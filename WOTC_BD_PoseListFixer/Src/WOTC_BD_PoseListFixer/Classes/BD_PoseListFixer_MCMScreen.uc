class BD_PoseListFixer_MCMScreen extends Object config(XComPoseListFixer);

var config int VERSION_CFG;

var localized string ModName;
var localized string PageTitle;
var localized string GroupHeader;

// Pose exclusion/blacklist. The photobooth's own pose list handles both
// adding to and reviewing the blacklist directly - this screen only holds
// the persisted list and a single checkbox controlling whether the
// photobooth shows all poses with checkbox status (on) or the normal
// selectable list with exclusions hidden (off).

struct BlacklistedPose
{
	var name AnimationName;
	var float AnimationOffset;
};

var config array<BlacklistedPose> ExcludedPoses;

// Group-formation pose restriction ("keep this pose out of every group
// photo, not just fully excluded ones"). Reuses X2Photobooth's own
// PoseFormationRestrictionInfo struct/RestrictedFromFormation() mechanism -
// that function is already called unconditionally inside GetAnimations(),
// so we don't need our own filtering logic for this one, just a way to
// feed entries into it. Deliberately NOT stored on X2Photobooth itself:
// its config arrays (like m_arrAnimationPoses) are built by additively
// merging every installed mod's own +PoseFormationRestrictions=(...) lines
// at load time, so calling SaveConfig on that class would bake the entire
// current merged snapshot into this profile's ini - next launch, that
// snapshot and every mod's live contributions merge again, additively,
// duplicating a little more each time anyone saves. Keeping our own
// separate copy here (safe to SaveConfig, nothing else touches it) and
// live-injecting it into the current session's actual X2Photobooth
// instance avoids that entirely - see UIArmory/UITactical_Photobooth_PoseFix's
// OnInit for the injection step (needs `PHOTOBOOTH, which is only proven to
// work from instance context, not from here).
var config array<X2Photobooth.PoseFormationRestrictionInfo> GroupPoseRestrictions;

// Dedicated formation used purely for reviewing/managing group
// restrictions, so RestrictedFromFormation() never hides anything from that
// review list - needs a matching +PhotoboothTemplateConfig entry in
// XComContent.ini (clone of an existing multi-soldier formation, e.g. Mob,
// same LayoutBlueprint/CameraFocus/LocationTags, just this TemplateName).
// Never shown to the player as a real formation choice - the photobooth
// files switch `PHOTOBOOTH.m_kFormationTemplate to this directly while
// group-restrict review mode is active and restore the real formation on
// exit, rather than requiring the player to select it from the normal
// formation dropdown.
const REVIEW_FORMATION_NAME = 'BD_PoseFixReview';

`include(WOTC_BD_PoseListFixer\Src\ModConfigMenuAPI\MCM_API_Includes.uci)

`MCM_API_AutoCheckBoxVars(RIGHT_CLICK_EXITS_SCREEN);

`include(WOTC_BD_PoseListFixer\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

`MCM_API_AutoCheckBoxFns(RIGHT_CLICK_EXITS_SCREEN, 1);

event OnInit(UIScreen Screen)
{
	`MCM_API_Register(Screen, ClientModCallback);
}

//Simple one group framework code
simulated function ClientModCallback(MCM_API_Instance ConfigAPI, int GameMode)
{
	local MCM_API_SettingsPage Page;
	local MCM_API_SettingsGroup Group;

	LoadSavedSettings();
	Page = ConfigAPI.NewSettingsPage(ModName);
	Page.SetPageTitle(PageTitle);
	Page.SetSaveHandler(SaveButtonClicked);

	//Uncomment to enable reset
	//Page.EnableResetButton(ResetButtonClicked);

	Group = Page.AddGroup('Group', GroupHeader);

	`MCM_API_AutoAddCheckBox(Group, RIGHT_CLICK_EXITS_SCREEN);

	Page.ShowSettings();
}

simulated function LoadSavedSettings()
{
	RIGHT_CLICK_EXITS_SCREEN = `GETMCMVAR(RIGHT_CLICK_EXITS_SCREEN);
}
/*
simulated function ResetButtonClicked(MCM_API_SettingsPage Page)
{
	`MCM_API_AutoReset(RIGHT_CLICK_EXITS_SCREEN);
}
*/
simulated function SaveButtonClicked(MCM_API_SettingsPage Page)
{
	VERSION_CFG = `MCM_CH_GetCompositeVersion();
	SaveConfig();
}

// ---------------------------------------------------------------------------
// Blacklist read/write - shared with the photobooth's checkbox toggle
// ---------------------------------------------------------------------------

// Static so the photobooth can call these with no live MCM instance around.
// Uses default.ExcludedPoses explicitly since static functions have no self.
static function int FindExcludedPoseIndex(name AnimationName, float AnimationOffset)
{
	local int i;

	for (i = 0; i < default.ExcludedPoses.Length; i++)
	{
		if (default.ExcludedPoses[i].AnimationName == AnimationName && default.ExcludedPoses[i].AnimationOffset == AnimationOffset)
		{
			return i;
		}
	}
	return INDEX_NONE;
}

static function bool IsPoseExcluded(name AnimationName, float AnimationOffset)
{
	return FindExcludedPoseIndex(AnimationName, AnimationOffset) != INDEX_NONE;
}

static function int FindGroupRestrictionIndex(name AnimationName, float AnimationOffset, optional name FormationName)
{
	local int i;

	for (i = 0; i < default.GroupPoseRestrictions.Length; i++)
	{
		if (default.GroupPoseRestrictions[i].AnimationName == AnimationName
			&& default.GroupPoseRestrictions[i].AnimationOffset == AnimationOffset
			&& (FormationName == '' || default.GroupPoseRestrictions[i].FormationName == FormationName))
		{
			return i;
		}
	}
	return INDEX_NONE;
}

static function bool IsPoseGroupRestricted(name AnimationName, float AnimationOffset)
{
	return FindGroupRestrictionIndex(AnimationName, AnimationOffset) != INDEX_NONE;
}

// Checked = restricted from every non-Solo formation entirely (every one of
// that formation's own LocationTags), matching "list Slot1->Slot6 to
// restrict completely". Formations are read live via
// X2PropagandaPhotoTemplateManager rather than hardcoded, so a mod-added
// formation is picked up automatically, same as vanilla ones.
//
// bPersistImmediately=false skips the disk write (used when batching many
// checkbox clicks - see PersistGroupRestrictions below).
static function SetPoseGroupRestricted(name AnimationName, float AnimationOffset, bool bRestricted, optional bool bPersistImmediately = true)
{
	local X2PropagandaPhotoTemplateManager PhotoTemplateManager;
	local array<X2PropagandaPhotoTemplate> FormationTemplates;
	local X2PropagandaPhotoTemplate FormationTemplate;
	local X2Photobooth.PoseFormationRestrictionInfo NewEntry;
	local int ExistingIndex;

	if (bRestricted)
	{
		PhotoTemplateManager = class'X2PropagandaPhotoTemplateManager'.static.GetPropagandaPhotoTemplateManager();
		PhotoTemplateManager.GetUberTemplates("Formation", FormationTemplates);

		foreach FormationTemplates(FormationTemplate)
		{
			if (FormationTemplate.NumSoldiers <= 1 || FormationTemplate.DataName == REVIEW_FORMATION_NAME)
			{
				continue;
			}

			if (FindGroupRestrictionIndex(AnimationName, AnimationOffset, FormationTemplate.DataName) != INDEX_NONE)
			{
				continue;
			}

			NewEntry.AnimationName = AnimationName;
			NewEntry.AnimationOffset = AnimationOffset;
			NewEntry.FormationName = FormationTemplate.DataName;
			NewEntry.LocationTags = FormationTemplate.LocationTags;
			default.GroupPoseRestrictions.AddItem(NewEntry);
		}
	}
	else
	{
		ExistingIndex = FindGroupRestrictionIndex(AnimationName, AnimationOffset);
		while (ExistingIndex != INDEX_NONE)
		{
			default.GroupPoseRestrictions.Remove(ExistingIndex, 1);
			ExistingIndex = FindGroupRestrictionIndex(AnimationName, AnimationOffset);
		}
	}

	if (bPersistImmediately)
	{
		StaticSaveConfig();
	}
}

// Flushes a batch of deferred SetPoseGroupRestricted(..., bPersistImmediately=false)
// calls with a single disk write - called once when group-restrict review
// mode is exited (button toggle or backing out mid-edit), not per click.
static function PersistGroupRestrictions()
{
	StaticSaveConfig();
}

// Shared by both photobooth files' GetAnimationData, the duplicate
// GetAnimations() call in PopulatePoseList (for AnimationPosesData - must
// stay in lockstep with whatever GetAnimationData did to AnimationNames),
// and SetRandomAnimationPoseForSoldier.
static function FilterExcludedPoses(out array<AnimationPoses> Poses)
{
	local int i;

	for (i = 0; i < Poses.Length; i++)
	{
		if (IsPoseExcluded(Poses[i].AnimationName, Poses[i].AnimationOffset))
		{
			Poses.Remove(i--, 1);
		}
	}
}

// Persists on every call (StaticSaveConfig - no instance to SaveConfig() on)
// so a photobooth toggle is durable without needing MCM's Save button.
static function SetPoseExcluded(name AnimationName, float AnimationOffset, bool bExcluded)
{
	local int ExistingIndex;
	local BlacklistedPose Entry;

	ExistingIndex = FindExcludedPoseIndex(AnimationName, AnimationOffset);

	if (bExcluded && ExistingIndex == INDEX_NONE)
	{
		Entry.AnimationName = AnimationName;
		Entry.AnimationOffset = AnimationOffset;
		default.ExcludedPoses.AddItem(Entry);
	}
	else if (!bExcluded && ExistingIndex != INDEX_NONE)
	{
		default.ExcludedPoses.Remove(ExistingIndex, 1);
	}
	else
	{
		return;
	}

	StaticSaveConfig();
}
