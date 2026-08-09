class UITactical_Photobooth_PoseFix extends UITactical_Photobooth dependson(UIPoseFix_SaveSquad);

var localized string m_strNMD;

// bPoseBlacklistModeActive: toggled via the "Restrict From All Formations"
// row in PoseModeList - shows every pose (unfiltered) as checkboxes while
// active, checked = already excluded. BlacklistModePagePoses caches the
// current page's poses in render order, so OnPoseCheckboxToggled can map a
// checkbox back to its pose via index.
var bool bPoseBlacklistModeActive;
// bGroupRestrictModeActive: same idea, second independent row, for editing
// GroupPoseRestrictions instead of ExcludedPoses. Mutually exclusive with
// bPoseBlacklistModeActive - toggling one off if the other's turned on.
var bool bGroupRestrictModeActive;
var array<AnimationPoses> BlacklistModePagePoses;

// Full (unsliced) filtered pose array from PopulatePoseList's last render -
// OnSetPose reads this instead of re-calling GetAnimations() on every
// single hover/selection change, since GetAnimations() internally re-scans
// the entire PoseFormationRestrictions list per pose every time it's
// called (see RestrictedFromFormation) - that cost is unavoidable per
// call, but there's no need to pay it again for every mouse movement over
// a list whose content hasn't changed since it was last rendered.
var array<AnimationPoses> CachedFilteredAnimationPoses;

// Snapshot of each soldier's live in-session pose, taken right before
// OnClickedRandomizeBackground triggers a studio respawn (SpawnStudio) -
// reapplied afterward instead of the saved squad slot's poses, so
// randomizing the location doesn't silently revert poses the player set
// this session but never saved.
var array<UIPoseFix_SaveSquad.SavedSquadSoldierData> PreRandomizeLocationPoses;

// Tracks exactly which GroupPoseRestrictions entries this screen instance
// has itself injected into the live PHOTOBOOTH.PoseFormationRestrictions,
// so SyncGroupPoseRestrictionsToLiveSession's removal step only ever
// touches entries we added - never a native or another mod's restriction
// that happens to share the same fields.
var array<X2Photobooth.PoseFormationRestrictionInfo> InjectedGroupRestrictions;

// Poses actually toggled during the current group-restrict edit session
// (deduplicated) - lets the mode-exit flush sync only what changed instead
// of re-diffing every restriction that exists, however many there are. See
// SyncGroupPoseRestrictionForPose.
var array<AnimationPoses> DirtyGroupRestrictPoses;

// The real formation in effect before group-restrict review mode switched
// to the dedicated review formation - restored when review mode exits.
var X2PropagandaPhotoTemplate SavedFormationBeforeGroupRestrictReview;

// Maps each displayed formation row to its real index in
// `PHOTOBOOTH.GetFormations()` - needed because GetFormationData filters
// BD_PoseFixReview out of the list, so row position and raw index diverge.
var array<int> FormationListRealIndices;

// Small list near the bottom of the pose screen with a header row
// ("Pose Blacklist") and two selectable rows for the two edit modes below -
// see BuildPoseModeList. Replaces the old blacklistPoses/groupRestrict
// UIButtons.
var UIList PoseModeList;

// Needs .int entries (m_strBlacklistPoses=Blacklist Poses,
// m_strGroupRestrictPoses=Restrict From Group Poses,
// m_strPoseBlacklistHeader=Pose Blacklist), like m_strNMD.
// TEMPORARY: plain (not localized) strings, since a localized var can't
// have a defaultproperties entry - compiler rejects the combination. Once
// real .int entries exist for these, switch back to `var localized string`
// and drop the defaultproperties lines, matching m_strNMD's pattern.
var string m_strBlacklistPoses;
var string m_strGroupRestrictPoses;
var string m_strPoseBlacklistHeader;

`include(WOTC_BD_PoseListFixer\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

// Special Handling for NMD
function int GetSquadContext()
{
	if (class'UIPoseFixHelpers'.default.NMDPhotoboothActive)
		return class'UIPoseFix_SaveSquad'.const.CONTEXT_NMD;
	return class'UIPoseFix_SaveSquad'.const.CONTEXT_TACTICAL;
}

// Overridden so "Hide Poster" only hides the text/layout overlay
function HidePosterElements(bool bHide)
{
	if (bHide)
	{
		`PHOTOBOOTH.HidePosterTexture();
	}
	else
	{
		`PHOTOBOOTH.UpdatePosterTexture();
	}
}

// `PHOTOBOOTH.PosterElementsHidden() reads bShowInGame, which
// HidePosterElements() above deliberately no longer touches (that's what
// preserves a custom background) - so it's permanently stale and can't be
// used to tell whether text is actually hidden anymore, hence this check instead.
function bool IsPosterTextHidden()
{
	return (`PHOTOBOOTH.m_kPhotoboothEffect != none) && (`PHOTOBOOTH.m_kPhotoboothEffect.UIRenderTarget == none);
}

// Pushes persisted GroupPoseRestrictions into the live X2Photobooth
// instance, which RestrictedFromFormation() reads directly. Only called
// once, at OnInit.
//
// PHOTOBOOTH is a fresh instance every time the photobooth screen opens
// (confirmed via diagnostic logging - X2Photobooth_LEBPortrait_1, _2, _3...
// incrementing per visit, never reused) - a new instance's
// PoseFormationRestrictions only ever contains whatever's ini-defined
// (native or another mod's entries), never anything injected at runtime by
// a previous instance, since that only ever lived in the now-destroyed
// object's memory and we deliberately never call SaveConfig on
// X2Photobooth itself (see GroupPoseRestrictions in
// BD_PoseListFixer_MCMScreen.uc for why). So nothing here could possibly
// already be live, and InjectedGroupRestrictions (this fresh screen
// instance's own var) is always empty too - no diffing needed at all, just
// a straight bulk add. If PHOTOBOOTH's construction semantics ever change
// such that it can persist across visits, this would need to go back to
// checking for already-live entries first.
function SyncGroupPoseRestrictionsToLiveSession()
{
	local X2Photobooth.PoseFormationRestrictionInfo PersistedEntry;

	InjectedGroupRestrictions.Length = 0;
	foreach class'BD_PoseListFixer_MCMScreen'.default.GroupPoseRestrictions(PersistedEntry)
	{
		`PHOTOBOOTH.PoseFormationRestrictions.AddItem(PersistedEntry);
		InjectedGroupRestrictions.AddItem(PersistedEntry);
	}
}


// Fast path for the mode-exit flush. Unlike SyncGroupPoseRestrictionsToLiveSession
// (a plain bulk-add, safe only at OnInit because PHOTOBOOTH is always a
// fresh instance there - see that function's comment), this can't skip
// straight to bulk-adding: PHOTOBOOTH already has this session's earlier
// injections live, so it needs to know exactly which of THIS pose's
// entries to drop before re-adding, without touching anything else. During
// an edit session we know exactly which poses were touched
// (DirtyGroupRestrictPoses) - this only touches entries for one specific
// pose, bounded by the number of formations, not by how many restrictions
// exist in total.
function SyncGroupPoseRestrictionForPose(name AnimationName, float AnimationOffset)
{
	local X2Photobooth.PoseFormationRestrictionInfo Entry;
	local int i, j;

	// Drop anything previously injected for this pose. Simplest correct way
	// to handle every case (still restricted for some formations but not
	// others, or fully unchecked now) without extra per-formation bookkeeping.
	for (i = InjectedGroupRestrictions.Length - 1; i >= 0; i--)
	{
		if (InjectedGroupRestrictions[i].AnimationName != AnimationName
			|| InjectedGroupRestrictions[i].AnimationOffset != AnimationOffset)
		{
			continue;
		}

		for (j = `PHOTOBOOTH.PoseFormationRestrictions.Length - 1; j >= 0; j--)
		{
			if (`PHOTOBOOTH.PoseFormationRestrictions[j].AnimationName == InjectedGroupRestrictions[i].AnimationName
				&& `PHOTOBOOTH.PoseFormationRestrictions[j].AnimationOffset == InjectedGroupRestrictions[i].AnimationOffset
				&& `PHOTOBOOTH.PoseFormationRestrictions[j].FormationName == InjectedGroupRestrictions[i].FormationName)
			{
				`PHOTOBOOTH.PoseFormationRestrictions.Remove(j, 1);
				break;
			}
		}
		InjectedGroupRestrictions.Remove(i, 1);
	}

	// Re-add whatever's now persisted for this pose - SetPoseGroupRestricted
	// already built one entry per applicable formation (or none, if this
	// pose was just unchecked).
	for (i = 0; i < class'BD_PoseListFixer_MCMScreen'.default.GroupPoseRestrictions.Length; i++)
	{
		Entry = class'BD_PoseListFixer_MCMScreen'.default.GroupPoseRestrictions[i];
		if (Entry.AnimationName != AnimationName || Entry.AnimationOffset != AnimationOffset)
		{
			continue;
		}

		`PHOTOBOOTH.PoseFormationRestrictions.AddItem(Entry);
		InjectedGroupRestrictions.AddItem(Entry);
	}
}

// Called once when group-restrict review mode is exited - syncs only the
// poses actually touched this session (see OnGroupRestrictCheckboxToggled),
// then clears the dirty list for next time.
function FlushDirtyGroupPoseRestrictions()
{
	local int i;

	for (i = 0; i < DirtyGroupRestrictPoses.Length; i++)
	{
		SyncGroupPoseRestrictionForPose(DirtyGroupRestrictPoses[i].AnimationName, DirtyGroupRestrictPoses[i].AnimationOffset);
	}
	DirtyGroupRestrictPoses.Length = 0;
}

simulated function OnInit()
{
	local int			i, NumberNonBlank;
	local string		TestString;
	
	super.OnInit();

	SyncGroupPoseRestrictionsToLiveSession();

	// Hide the poster overlay until our saved slots are actually applied,
	// so the transient auto-generated layout never becomes visible - masks
	// the delay below rather than needing it to be imperceptibly short.
	HidePosterElements(true);

	class'UIPoseFix_SaveLayout'.default.lastAline = "";
	class'UIPoseFix_SaveLayout'.default.lastBline = "";
	class'UIPoseFix_SaveLayout'.default.lastOpline = "";
	class'UIPoseFix_SaveLayout'.static.SaveLayoutConfigs();
	class'UIPoseFix_SaveLayout'.static.EnsureSlotsInitialized();
	class'UIPoseFix_SaveSquad'.static.EnsureSlotsInitialized();

	//`log("Ran PoseFix OnInit - NMDPhotoboothActive Status:" @ class'UIPoseFixHelpers'.default.NMDPhotoboothActive,,'BDLOG');
	If(class'UIPoseFixHelpers'.default.NMDPhotoboothActive == true)
	{
		//Do any stuff here that is specific to Nice Mission Briefings (setting formations, getting soldiers etc.)
		NMD_InitializeFormation();
		GenerateDefaultSoldierSetup();	
		class'UIPoseFixHelpers'.default.UIPhotoboothSoldierIndex = 0;
	}

	// Initialise layout settings (give up after 10 attempts of trying getting an equal number of elements to what we saved)
	for(i=0; i<10; i++)
	{
		if (`PHOTOBOOTH.m_kFormationTemplate.NumSoldiers == 1)
		{
			`PHOTOBOOTH.SetAutoTextStrings(ePBAT_SOLO);
		}
		else if (`PHOTOBOOTH.m_kFormationTemplate.NumSoldiers == 2)
		{
			`PHOTOBOOTH.SetAutoTextStrings(ePBAT_DUO);
		}
		else
		{
			`PHOTOBOOTH.SetAutoTextStrings(ePBAT_SQUAD);
		}
		NumberNonBlank = 0;
		foreach `PHOTOBOOTH.m_PosterStrings(TestString)
		{
			//`log("PosterStrings:" @ TestString,,'BDLOG');
			if(TestString != "")
			{
				NumberNonBlank += 1;
				if(IsBLine(TestString))
				{
					class'UIPoseFix_SaveLayout'.default.lastBline = TestString;
				}			
			}
		}
		if(NumberNonBlank >= class'UIPoseFix_SaveLayout'.default.NumberOfNonBlankLinesInSavedLayout)
		{		
		class'UIPoseFix_SaveLayout'.static.SaveLayoutConfigs();
		break;
		}
	}

	ApplySavedPhotoboothSlots();
}

function ApplySavedPhotoboothSlots()
{	
	if (m_kGenRandomState != eAGCS_Idle)
	{
		`log("PoseFix ApplySavedPhotoboothSlots: base game random setup still in progress (m_kGenRandomState =" @ m_kGenRandomState $ "), retrying shortly",,'BDLOG');
		SetTimer(0.05f, false, nameof(ApplySavedPhotoboothSlots));
		return;
	}

	`log("PoseFix: applying saved Pose/Camera and Layout slots after startup delay",,'BDLOG');
	
	ApplySquadSlot();
	if (!ApplyLayoutSlot())
	{		
		HidePosterElements(false);
	}
}

function PopulateData()
{
	//bsg-jneal (5.16.17): now returning to original menu index when leaving soldier or pose selection
	local int							i, previousListIndex, soldierIndex, NumberNonBlank;
	local								UIButton nextItemsButton, previousItemsButton, soldierToggleButton;
	local array<XComGameState_Unit>		arrSoldiers, arrValidSoldiers;
	local string						TestString;

	BATTLE().GetHumanPlayer().GetOriginalUnits(arrSoldiers, true, true, true);
	
	arrValidSoldiers.length = 0;

	for (i = 0; i < arrSoldiers.Length; ++i) // Check that we are not adding more than 6 units as no formation holds more than 6.
	{
		if (class'UIPoseFixHelpers'.static.IsValidNMDPhotoboothSoldier(arrSoldiers[i]))
		{
			arrValidSoldiers.additem(arrSoldiers[i]);
		}
	}

	previousListIndex = -1;	
	
	soldierIndex = class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex + class'UIPoseFixHelpers'.default.UIPhotoboothSoldierIndex;
	if(soldierIndex == -1)
	{
	soldierIndex = 0;
	}

	//bsg-jedwards (5.1.17) : Check if the state changed so we can clear the list items and remake them as some may have changed drastically
	if(currentState != lastState)
	{
		if(currentState != eUIPropagandaType_Base)
		{
		UIButton(self.GetChildByName('soldierToggle',false)).Remove();
		}
		if(currentState == eUIPropagandaType_SoldierData)
		{
			// Remove vbuttons and restore normal title when we back out of the pose screen
			UIButton(self.GetChildByName('previousItems',false)).Remove();
			UIButton(self.GetChildByName('nextItems',false)).Remove();
			if (PoseModeList != none)
			{
				PoseModeList.Remove();
				PoseModeList = none;
			}
			// Backing out of the pose screen lands here directly, bypassing
			// OnToggleGroupRestrictMode entirely - so if review mode was
			// active, flush its deferred changes and restore the real
			// formation ourselves.
			if (bGroupRestrictModeActive)
			{
				class'BD_PoseListFixer_MCMScreen'.static.PersistGroupRestrictions();
				FlushDirtyGroupPoseRestrictions();
			}
			bPoseBlacklistModeActive = false;
			bGroupRestrictModeActive = false;
			if (SavedFormationBeforeGroupRestrictReview != none)
			{
				`PHOTOBOOTH.m_kFormationTemplate = SavedFormationBeforeGroupRestrictReview;
				SavedFormationBeforeGroupRestrictReview = none;
			}
			setCategory(m_PhotoboothTitle);			
			// only check if we are returning to soldier data list
			if(lastState == eUIPropagandaType_Pose)
			{	
				previousListIndex = (m_iLastTouchedSoldierIndex * 4) + 1; //multiply index by number of list items per soldier (3 + 1 blank), also add 1 if returning from pose
			}
			else if(lastState == eUIPropagandaType_Soldier)
			{
				previousListIndex = (m_iLastTouchedSoldierIndex * 4); //multiply index by number of list items per soldier (3 + 1 blank)
			}
		}
		lastState = currentState;
		List.ClearItems();
	}
	else
	{
		HideListItems();
	}

	// Sort out layout save / load stuff
	NumberNonBlank = 0;

	foreach `PHOTOBOOTH.m_PosterStrings(TestString)
	{
		//`log("PosterStrings:" @ TestString,,'BDLOG');			
		if(TestString != "" )
		{
			NumberNonBlank += 1;
		}
	}	

	class'UIPoseFix_SaveLayout'.default.NumberOfNonBlankLinesInCurrentLayout = NumberNonBlank;
	class'UIPoseFix_SaveLayout'.default.hasOpline = false;
	
	for(i=0; i<`PHOTOBOOTH.m_PosterStrings.length; i++)
	{
		TestString = `PHOTOBOOTH.m_PosterStrings[i];

		if(isBLine(TestString))
		{
			class'UIPoseFix_SaveLayout'.default.lastBline = TestString;
		}
		else if(i==0 && `PHOTOBOOTH.m_PosterStrings[i] != "")
		{
			class'UIPoseFix_SaveLayout'.default.lastAline = TestString;
		}
		else if(`PHOTOBOOTH.m_PosterStrings[i] != "")
		{
			class'UIPoseFix_SaveLayout'.default.lastOpline = TestString;
			class'UIPoseFix_SaveLayout'.default.hasOpline = true;
		}
	}

	class'UIPoseFix_SaveLayout'.static.SaveLayoutConfigs();
	
	// Create layout and update strings
	i = 0;	
	if (m_bInitialized)
	{
		switch (currentState)
		{
		case eUIPropagandaType_Base:
			class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex = 0;
			class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex = class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay;
			class'UIPoseFixHelpers'.default.UIPhotoboothPoseOffset = 0;	
			if(class'UIPoseFixHelpers'.default.NMDPhotoboothActive == true && UIButton(self.GetChildByName('soldierToggleButton',false)) == none)
			{
				soldierToggleButton = Spawn(class'UIButton',self);
				soldierToggleButton.InitButton('soldierToggle', class'UIUtilities_Strategy'.default.m_arrStaffTypes[eStaff_Soldier] $ " : " $ arrValidSoldiers[soldierIndex].GetFullName(),, eUIButtonStyle_NONE);
				soldierToggleButton.SetGamepadIcon(class'UIUtilities_Input'.const.ICON_Y_TRIANGLE);
				soldierToggleButton.SetResizeToText(false);
				soldierToggleButton.SetTextAlign("center");
				soldierToggleButton.SetPosition(75,925);
				soldierToggleButton.SetWidth(410);			
			}						
			PopulateDefaultList(i);
			break;
		case eUIPropagandaType_Formation:
			PopulateFormationList(i);
			break;
		case eUIPropagandaType_SoldierData:
			PopulateSoldierDataList(i);
			break;
		case eUIPropagandaType_Soldier:
			PopulateSoldierList(i);
			break;
		case eUIPropagandaType_Pose:	
			if(UIButton(self.GetChildByName('previousItems',false)) == none)
			{
				previousItemsButton = Spawn(class'UIButton',self).InitButton('previousItems', class'UIMPShell_Leaderboards'.default.m_strPreviousPageText, onSelectPrevious, eUIButtonStyle_HOTLINK_BUTTON);		
				previousItemsButton.SetGamepadIcon(class'UIUtilities_Input'.const.ICON_DPAD_LEFT);
				previousItemsButton.SetPosition(75,864);
				nextItemsButton = Spawn(class'UIButton',self).InitButton('nextItems', class'UIMPShell_Leaderboards'.default.m_strNextPageText, onSelectNext, eUIButtonStyle_HOTLINK_BUTTON);			
				nextItemsButton.SetGamepadIcon(class'UIUtilities_Input'.const.ICON_DPAD_RIGHT);
				nextItemsButton.SetPosition(350,864);		
			}
			if(PoseModeList == none)
			{
				BuildPoseModeList();
			}
			PopulatePoseList(i);
			break;
		case eUIPropagandaType_BackgroundOptions:
			PopulateBackgroundOptionsList(i);
			break;
		case eUIPropagandaType_Background:
			PopulateBackgroundList(i);
			break;
		case eUIPropagandaType_Graphics:
			PopulateGraphicsList(i);
			break;
		case eUIPropagandaType_Fonts:
			PopulateFontList(i);
			break;
		case eUIPropagandaType_TextColor:
			PopulateTextColors(i);
			break;
		case eUIPropagandaType_GradientColor1:
			PopulateBackground1Colors(i);
			break;
		case eUIPropagandaType_GradientColor2:
			PopulateBackground2Colors(i);
			break;
		case eUIPropagandaType_TextFont:
			PopulateFontList(i);
			break;
		case eUIPropagandaType_Layout:
			PopulateLayoutList(i);
			break;
		case eUIPropagandaType_Filter:
			PopulateFilterList(i);
			break;
		case eUIPropagandaType_Treatment:
			PopulateTreatmentList(i);
			break;
		};

		//bsg-jedwards (5.1.17) : Repopulate the navigator on the list when the list refreshens
		if(`ISCONTROLLERACTIVE)
		{
			if(previousListIndex != -1)
			{
				List.SetSelectedIndex(previousListIndex);
			}
			else 
			{
				//bsg-jneal (5.23.17): updating certain list indices for poster previews on selection changed, if entering these menus set the initial pose index so the list does not init on the wrong pose
				if(currentState == eUIPropagandaType_Pose || currentState == eUIPropagandaType_Formation || currentState == eUIPropagandaType_Layout || currentState == eUIPropagandaType_Filter || currentState == eUIPropagandaType_Background || currentState == eUIPropagandaType_Treatment)
				{
					List.NavigatorSelectionChanged(m_bOriginalSubListIndex);
				}
				else if(currentState == eUIPropagandaType_Base)
				{
					List.SetSelectedIndex(m_iDefaultListIndex); //bsg-jneal (5.23.17): saving default list index for better nav
				}
				else
				{
					List.OnSelectionChanged = none; //bsg-jneal (5.23.17): clear selection changed callback for sub lists that do not use it
					List.SetSelectedIndex(List.SelectedIndex);
				}
			}
		}
		//bsg-jedwards (5.1.17) : end
	}
	//bsg-jneal (5.16.17): end
}

function PopulatePoseList(out int Index)
{
	local array<string> AnimationNames;
	local array<AnimationPoses> AnimationPosesData;
	local int AnimationIndex, i, endIndex;
	local string poseHeader;
	local int numPages;
	local int currentPage;
	
	// GetAnimations() internally scans the full PoseFormationRestrictions
	// list for every single pose (RestrictedFromFormation, unconditional,
	// no way to skip it) - an O(poses * restrictions) cost that scales
	// directly with how many poses are excluded/restricted. This used to
	// pay that cost TWICE per render: once via GetAnimationData, once more
	// here for the struct data GetAnimationData's signature can't return
	// (it overrides a base function). Fetching once and inlining
	// GetAnimationData's own filter/recompute logic against that same
	// result halves the cost of every page render, mode toggle, and
	// backing-out repopulate.
	AnimationIndex = `PHOTOBOOTH.GetAnimations(m_iLastTouchedSoldierIndex, AnimationPosesData, , class'UIPoseFixHelpers'.default.enableMemorialPoseFiltering && DefaultSetupSettings.TextLayoutState == ePBTLS_DeadSoldier);
	// Must apply the exact same filtering GetAnimationData would have, or
	// the two arrays fall out of index-sync. The "Blacklist Poses" toggle
	// shows everything unfiltered so already-excluded poses can still be
	// seen/reviewed there; group-restrict mode and normal browsing both
	// still filter out fully-excluded poses.
	if (!bPoseBlacklistModeActive)
	{
		class'BD_PoseListFixer_MCMScreen'.static.FilterExcludedPoses(AnimationPosesData);

		// Filtering shifts/removes indices, so the raw index above is
		// stale - recompute it by name/offset match, same as
		// GetAnimationData does.
		AnimationIndex = INDEX_NONE;
		for (i = 0; i < AnimationPosesData.Length; ++i)
		{
			if (AnimationPosesData[i].AnimationName == `PHOTOBOOTH.m_arrUnits[m_iLastTouchedSoldierIndex].AnimationName &&
				AnimationPosesData[i].AnimationOffset == `PHOTOBOOTH.m_arrUnits[m_iLastTouchedSoldierIndex].AnimationOffset)
			{
				AnimationIndex = i;
				break;
			}
		}
	}

	AnimationNames.Length = 0;
	for (i = 0; i < AnimationPosesData.Length; ++i)
	{
		AnimationNames.AddItem(AnimationPosesData[i].AnimationDisplayName);
	}

	//`log("Number of Poses:" @ AnimationNames.Length,,'BDLOG');
	//`log("Start index:" @ class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex @ "End Index:" @ class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex @ "Anim Index:" @ AnimationIndex,,'BDLOG');
	
	// If we try to start at a number greater than the number of poses, go back to the first page:
	if (class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex > AnimationNames.Length)
	{
		class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex = 0;
		class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex = class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay;
	}		
	// We're going onto the last page so don't display loads of empty records
	if (class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex <= 0 || class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex >= AnimationNames.Length)
	{
		class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex = AnimationNames.Length <= class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay ? 0 : (AnimationNames.Length - (AnimationNames.Length % class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay));
		class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex = AnimationNames.Length;
	}	
	else
	{
		//use default list size
		class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex = class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex + class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay;
	}
	//cover for situations where we have less poses than the 'number of elements to display'
	if (AnimationNames.Length < class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay)
	{
		endIndex = AnimationNames.Length;
	}
	else
	{
		endIndex = class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex;
	}
	//`log("Building List:",,'BDLOG');
	//`log("Start index:" @ class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex @ "End Index:" @ class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex @ "Anim Index:" @ AnimationIndex,,'BDLOG');

	if (bPoseBlacklistModeActive || bGroupRestrictModeActive)
	{
		BlacklistModePagePoses.Length = 0;
		for (i = class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex; i < endIndex; i++)
		{
			if (bGroupRestrictModeActive)
			{
				GetListItem(Index++).UpdateDataCheckbox(AnimationNames[i], "",
					class'BD_PoseListFixer_MCMScreen'.static.IsPoseGroupRestricted(AnimationPosesData[i].AnimationName, AnimationPosesData[i].AnimationOffset),
					OnGroupRestrictCheckboxToggled);
			}
			else
			{
				GetListItem(Index++).UpdateDataCheckbox(AnimationNames[i], "",
					class'BD_PoseListFixer_MCMScreen'.static.IsPoseExcluded(AnimationPosesData[i].AnimationName, AnimationPosesData[i].AnimationOffset),
					OnPoseCheckboxToggled);
			}
			BlacklistModePagePoses.AddItem(AnimationPosesData[i]);
		}
	}
	else
	{
		for (i = class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex; i < endIndex; i++)
		{
			GetListItem(Index++).UpdateDataDescription(AnimationNames[i], OnConfirmPose); //bsg-jneal (5.16.17): now changing pose on selection change
		}
	}
	// Defensively hide any leftover rows beyond this page's actual item
	// count - the base game only fully clears the list when currentState
	// changes (which toggling checkbox mode never does), so switching
	// between a full page and a partial one via list-item reuse can leave
	// stale rows visible. Only touches rows that already exist (List.GetItem,
	// not GetListItem, which would spawn new ones).
	for (i = Index; i < List.ItemCount; i++)
	{
		List.GetItem(i).Hide();
	}
	// Hover-preview works the same in both modes - it's driven by the list's
	// selected index changing, which is independent of a checkbox's own
	// click handler, so there's no interference between previewing a pose
	// and toggling its blacklist state.
	List.OnSelectionChanged = OnSetPose;

	numPages = FCeil(float(AnimationNames.Length) / float(class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay));
	currentPage = (class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex / class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay) +1;
	if (bGroupRestrictModeActive)
	{
		poseHeader = (m_strPoseBlacklistHeader $ " - " $ m_strGroupRestrictPoses @ "[" $ currentPage $ "/" $ numPages $ "]");
	}
	else
	{
		poseHeader = ((bPoseBlacklistModeActive ? m_strPoseBlacklistHeader  $ " - " $  m_strBlacklistPoses : m_PhotoboothTitle) @ "[" $ currentPage $ "/" $ numPages $ "]");
	}
	SetCategory(poseHeader);
	
	//bsg-jneal (5.16.17): now changing pose on selection change so need to remember initial pose when cancelling menu
	m_bOriginalSubListIndex = AnimationIndex;
	//bsg-jneal (5.16.17): end

	CachedFilteredAnimationPoses = AnimationPosesData;
}

function GetAnimationData(int LocationIndex, out array<String> outAnimationNames, out int outAnimationIndex)
{
	local array<AnimationPoses> arrAnimations;
	local int i;

	outAnimationIndex = `PHOTOBOOTH.GetAnimations(LocationIndex, arrAnimations, , class'UIPoseFixHelpers'.default.enableMemorialPoseFiltering && DefaultSetupSettings.TextLayoutState == ePBTLS_DeadSoldier);

	// "Blacklist Poses" toggle mode shows the full unfiltered list, so
	// already-excluded poses can be seen/reviewed there. Group-restrict mode
	// and normal browsing both still filter out fully-excluded poses.
	if (!bPoseBlacklistModeActive)
	{
		class'BD_PoseListFixer_MCMScreen'.static.FilterExcludedPoses(arrAnimations);

		// Filtering shifts/removes indices, so the soldier's current-pose
		// index (from the unfiltered GetAnimations() call above) is now
		// stale - recompute it by name/offset match against the filtered list.
		outAnimationIndex = INDEX_NONE;
		for (i = 0; i < arrAnimations.Length; ++i)
		{
			if (arrAnimations[i].AnimationName == `PHOTOBOOTH.m_arrUnits[LocationIndex].AnimationName &&
				arrAnimations[i].AnimationOffset == `PHOTOBOOTH.m_arrUnits[LocationIndex].AnimationOffset)
			{
				outAnimationIndex = i;
				break;
			}
		}
	}

	outAnimationNames.Length = 0;
	for (i = 0; i < arrAnimations.Length; ++i)
	{
		outAnimationNames.AddItem(arrAnimations[i].AnimationDisplayName);
	}
}

// Filters BD_PoseFixReview out of the formation list - it's an internal
// review-only formation, not a real player choice. Same idea as
// FilterExcludedPoses for the pose list.
function GetFormationData(out array<String> outFormationNames, out int outFormationIndex)
{
	local array<X2PropagandaPhotoTemplate> arrFormations;
	local int RawIndex, i;

	RawIndex = `PHOTOBOOTH.GetFormations(arrFormations);
	outFormationNames.Length = 0;
	FormationListRealIndices.Length = 0;

	for (i = 0; i < arrFormations.Length; ++i)
	{
		if (arrFormations[i].DataName == class'BD_PoseListFixer_MCMScreen'.const.REVIEW_FORMATION_NAME)
		{
			continue;
		}
		outFormationNames.AddItem(arrFormations[i].DisplayName);
		FormationListRealIndices.AddItem(i);
	}

	// RawIndex is m_kFormationTemplate's position in the unfiltered array -
	// remap to its position in the filtered list actually being displayed.
	// Never matches the review formation itself: that's only ever swapped
	// into m_kFormationTemplate directly, never selected through this list.
	outFormationIndex = 0;
	for (i = 0; i < FormationListRealIndices.Length; ++i)
	{
		if (FormationListRealIndices[i] == RawIndex)
		{
			outFormationIndex = i;
			break;
		}
	}
}

// Base version indexes straight into `PHOTOBOOTH.GetFormations()` via
// List.SelectedIndex - no longer valid once GetFormationData has skipped a
// row, so remap through FormationListRealIndices instead.
function OnSetFormation(UIList ContainerList, int ItemIndex)
{
	if (List.SelectedIndex >= 0 && List.SelectedIndex < FormationListRealIndices.Length)
	{
		SetFormation(FormationListRealIndices[List.SelectedIndex], true);
	}
}

// Base UITactical_Photobooth.InitializeFormation() picks randomly from
// every formation except Solo/Duo for squads of 3+, which can land on
// BD_PoseFixReview - a real formation template (RestrictedFromFormation()
// needs something to check against for the review list), but restrictions
// deliberately don't apply to it, since that's the whole point of the
// review formation. If a real squad photo ends up on it here, restrictions
// the player configured would silently not apply. Keeps the base's raw
// (unfiltered) index space throughout, since SetFormation() indexes
// directly into `PHOTOBOOTH.GetFormations() itself - just excludes the
// review formation's index from both random-pick paths (the 3+ soldiers
// case and the same-list fallback), rather than filtering the array itself.
function InitializeFormation()
{
	local array<X2PropagandaPhotoTemplate> arrFormations;
	local array<int> arrFilteredFormationIndices;
	local array<int> arrAllValidIndices;
	local int i, FormationIndex;

	FormationIndex = INDEX_NONE;
	`PHOTOBOOTH.GetFormations(arrFormations);

	if (m_arrSoldiers.Length == 1)
	{
		for (i = 0; i < arrFormations.Length; ++i)
		{
			if (arrFormations[i].DataName == name("Solo"))
			{
				FormationIndex = i;
				break;
			}
		}
	}
	else if (m_arrSoldiers.Length == 2)
	{
		for (i = 0; i < arrFormations.Length; ++i)
		{
			if (arrFormations[i].DataName == name("Duo"))
			{
				FormationIndex = i;
				break;
			}
		}
	}
	else
	{
		for (i = 0; i < arrFormations.Length; ++i)
		{
			if (arrFormations[i].DataName != name("Solo") && arrFormations[i].DataName != name("Duo")
				&& arrFormations[i].DataName != class'BD_PoseListFixer_MCMScreen'.const.REVIEW_FORMATION_NAME)
			{
				arrFilteredFormationIndices.AddItem(i);
			}
		}

		if (arrFilteredFormationIndices.Length > 0)
		{
			FormationIndex = arrFilteredFormationIndices[`SYNC_RAND(arrFilteredFormationIndices.Length)];
		}
	}

	if (FormationIndex == INDEX_NONE)
	{
		// Base game falls back to SYNC_RAND(arrFormations.Length) here,
		// which could land on the review formation directly - same
		// exclusion for this fallback path.
		for (i = 0; i < arrFormations.Length; ++i)
		{
			if (arrFormations[i].DataName != class'BD_PoseListFixer_MCMScreen'.const.REVIEW_FORMATION_NAME)
			{
				arrAllValidIndices.AddItem(i);
			}
		}
		FormationIndex = arrAllValidIndices[`SYNC_RAND(arrAllValidIndices.Length)];
	}

	if (DefaultSetupSettings.FormationTemplate == none)
	{
		DefaultSetupSettings.FormationTemplate = arrFormations[FormationIndex];
	}

	SetFormation(FormationIndex);
}

// See InitializeFormation's comment above - same exclusion, applied to
// this function's own (lower-probability, since this flow is normally
// single-soldier and should always find "Solo" directly) fallback.
function NMD_InitializeFormation()
{
	local array<X2PropagandaPhotoTemplate> arrFormations;
	local array<int> arrAllValidIndices;
	local int i, FormationIndex;

	FormationIndex = INDEX_NONE;
	`PHOTOBOOTH.GetFormations(arrFormations);
	for (i = 0; i < arrFormations.Length; ++i)
	{
		if (arrFormations[i].DataName == name("Solo"))
		{
			FormationIndex = i;
			break;
		}
	}

	if (FormationIndex == INDEX_NONE)
	{
		for (i = 0; i < arrFormations.Length; ++i)
		{
			if (arrFormations[i].DataName != class'BD_PoseListFixer_MCMScreen'.const.REVIEW_FORMATION_NAME)
			{
				arrAllValidIndices.AddItem(i);
			}
		}
		FormationIndex = arrAllValidIndices[`SYNC_RAND(arrAllValidIndices.Length)];
	}

	if (DefaultSetupSettings.FormationTemplate == none)
	{
		DefaultSetupSettings.FormationTemplate = arrFormations[FormationIndex];
	}
	//`log("Calling SetFormation - TextLayout:" @ DefaultSetupSettings.TextLayoutState,, 'BDLOG');
	SetFormation(FormationIndex);
	//`log("SetFormation Called - TextLayout:" @ DefaultSetupSettings.TextLayoutState,, 'BDLOG');
}

function GenerateDefaultSoldierSetup()
{
	local array<XComGameState_Unit> arrSoldiers, arrValidSoldiers;
	local int soldierIndex, i; 
	local XComGameState_AdventChosen ChosenState;

	BATTLE().GetHumanPlayer().GetOriginalUnits(arrSoldiers, true, true, true);
	
	for (i = 0; i < arrSoldiers.Length; ++i) // Check that we are not adding more than 6 units as no formation holds more than 6.
	{
		if (class'UIPoseFixHelpers'.static.IsValidNMDPhotoboothSoldier(arrSoldiers[i]))
		{
			arrValidSoldiers.additem(arrSoldiers[i]);
		}
	}

	soldierIndex = class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex;
	
	if(class'UIPoseFixHelpers'.default.NMDPhotoboothActive == true)
	{		
		//`log("Setting soldier index:" @ class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex @ "Name:" @ arrSoldiers[soldierIndex].GetFullName());
		//`log("TextLayout:" @ DefaultSetupSettings.TextLayoutState);
		`PHOTOBOOTH.SetSoldier(0, arrValidSoldiers[soldierIndex].GetReference());		
		//`log("TextLayout AfterSetSoldier:" @ DefaultSetupSettings.TextLayoutState);
		DefaultSetupSettings.PossibleSoldiers.AddItem(arrValidSoldiers[soldierIndex].GetReference());
		//`log("Is soldier dead?:" @ arrValidSoldiers[soldierIndex].IsDead() @ "Index:" @ soldierIndex);
		//If the soldier is dead, use the memorial layout instead of the normal one
		If(arrValidSoldiers[soldierIndex].IsDead())
        {
	        DefaultSetupSettings.TextLayoutState = ePBTLS_DeadSoldier;
       		//`log("TextLayout before SetAutoStrings:" @ DefaultSetupSettings.TextLayoutState); 
			`PHOTOBOOTH.SetAutoTextStrings(ePBAT_SOLO, ePBTLS_DeadSoldier, DefaultSetupSettings);
			 //`log("TextLayout after SetAutoStrings:" @ DefaultSetupSettings.TextLayoutState); 
		}
		If(arrValidSoldiers[soldierIndex].bCaptured)
		{
			// Find out which chosen got us
			ChosenState = XComGameState_AdventChosen(`XCOMHISTORY.GetGameStateForObjectID(arrValidSoldiers[soldierIndex].ChosenCaptorRef.ObjectID));
			DefaultSetupSettings.TextLayoutState = ePBTLS_CapturedSoldier;			
			DefaultSetupSettings.BackgroundDisplayName = GetChosenBackgroundName(ChosenState);
			//`log("Background name:" @ DefaultSetupSettings.BackgroundDisplayName);
			`PHOTOBOOTH.SetBackgroundTexture(GetChosenBackgroundName(ChosenState));
			`PHOTOBOOTH.SetTextLayoutByType(eTLT_Captured);
			`PHOTOBOOTH.SetAutoTextStrings(ePBAT_SOLO, DefaultSetupSettings.TextLayoutState, DefaultSetupSettings);
		}
	//`log("TextLayout before SuperBase:" @ DefaultSetupSettings.TextLayoutState); 
	super(UIPhotoboothBase).GenerateDefaultSoldierSetup();
	//`log("TextLayout after SuperBase:" @ DefaultSetupSettings.TextLayoutState); 
	}
	else
	{
	//`log("TextLayout before Super:" @ DefaultSetupSettings.TextLayoutState); 
	super.GenerateDefaultSoldierSetup();
	//`log("TextLayout after Super:" @ DefaultSetupSettings.TextLayoutState); 
	}	
}

simulated function CloseScreen()
{	
	class'Engine'.static.GetEngine().GameViewport.bRenderEmptyScene = false;
	`PRESBASE.GetPhotoboothMovie().RemoveScreen(`PHOTOBOOTH.m_backgroundPoster);
	Movie.Stack.Pop(self);
	Movie.Pres.PlayUISound(eSUISound_MenuClose);
	class'UIPoseFixHelpers'.default.NMDPhotoboothActive = false;	
}

function CreatePosterCallback(StateObjectReference UnitRef)
{
	If(class'UIPoseFixHelpers'.default.NMDPhotoboothActive == true)
	{
		bWaitingOnPhoto = false;
		`PRESBASE.GetPhotoboothMovie().RemoveScreen(`PHOTOBOOTH.m_backgroundPoster);
		Movie.Pres.UICloseProgressDialog();
		CloseScreen();
	}
	else
	{
		super.CreatePosterCallback(UnitRef);
	}
}

function string GetChosenBackgroundName(XComGameState_AdventChosen ChosenState)
{
	local string BackgroundName;
	local array<BackgroundPosterOptions> arrBackgrounds;
	local int i;

	BackgroundName = class'UIPhotoboothBase'.default.m_strEmptyOption;

	if (ChosenState != None)
	{
		`PHOTOBOOTH.GetBackgrounds(arrBackgrounds, ePBT_CHOSEN);

		for (i = 0; i < arrBackgrounds.Length; ++i)
		{
			if (arrBackgrounds[i].BackgroundDisplayName == ChosenState.GetChosenClassName())
			{
				BackgroundName = arrBackgrounds[i].BackgroundDisplayName;
				break;
			}
		}
	}
	return BackgroundName;
}

function int SetRandomAnimationPoseForSoldier(int LocationIndex, optional bool bPreventDuplicates = false, optional out array<AnimationPoses> arrAnimationsAlreadyUsed)
{
	local array<AnimationPoses> arrAnimations, arrOrigAnimations, arrFiltered;
	local int AnimationIndex, i, Rolls;
	local XComGameState_Unit Unit;
	local array<Photobooth_AnimationFilterType> ClassFilters; // Issue #309
	local Photobooth_AnimationFilterType ClassFilter;
	local bool bUseClassPose, bPoseNotFound;

	AnimationIndex = 0;
	if (LocationIndex >= 0 && LocationIndex < `PHOTOBOOTH.m_arrUnits.Length && `PHOTOBOOTH.m_arrUnits[locationIndex].UnitRef.ObjectID > 0)
	{
		`PHOTOBOOTH.GetAnimations(LocationIndex, arrOrigAnimations, , class'UIPoseFixHelpers'.default.enableMemorialPoseFiltering && DefaultSetupSettings.TextLayoutState == ePBTLS_DeadSoldier, true);

		// Skip blacklisted poses. Falls back to the unfiltered list if
		// filtering would leave nothing to roll from.
		arrFiltered = arrOrigAnimations;
		class'BD_PoseListFixer_MCMScreen'.static.FilterExcludedPoses(arrFiltered);
		if (arrFiltered.Length > 0)
		{
			arrOrigAnimations = arrFiltered;
		}

		Rolls = bPreventDuplicates ? 100 : 1;
		while (--Rolls >= 0)
		{
			arrAnimations = arrOrigAnimations;
			ClassFilter = ePAFT_None;

			Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(`PHOTOBOOTH.m_arrUnits[locationIndex].UnitRef.ObjectID));
			if (Unit != none)
			{
				// Start Issue #309
				ClassFilters = class'X2PhotoboothHelpers'.static.GetClassFiltersForClass(Unit.GetSoldierClassTemplateName());
				ClassFilter = ClassFilters[0];
				// End Issue #309
			}

			if (ClassFilter != ePAFT_None && DefaultSetupSettings.TextLayoutState != ePBTLS_DeadSoldier)
			{
				bUseClassPose = false;
				for (i = 0; i < m_arrClassPoseChances.length; ++i)
				{
					if (m_arrClassPoseChances[i].AnimType == ClassFilter)
					{
						bUseClassPose = `SYNC_RAND(100) < m_arrClassPoseChances[i].Chance;
						break;
					}
				}

				if (bUseClassPose)
				{
					for (i = 0; i < arrAnimations.length; ++i)
					{
						if (arrAnimations[i].AnimType != ClassFilter)
						{
							arrAnimations.Remove(i--, 1);
						}
					}
				}
			}

			AnimationIndex = `SYNC_RAND(arrAnimations.length);

			if (bPreventDuplicates)
			{
				bPoseNotFound = true;
				for (i = 0; i < arrAnimationsAlreadyUsed.Length; ++i)
				{
					if (arrAnimationsAlreadyUsed[i].AnimationName == arrAnimations[AnimationIndex].AnimationName &&
						arrAnimationsAlreadyUsed[i].AnimationOffset == arrAnimations[AnimationIndex].AnimationOffset)
					{
						bPoseNotFound = false;
						break;
					}
				}

				if (bPoseNotFound)
				{
					arrAnimationsAlreadyUsed.AddItem(arrAnimations[AnimationIndex]);
					Rolls = 0;
				}
			}
		}

		`PHOTOBOOTH.SetSoldierAnim(LocationIndex, arrAnimations[AnimationIndex].AnimationName, arrAnimations[AnimationIndex].AnimationOffset);
	}

	return AnimationIndex;
}

function SetupInitialCameraAndCapturePositions()
{
	super.SetupInitialCameraAndCapturePositions();
	m_kStudioCamera.m_fMinCameraDistance = class'UIPoseFixHelpers'.default.TacMinZoomDistance;
	m_kStudioCamera.m_fMaxCameraDistance = class'UIPoseFixHelpers'.default.TacMaxZoomDistance;
	m_kStudioCamera.SetFOV(class'UIPoseFixHelpers'.default.TacFOV);
}

function ZoomIn()
{
	m_kStudioCamera.ZoomCamera(-class'UIPoseFixHelpers'.default.TacZoomInOutAmount);	
}

function ZoomOut()
{
	m_kStudioCamera.ZoomCamera(class'UIPoseFixHelpers'.default.TaczoomInOutAmount);
}

function TPOV GetCameraPOV()
{
	local TPOV outPOV;
	
	outPOV = m_kStudioCamera.GetCameraLocationAndOrientation();
	outPOV.FOV = class'UIPoseFixHelpers'.default.TacFOV;

	return outPOV;
}


function bool isBline(string CheckForBline)
{
	local AutoGeneratedLines		LinesStruct;
	local String					Bline;
	local XComGameState_Unit		SoloUnit;
	local X2SoldierClassTemplate	SoloTemplate;
	
	SoloUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(`PHOTOBOOTH.GetCurrentSoldier(0).ObjectID));
	SoloTemplate = SoloUnit.GetSoldierClassTemplate();

	//`log("Check:" @ CheckForBline,,'BDLOG');

	//Shove all possible B-Lines into local struct
	foreach `PHOTOBOOTH.m_arrSoloBlines(Bline)
		LinesStruct.BLines.AddItem(Bline);
	foreach `PHOTOBOOTH.m_arrSoloBlines_Male(Bline)
		LinesStruct.BLines.AddItem(Bline);
	foreach `PHOTOBOOTH.m_arrSoloBlines_Female(Bline)
		LinesStruct.BLines.AddItem(Bline);
	foreach `PHOTOBOOTH.m_arrSoloMemorialBlines(Bline)
		LinesStruct.BLines.AddItem(Bline);
	foreach `PHOTOBOOTH.m_arrSoloMemorialBlines_Male(Bline)
		LinesStruct.BLines.AddItem(Bline);
	foreach `PHOTOBOOTH.m_arrSoloMemorialBlines_Female(Bline)
		LinesStruct.BLines.AddItem(Bline);
	foreach `PHOTOBOOTH.m_arrDuoBLines(Bline)
		LinesStruct.BLines.AddItem(Bline);
	foreach `PHOTOBOOTH.m_arrDuoBLines_Male(Bline)
		LinesStruct.BLines.AddItem(Bline);
	foreach `PHOTOBOOTH.m_arrDuoBLines_Female(Bline)
		LinesStruct.BLines.AddItem(Bline);
	foreach `PHOTOBOOTH.m_arrSquadBLines(Bline)
		LinesStruct.BLines.AddItem(Bline);	
	foreach SoloTemplate.PhotoboothSoloBLines_Male(Bline)
		LinesStruct.BLines.AddItem(Bline);	
	foreach SoloTemplate.PhotoboothSoloBLines_Female(Bline)
		LinesStruct.BLines.AddItem(Bline);	

	//If the first element in the saved layout is a B-line return true
	if(LinesStruct.Blines.Find(CheckForBline) != INDEX_NONE)
	{
		return true;
	}

	return false;
}

// DELEGATES
// List.SelectedIndex is a position in the list GetAnimationData built (the
// filtered, unpaginated list actually shown while browsing) - arrAnimations
// here comes straight from GetAnimations() and needs the identical filter
// applied before it's safe to index with that same position. The old
// UIPhotoboothPoseStartIndex offset this used to add doesn't apply at all -
// that's pagination state from PopulatePoseList's edit-mode list, not this
// unpaginated browsing one.
// List.SelectedIndex is a row position within the CURRENT PAGE, not an
// absolute index - this mod's own PopulatePoseList paginates the normal
// browsing list the same way it paginates the edit-mode checkbox list, not
// just GetAnimationData's full (unpaginated) filtered list. Add
// UIPhotoboothPoseStartIndex to get the absolute position in arrAnimations
// below, same as PopulatePoseList's own render loop does.
// Uses PopulatePoseList's cache (CachedFilteredAnimationPoses) instead of
// calling GetAnimations() again here - this fires on every hover/selection
// change, and a fresh native call on every mouse movement over the list
// would re-pay the same restriction-scan cost repeatedly for content that
// hasn't changed since the list was last rendered. The cache already
// reflects whichever filtering PopulatePoseList applied (or skipped, in
// blacklist mode), so no extra mode-checking is needed here.
function OnSetPose(UIList ContainerList, int ItemIndex)
{
	local int CurrAnimationIndex, AbsoluteIndex, i;

	CurrAnimationIndex = INDEX_NONE;
	for (i = 0; i < CachedFilteredAnimationPoses.Length; ++i)
	{
		if (CachedFilteredAnimationPoses[i].AnimationName == `PHOTOBOOTH.m_arrUnits[m_iLastTouchedSoldierIndex].AnimationName &&
			CachedFilteredAnimationPoses[i].AnimationOffset == `PHOTOBOOTH.m_arrUnits[m_iLastTouchedSoldierIndex].AnimationOffset)
		{
			CurrAnimationIndex = i;
			break;
		}
	}

	AbsoluteIndex = class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex + List.SelectedIndex;

	if (AbsoluteIndex != CurrAnimationIndex && AbsoluteIndex >= 0 && AbsoluteIndex < CachedFilteredAnimationPoses.Length)
	{
		`PHOTOBOOTH.SetSoldierAnim(m_iLastTouchedSoldierIndex, CachedFilteredAnimationPoses[AbsoluteIndex].AnimationName, CachedFilteredAnimationPoses[AbsoluteIndex].AnimationOffset);
	}
}

function OnSelectNext(optional UIButton nextItemsButton)
{	
	`SOUNDMGR.PlaySoundEvent("Generic_Mouse_Click");
	if(currentState == eUIPropagandaType_Pose)
	{
		class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex += class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay;
		class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex += class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay;
		List.OnSelectionChanged = none;
		currentState = eUIPropagandaType_Pose;
		NeedsPopulateData();
	}
}

function OnSelectPrevious(optional UIButton previousItemsButton)
{		
	`SOUNDMGR.PlaySoundEvent("Generic_Mouse_Click");
	if(currentState == eUIPropagandaType_Pose)
	{
		class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex -= class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay;
		class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex -= class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay;
		List.OnSelectionChanged = none;
		currentState = eUIPropagandaType_Pose;
		NeedsPopulateData();
	}
}

function OnToggleBlacklistMode()
{
	if (currentState != eUIPropagandaType_Pose)
	{
		return;
	}

	bPoseBlacklistModeActive = !bPoseBlacklistModeActive;
	bGroupRestrictModeActive = false;

	// Turning the toggle off: excluding a pose doesn't retroactively change
	// a soldier already wearing it - if that's what just happened, reroll a
	// valid replacement rather than leaving them stuck on a pose that's now
	// hidden from the normal list.
	if (!bPoseBlacklistModeActive && class'BD_PoseListFixer_MCMScreen'.static.IsPoseExcluded(
		`PHOTOBOOTH.m_arrUnits[m_iLastTouchedSoldierIndex].AnimationName,
		`PHOTOBOOTH.m_arrUnits[m_iLastTouchedSoldierIndex].AnimationOffset))
	{
		SetRandomAnimationPoseForSoldier(m_iLastTouchedSoldierIndex);
	}

	List.OnSelectionChanged = none;
	RefreshPoseModeListSelection();
	NeedsPopulateData();
}

function OnToggleGroupRestrictMode()
{
	local X2PropagandaPhotoTemplateManager PhotoTemplateManager;
	local X2PropagandaPhotoTemplate ReviewFormation;

	if (currentState != eUIPropagandaType_Pose)
	{
		return;
	}

	bGroupRestrictModeActive = !bGroupRestrictModeActive;
	bPoseBlacklistModeActive = false;

	// Switch to a dedicated formation with no restrictions ever generated
	// against it (see REVIEW_FORMATION_NAME), so RestrictedFromFormation()
	// can't hide anything from this review list - restore the real
	// formation on exit. m_kFormationTemplate has no custom setter/hook
	// visible from source, so this should be a pure data-layer redirect for
	// filtering purposes, not something that repositions pawns - worth
	// confirming in-game.
	PhotoTemplateManager = class'X2PropagandaPhotoTemplateManager'.static.GetPropagandaPhotoTemplateManager();
	if (bGroupRestrictModeActive)
	{
		SavedFormationBeforeGroupRestrictReview = `PHOTOBOOTH.m_kFormationTemplate;
		ReviewFormation = PhotoTemplateManager.FindUberTemplate("Formation", class'BD_PoseListFixer_MCMScreen'.const.REVIEW_FORMATION_NAME);
		if (ReviewFormation != none)
		{
			`PHOTOBOOTH.m_kFormationTemplate = ReviewFormation;
		}
		else
		{
			`log("BD_PoseFixReview formation not found - add its +PhotoboothTemplateConfig entry to XComContent.ini. Group-restrict review will still work, but won't be immune to the currently-selected formation's own restrictions.",,'BDLOG');
		}
	}
	else if (SavedFormationBeforeGroupRestrictReview != none)
	{
		// Flush what OnGroupRestrictCheckboxToggled deferred: one save,
		// plus a sync of just this session's actual clicks (see
		// FlushDirtyGroupPoseRestrictions) instead of both per click.
		class'BD_PoseListFixer_MCMScreen'.static.PersistGroupRestrictions();
		FlushDirtyGroupPoseRestrictions();

		`PHOTOBOOTH.m_kFormationTemplate = SavedFormationBeforeGroupRestrictReview;
		SavedFormationBeforeGroupRestrictReview = none;
	}

	List.OnSelectionChanged = none;
	RefreshPoseModeListSelection();
	NeedsPopulateData();
}

// Spawns the small list near the bottom of the pose screen: an unclickable
// header row ("Pose Blacklist") plus one selectable row per edit mode.
// Built once per pose-screen visit (PopulateData) and torn down when
// backing out to SoldierData, same lifecycle the old buttons had.
function BuildPoseModeList()
{
	PoseModeList = Spawn(class'UIList', self).InitList('poseModeList', 240, 900, 312, 150);
	PoseModeList.bStickyHighlight = true;
	Spawn(class'UIMechaListItem', PoseModeList.ItemContainer).InitListItem().UpdateDataDescription(
		class'UIUtilities_Text'.static.AlignCenter(Caps(m_strPoseBlacklistHeader $ " - " $ m_strBlacklistPoses)), OnToggleBlacklistMode);
	Spawn(class'UIMechaListItem', PoseModeList.ItemContainer).InitListItem().UpdateDataDescription(
		class'UIUtilities_Text'.static.AlignCenter(Caps(m_strPoseBlacklistHeader $ " - " $ m_strGroupRestrictPoses)), OnToggleGroupRestrictMode);
	RefreshPoseModeListSelection();
}

// Highlights whichever mode row (if any) is currently active, so the list
// itself shows which edit mode is on instead of relying on a separate
// pressed/unpressed button state.
function RefreshPoseModeListSelection()
{
	if (PoseModeList == none)
	{
		return;
	}

	if (bPoseBlacklistModeActive)
	{
		PoseModeList.SetSelectedIndex(0);
	}
	else if (bGroupRestrictModeActive)
	{
		PoseModeList.SetSelectedIndex(1);
	}
	else
	{
		PoseModeList.SetSelectedIndex(INDEX_NONE);
	}
}

function OnPoseCheckboxToggled(UICheckbox CheckboxControl)
{
	local int RowIndex;

	RowIndex = List.GetItemIndex(CheckboxControl);
	if (RowIndex < 0 || RowIndex >= BlacklistModePagePoses.Length)
	{
		return;
	}

	class'BD_PoseListFixer_MCMScreen'.static.SetPoseExcluded(
		BlacklistModePagePoses[RowIndex].AnimationName,
		BlacklistModePagePoses[RowIndex].AnimationOffset,
		CheckboxControl.bChecked);
}

// Same mapping as OnPoseCheckboxToggled, but writes to GroupPoseRestrictions.
// Doesn't persist or sync live per click - the checkbox's own visual state
// reads from the persisted list directly, so both are safe to defer until
// review mode exits (OnToggleGroupRestrictMode).
function OnGroupRestrictCheckboxToggled(UICheckbox CheckboxControl)
{
	local int RowIndex, i;
	local bool bAlreadyDirty;

	RowIndex = List.GetItemIndex(CheckboxControl);
	if (RowIndex < 0 || RowIndex >= BlacklistModePagePoses.Length)
	{
		return;
	}

	class'BD_PoseListFixer_MCMScreen'.static.SetPoseGroupRestricted(
		BlacklistModePagePoses[RowIndex].AnimationName,
		BlacklistModePagePoses[RowIndex].AnimationOffset,
		CheckboxControl.bChecked,
		false);

	// Track which pose changed so the mode-exit flush only has to sync
	// this session's actual clicks, not every restriction that exists.
	bAlreadyDirty = false;
	for (i = 0; i < DirtyGroupRestrictPoses.Length; i++)
	{
		if (DirtyGroupRestrictPoses[i].AnimationName == BlacklistModePagePoses[RowIndex].AnimationName
			&& DirtyGroupRestrictPoses[i].AnimationOffset == BlacklistModePagePoses[RowIndex].AnimationOffset)
		{
			bAlreadyDirty = true;
			break;
		}
	}
	if (!bAlreadyDirty)
	{
		DirtyGroupRestrictPoses.AddItem(BlacklistModePagePoses[RowIndex]);
	}
}

function OnDefaultListChange(UIList ContainerList, int ItemIndex)
{
	class'UIPoseFixHelpers'.default.UIPhotoboothPoseOffset = class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex;
	m_iDefaultListIndex = List.SelectedIndex;
}

function OnConfirmPose()
{
	List.OnSelectionChanged = none;
	currentState = eUIPropagandaType_SoldierData;
	List.ClearItems();
	NeedsPopulateData();
}

function OnCancel()
{

	local XComPresentationLayer Pres;
	local UIMissionSummary SummaryScreen;
	Pres = `PRES;

	if (bWaitingOnPhoto)
		return;

	switch (currentState)
	{
	case eUIPropagandaType_Base:			
		If(`ISCONTROLLERACTIVE && class'UIPoseFixHelpers'.default.NMDPhotoboothActive == false)
		{
			//`log("Should be super closing screen here - Bool status:" @ class'UIPoseFixHelpers'.default.NMDPhotoboothActive,,'BDLOG');
			CloseScreen();			
			SummaryScreen = UIMissionSummary(Pres.ScreenStack.GetLastInstanceOf(class'UIMissionSummary'));
			If(SummaryScreen != none)
			{
				SummaryScreen.Show();
			}
		}
		else
		{
			CloseScreen();
		}
	break;	
	case eUIPropagandaType_Soldier:
		m_bRotatingPawn = false;
	case eUIPropagandaType_Pose:
		//bsg-jneal (5.16.17): now changing pose on selection change so need to remember initial pose when cancelling menu
		//List.SetSelectedIndex(m_bOriginalSubListIndex);
		// Uses PopulatePoseList's cache (CachedFilteredAnimationPoses)
		// instead of a fresh GetAnimations() call - this was previously
		// fetched unconditionally at the top of OnCancel for every single
		// Cancel/Back press throughout the whole photobooth, even though
		// it's only ever used here. The cache already reflects whatever
		// filtering was applied when the pose list was last rendered,
		// matching the same filtered space m_bOriginalSubListIndex was
		// captured in.
		if (m_bOriginalSubListIndex >= 0 && m_bOriginalSubListIndex < CachedFilteredAnimationPoses.Length)
		{
			`PHOTOBOOTH.SetSoldierAnim(m_iLastTouchedSoldierIndex, CachedFilteredAnimationPoses[m_bOriginalSubListIndex].AnimationName, CachedFilteredAnimationPoses[m_bOriginalSubListIndex].AnimationOffset);
		}
		//List.SetSelectedIndex(m_bOriginalSubListIndex);
		List.OnSelectionChanged = none;		
		//bsg-jneal (5.16.17): end
		currentState = eUIPropagandaType_SoldierData;
		break;

	//bsg-jedwards (5.1.17) : Hide color selector if backing out
	//case eUIPropagandaType_GradientColor1:
	//case eUIPropagandaType_GradientColor2:
	//	ColorSelector.Hide();
	//	currentState = eUIPropagandaType_Base;
	//	break;
	//bsg-jedwards (5.1.17) : end
	//bsg-jneal (5.23.17): updating certain list indices for poster previews on selection changed
	case eUIPropagandaType_Formation:
	case eUIPropagandaType_Layout:
	case eUIPropagandaType_Filter:
	case eUIPropagandaType_Treatment:
		List.SetSelectedIndex(m_bOriginalSubListIndex);
		List.OnSelectionChanged = none;
	case eUIPropagandaType_SoldierData:
	case eUIPropagandaType_BackgroundOptions:
	case eUIPropagandaType_Graphics:
		currentState = eUIPropagandaType_Base;
		break;
	
	case eUIPropagandaType_GradientColor1:
	case eUIPropagandaType_GradientColor2:
		ColorSelector.Hide();
		SetTextColor(m_iPreviousColor);
		currentState = eUIPropagandaType_BackgroundOptions;
		break;
	case eUIPropagandaType_Background:
		List.SetSelectedIndex(m_bOriginalSubListIndex);
		List.OnSelectionChanged = none;
		currentState = eUIPropagandaType_BackgroundOptions;
		break;
	case eUIPropagandaType_TextColor:
		ColorSelector.Hide();
		SetTextColor(m_iPreviousColor);
		currentState = eUIPropagandaType_Graphics;
		break;
	//bsg-jneal (5.23.17): end
	case eUIPropagandaType_TextFont:
	case eUIPropagandaType_Fonts:
		currentState = eUIPropagandaType_Graphics;
		break;
	}
	List.ClearItems();
	NeedsPopulateData();
}

// Over-riding fully so that Filter and Effects can be moved into Background Options 
function PopulateDefaultList(out int Index)
{
	local XGParamTag ParamTag;

	ParamTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	ParamTag.IntValue0 = m_kTacticalLocation.m_iCurrentStudioIndex + 1;
	GetListItem(Index++).UpdateDataSpinner(m_LocationTitle, `XEXPAND.ExpandString(m_LocationStr), OnChangeStudioLocation);

	GetListItem(Index++).UpdateDataValue(m_CategoryFormations, `PHOTOBOOTH.m_kFormationTemplate.DisplayName, OnClickFormation);
	GetListItem(Index++).UpdateDataDescription(m_CategorySoldiers, OnClickSoldiers);
	GetListItem(Index++).UpdateDataDescription(m_CategoryBackgroundOptions, OnClickBackgroundOptions);
	GetListItem(Index++).UpdateDataValue(m_CategoryLayout, `PHOTOBOOTH.m_currentTextLayoutTemplate.DisplayName, OnClickTextLayout);

	GetListItem(Index++).UpdateDataDescription(m_CategoryGraphics, OnClickGraphics);
	if (bChallengeMode)
	{
		GetListItem(Index - 1).SetDisabled(true);
	}

	GetListItem(Index++).UpdateDataCheckbox(m_CategoryHidePoster, "", IsPosterTextHidden(), OnHidePoster);

	//bsg-jedwards (5.1.17) : Adds Spinner to the options when using a controller
	if(`ISCONTROLLERACTIVE)
	{
		GetListItem(Index++).UpdateDataSpinner(m_CategoryCameraPresets, m_CameraPresets_Labels[ModeSpinnerVal], UpdateMode_OnChanged);
	}
	//bsg-jedwards (5.1.17) : end

	GetListItem(Index++).UpdateDataDescription(m_CategoryRandom, OnRandomize);

	List.OnSelectionChanged = OnDefaultListChange; //bsg-jneal (5.23.17): saving default list index for better nav

	GetListItem(Index++).UpdateDataDescription(m_CategoryRandom @ m_CategoryBackground $ " / " $ m_LocationTitle, OnClickedRandomizeBackground);
	GetListItem(Index++).UpdateDataDescription(m_CategoryRandom @ m_CategoryGraphics, OnClickedRandomizeText);
	GetListItem(Index++).UpdateDataDescription(m_CategoryRandom @ m_CategoryLayout, OnClickedRandomizeLayout);
	GetListItem(Index++).UpdateDataDescription(m_CategoryRandom @ m_PrefixPose, OnClickedRandomizePose);
	GetListItem(Index++).UpdateDataSpinner(m_CategoryLayout @ class'UIOptionsPCScreen'.default.m_strGraphicsLabel_Preset, class'UIPoseFix_SaveLayout'.default.SelectedLayoutSlot == -1 ? m_CategoryRandom : string(class'UIPoseFix_SaveLayout'.default.SelectedLayoutSlot + 1), OnLayoutSlotChanged);
	GetListItem(Index++).UpdateDataDescription(class'UIMPShell_SquadEditor_Preset'.default.m_strReadyButtonText @ m_CategoryLayout @ class'UIOptionsPCScreen'.default.m_strGraphicsLabel_Preset, OnClickedSaveLayout);
	GetListItem(Index++).UpdateDataSpinner(class'UIPoseFixHelpers'.default.NMDPhotoboothActive ? m_strNMD @ m_PrefixPose @ class'UIOptionsPCScreen'.default.m_strGraphicsLabel_Preset : m_PrefixPose @ class'UIOptionsPCScreen'.default.m_strGraphicsLabel_Preset, class'UIPoseFix_SaveSquad'.static.GetSelectedSlot(GetSquadContext()) == -1 ? m_CategoryRandom : string(class'UIPoseFix_SaveSquad'.static.GetSelectedSlot(GetSquadContext()) + 1), OnSquadSlotChanged);
	GetListItem(Index++).UpdateDataDescription(class'UIPoseFixHelpers'.default.NMDPhotoboothActive ? class'UIMPShell_SquadEditor_Preset'.default.m_strReadyButtonText @ caps(m_strNMD) @ m_PrefixPose @ class'UIOptionsPCScreen'.default.m_strGraphicsLabel_Preset : class'UIMPShell_SquadEditor_Preset'.default.m_strReadyButtonText @ m_PrefixPose @ class'UIOptionsPCScreen'.default.m_strGraphicsLabel_Preset, OnClickedSaveSquad);
}

// Overridden to allow the filters / effects to go in the background options list
function PopulateBackgroundOptionsList(out int Index)
{
	local array<string> FilterNames;
	local int FilterIndex;

	super.PopulateBackgroundOptionsList(Index);

	GetFirstPassFilterData(FilterNames, FilterIndex);
	GetListItem(Index++).UpdateDataValue(m_CategoryFilter, FilterNames[FilterIndex], OnClickFirstPassFilter);

	FilterNames.Length = 0;
	GetSecondPassFilterData(FilterNames, FilterIndex);
	GetListItem(Index++).UpdateDataValue(m_CategoryTreatment, FilterNames[FilterIndex], OnClickSecondPassFilter);
}

function OnLayoutSlotChanged(UIListItemSpinner SpinnerControl, int Direction)
{
	local int NewSlot;

	`SOUNDMGR.PlaySoundEvent("Play_MenuSelect");
	NewSlot = class'UIPoseFix_SaveLayout'.default.SelectedLayoutSlot + Direction;
	if (NewSlot < -1)
		NewSlot = class'UIPoseFix_SaveLayout'.static.GetNumSlots() - 1;
	else if (NewSlot >= class'UIPoseFix_SaveLayout'.static.GetNumSlots())
		NewSlot = -1;

	class'UIPoseFix_SaveLayout'.static.SetSelectedSlot(NewSlot);
	SpinnerControl.SetValue(NewSlot == -1 ? m_CategoryRandom : string(NewSlot + 1));
	ApplyLayoutSlot();
}

function OnSquadSlotChanged(UIListItemSpinner SpinnerControl, int Direction)
{
	local int NewSlot;

	`SOUNDMGR.PlaySoundEvent("Play_MenuSelect");
	NewSlot = class'UIPoseFix_SaveSquad'.static.GetSelectedSlot(GetSquadContext()) + Direction;
	if (NewSlot < -1)
		NewSlot = class'UIPoseFix_SaveSquad'.static.GetNumSlots() - 1;
	else if (NewSlot >= class'UIPoseFix_SaveSquad'.static.GetNumSlots())
		NewSlot = -1;

	class'UIPoseFix_SaveSquad'.static.SetSelectedSlot(GetSquadContext(), NewSlot);
	SpinnerControl.SetValue(NewSlot == -1 ? m_CategoryRandom : string(NewSlot + 1));
	ApplySquadSlot();
}

function OnClickedSaveLayout()
{	
	`SOUNDMGR.PlaySoundEvent("Play_MenuSelect");
	class'UIPoseFix_SaveLayout'.static.ClearArrays();
	class'UIPoseFix_SaveLayout'.default.SavedLayoutTemplateIndex = `PHOTOBOOTH.GetLayoutIndex();
	class'UIPoseFix_SaveLayout'.default.PosterFonts = `PHOTOBOOTH.m_PosterFont;
	class'UIPoseFix_SaveLayout'.default.PosterStringColors = `PHOTOBOOTH.m_PosterStringColors;
	class'UIPoseFix_SaveLayout'.default.HidePoster = IsPosterTextHidden();
	class'UIPoseFix_SaveLayout'.static.SaveCurrentToSlot(class'UIPoseFix_SaveLayout'.default.SelectedLayoutSlot);
	class'UIPoseFix_SaveLayout'.static.SaveLayoutConfigs();
}

// Base UITactical_Photobooth.RandomSetBackground() hardcodes ePBT_XCOM -
// see UIArmory_Photobooth_PoseFix's version of this override for why.
// Broadened to ePBT_ALL, keeping the same "prefer None if available" logic
// the base version uses (Tactical's real backdrop is the mission scene
// itself, so a plain texture background is the exception, not the rule).
// Note this only affects the base game's own initial random setup, not
// OnClickedRandomizeBackground below - that reimplements its own
// selection logic entirely rather than calling this.
function RandomSetBackground()
{
	local array<string> ItemNames;
	local int ItemIndex, i;

	GetBackgroundData(ItemNames, ItemIndex, ePBT_ALL);

	ItemIndex = INDEX_NONE;
	for (i = 0; i < ItemNames.Length; ++i)
	{
		if (ItemNames[i] == "None")
		{
			ItemIndex = i;
			break;
		}
	}

	SetBackground(ItemIndex != INDEX_NONE ? ItemIndex : `SYNC_RAND(ItemNames.Length), ePBT_ALL, false);
}

function OnClickedRandomizeBackground()
{
	local array<FilterPosterOptions> arrFilters;
	local array<string> BackgroundNames;
	local int BackgroundIndex, i;
	local UIPoseFix_SaveSquad.SavedSquadSoldierData SoldierPose;

	`SOUNDMGR.PlaySoundEvent("Play_MenuSelect");

	// 75% Chance to change the current map location to a random one
	if (`SYNC_RAND(1000) < int(class'UIPoseFixHelpers'.default.RandomizeBackgroundMapLocationChancePercent * 10))
	{
		`log("PoseFix RandomizeBackground: location branch taken",,'BDLOG');

		// SpawnStudio() respawns the soldier pawns, wiping their current
		// pose - snapshot it now so OnRandomizedLocationLoaded can restore
		// it afterward, instead of ApplySquadSlot falling back to whatever
		// the saved squad slot has (stale, or possibly no slot at all).
		PreRandomizeLocationPoses.Length = 0;
		for (i = 0; i < `PHOTOBOOTH.m_kFormationTemplate.NumSoldiers; i++)
		{
			SoldierPose.AnimationName = `PHOTOBOOTH.m_arrUnits[i].AnimationName;
			SoldierPose.AnimationOffset = `PHOTOBOOTH.m_arrUnits[i].AnimationOffset;
			PreRandomizeLocationPoses.AddItem(SoldierPose);
		}

		m_kTacticalLocation.m_iCurrentStudioIndex = `SYNC_RAND(m_kTacticalLocation.m_arrAllExits.Length);
		m_kTacticalLocation.m_OnStudioLoaded = OnRandomizedLocationLoaded;
		m_kTacticalLocation.SpawnStudio();

		// Make sure that the background is set to "None" so we dont' get armoury backgrounds
		GetBackgroundData(BackgroundNames, BackgroundIndex, ePBT_ALL);
		BackgroundIndex = INDEX_NONE;
		for (i = 0; i < BackgroundNames.Length; ++i)
		{
			if (BackgroundNames[i] == "None")
			{
				BackgroundIndex = i;
				break;
			}
		}
		if (BackgroundIndex != INDEX_NONE)
		{
			SetBackground(BackgroundIndex, ePBT_ALL, false);
		}
	}
	else
	{
		// 25% Chance for a background to be generated - broadened to
		// ePBT_ALL so Chosen-themed backgrounds (Warlock/Hunter/Assassin)
		// are eligible too, matching UIArmory_Photobooth_PoseFix's own
		// RandomSetBackground override.
		GetBackgroundData(BackgroundNames, BackgroundIndex, ePBT_ALL);
		BackgroundIndex = `SYNC_RAND(BackgroundNames.Length);
		`log("PoseFix RandomizeBackground: texture branch taken, picked index" @ BackgroundIndex @ "of" @ BackgroundNames.Length @ "(" $ BackgroundNames[BackgroundIndex] $ ")",,'BDLOG');
		SetBackground(BackgroundIndex, ePBT_ALL, false);
		// Re-roll background colours if an armoury background is selected 
		`PHOTOBOOTH.SetGradientColorIndex1(`SYNC_RAND(`PHOTOBOOTH.m_FontColors.length));
		`PHOTOBOOTH.SetGradientColorIndex2(`SYNC_RAND(`PHOTOBOOTH.m_FontColors.length));
	}
	// Small (config) chance to apply a filter
	if (`SYNC_RAND(1000) < int(class'UIPoseFixHelpers'.default.RandomizeBackgroundFilterChancePercent * 10))
	{
		`PHOTOBOOTH.GetFirstPassFilters(arrFilters);
		`PHOTOBOOTH.SetFirstPassFilter(`SYNC_RAND(arrFilters.Length - 1) + 1);
	}
	else
	{
		`PHOTOBOOTH.SetFirstPassFilter(0);
	}
	// Small (config) chance to apply an effect
	if (`SYNC_RAND(1000) < int(class'UIPoseFixHelpers'.default.RandomizeBackgroundEffectChancePercent * 10))
	{
		`PHOTOBOOTH.GetSecondPassFilters(arrFilters);
		`PHOTOBOOTH.SetSecondPassFilter(`SYNC_RAND(arrFilters.Length - 1) + 1);
	}
	else
	{
		`PHOTOBOOTH.SetSecondPassFilter(0);
	}

	NeedsPopulateData();
}

function OnRandomizedLocationLoaded()
{
	StudioLoadedUpdateCamera();
	`log("PoseFix OnRandomizedLocationLoaded: StudioLoadedUpdateCamera done, scheduling ApplySquadSlotPoseCameraOnly in" @ class'UIPoseFixHelpers'.default.PhotoboothPresetLoadDelay @ "seconds",,'BDLOG');
	// Reapply the Pose/Camera preset after randomizing
	SetTimer(class'UIPoseFixHelpers'.default.PhotoboothPresetLoadDelay, false, nameof(ApplySquadSlotPoseCameraOnly));
}

// SetTimer can't pass arguments through, so this just fixes bApplyFormation
// to false and bUseCurrentPoses to true for the deferred call above -
// reapply the live pose snapshotted before the studio respawn, not
// whatever's sitting in the saved squad slot.
function ApplySquadSlotPoseCameraOnly()
{
	`log("PoseFix ApplySquadSlotPoseCameraOnly: timer fired, calling ApplySquadSlot(false, true)",,'BDLOG');
	ApplySquadSlot(false, true);
}

function OnClickedRandomizeText()
{
	local array<string> SavedFonts;
	local array<int> SavedColors;
	local int SavedLayoutIndex;

	`SOUNDMGR.PlaySoundEvent("Play_MenuSelect");

	SavedFonts = `PHOTOBOOTH.m_PosterFont;
	SavedColors = `PHOTOBOOTH.m_PosterStringColors;
	SavedLayoutIndex = `PHOTOBOOTH.GetLayoutIndex();

	if (`PHOTOBOOTH.m_kFormationTemplate.NumSoldiers == 1)
	{
		`PHOTOBOOTH.SetAutoTextStrings(ePBAT_SOLO);
	}
	else if (`PHOTOBOOTH.m_kFormationTemplate.NumSoldiers == 2)
	{
		`PHOTOBOOTH.SetAutoTextStrings(ePBAT_DUO);
	}
	else
	{
		`PHOTOBOOTH.SetAutoTextStrings(ePBAT_SQUAD);
	}

	`PHOTOBOOTH.m_PosterFont = SavedFonts;
	`PHOTOBOOTH.m_PosterStringColors = SavedColors;
	`PHOTOBOOTH.SetLayoutIndex(SavedLayoutIndex);
	NeedsPopulateData();
}

function OnClickedRandomizeLayout()
{
	local array<string> LayoutNames;
	local array<FontOptions> arrFontOptions;
	local int i;

	`SOUNDMGR.PlaySoundEvent("Play_MenuSelect");

	GetLayoutNames(LayoutNames);
	`PHOTOBOOTH.SetLayoutIndex(`SYNC_RAND(LayoutNames.Length));

	// Re-fetch NumTextBoxes after SetLayoutIndex(), since a different layout
	// can have a different box count. Filter/effect are handled by Randomize
	// Background instead, not here.
	`PHOTOBOOTH.GetFonts(arrFontOptions);
	for (i = 0; i < `PHOTOBOOTH.m_currentTextLayoutTemplate.NumTextBoxes; i++)
	{
		`PHOTOBOOTH.SetTextBoxFont(i, arrFontOptions[`SYNC_RAND(arrFontOptions.Length)].FontName);
		`PHOTOBOOTH.SetTextBoxColor(i, `SYNC_RAND(`PHOTOBOOTH.m_FontColors.Length));
	}

	NeedsPopulateData();
}

function OnClickedRandomizePose()
{
	local int i;

	`SOUNDMGR.PlaySoundEvent("Play_MenuSelect");
	for (i = 0; i < `PHOTOBOOTH.m_kFormationTemplate.NumSoldiers; i++)
	{
		SetRandomAnimationPoseForSoldier(i);
	}
	NeedsPopulateData();
}

function OnClickedSaveSquad()
{
	local array<UIPoseFix_SaveSquad.SavedSquadSoldierData> Soldiers;
	local UIPoseFix_SaveSquad.SavedSquadSoldierData SoldierData;
	local PhotoboothCameraSettings CameraSettings;
	local Actor FormationActor;
	local Vector VecX, VecY, VecZ, WorldOffset;
	local int i;

	`SOUNDMGR.PlaySoundEvent("Play_MenuSelect");

	Soldiers.Length = 0;
	for (i = 0; i < `PHOTOBOOTH.m_kFormationTemplate.NumSoldiers; i++)
	{
		SoldierData.AnimationName = `PHOTOBOOTH.m_arrUnits[i].AnimationName;
		SoldierData.AnimationOffset = `PHOTOBOOTH.m_arrUnits[i].AnimationOffset;
		Soldiers.AddItem(SoldierData);
	}

	CameraSettings.ViewDistance = m_kStudioCamera.GetCameraDistance();

	// Both the camera's RotationPoint AND Rotation are absolute world-space
	// values are tied to whichever map "location" (m_kTacticalLocation) is
	// currently active. Store both relative to the formation placement actor's own
	// location AND rotation instead.
	FormationActor = m_kTacticalLocation.GetFormationPlacementActor();
	WorldOffset = m_kStudioCamera.GetCameraOffset() - FormationActor.Location;
	GetAxes(FormationActor.Rotation, VecX, VecY, VecZ);
	CameraSettings.RotationPoint.X = WorldOffset Dot VecX;
	CameraSettings.RotationPoint.Y = WorldOffset Dot VecY;
	CameraSettings.RotationPoint.Z = WorldOffset Dot VecZ;
	CameraSettings.Rotation = m_kStudioCamera.GetCameraTargetRotation() - FormationActor.Rotation;

	class'UIPoseFix_SaveSquad'.static.SaveSquadToSlot(GetSquadContext(), class'UIPoseFix_SaveSquad'.static.GetSelectedSlot(GetSquadContext()), string(`PHOTOBOOTH.m_kFormationTemplate.DataName), Soldiers, CameraSettings);
}

function ApplySquadSlot(optional bool bApplyFormation = true, optional bool bUseCurrentPoses = false)
{
	local array<UIPoseFix_SaveSquad.SavedSquadSoldierData> Soldiers;
	local PhotoboothCameraSettings CameraSettings;
	local array<X2PropagandaPhotoTemplate> arrFormations;
	local string FormationDataName;
	local Actor FormationActor;
	local Vector VecX, VecY, VecZ, RelativeOffset;
	local array<AnimationPoses> arrValidPoses;
	local bool bPoseValid;
	local bool bAnyPoseApplied;
	local int i, j, NumSlotsToApply;

	if (!class'UIPoseFix_SaveSquad'.static.LoadSquadFromSlot(GetSquadContext(), class'UIPoseFix_SaveSquad'.static.GetSelectedSlot(GetSquadContext()), FormationDataName, Soldiers, CameraSettings))
	{
		`log("PoseFix ApplySquadSlot: slot" @ class'UIPoseFix_SaveSquad'.static.GetSelectedSlot(GetSquadContext()) @ "is empty, nothing to apply",,'BDLOG');
		return;
	}

	// Post-randomize-location reapply: only the pose source changes here -
	// formation and camera still come from the loaded slot as usual, but
	// the poses come from PreRandomizeLocationPoses (the live in-session
	// poses from just before the studio respawn) instead of the slot.
	if (bUseCurrentPoses)
	{
		Soldiers.Length = PreRandomizeLocationPoses.Length;
		for (i = 0; i < PreRandomizeLocationPoses.Length; i++)
		{
			Soldiers[i].AnimationName = PreRandomizeLocationPoses[i].AnimationName;
			Soldiers[i].AnimationOffset = PreRandomizeLocationPoses[i].AnimationOffset;
		}
	}

	if (bApplyFormation)
	{
		`PHOTOBOOTH.GetFormations(arrFormations);
		// ChangeFormation() sets m_bFormationNeedsUpdate = true unconditionally,
		// triggering a full pawn respawn regardless of whether the formation
		// TYPE actually differs. Skip it entirely when the current formation
		// already matches the saved one, to avoid an unnecessary respawn/flicker
		// that visually looks like "the formation reset" even though it didn't.
		if (string(`PHOTOBOOTH.m_kFormationTemplate.DataName) != FormationDataName)
		{
			for (i = 0; i < arrFormations.Length; i++)
			{
				if (string(arrFormations[i].DataName) == FormationDataName)
				{
					`PHOTOBOOTH.ChangeFormation(arrFormations[i]);
					break;
				}
			}
		}
	}

	// When bApplyFormation is false, the current formation may not match
	// the one the saved pose data was captured against (different slot
	// count) - only apply pose to slots that actually exist in whatever
	// formation is currently active.
	NumSlotsToApply = Min(Soldiers.Length, `PHOTOBOOTH.m_kFormationTemplate.NumSoldiers);
	`log("PoseFix ApplySquadSlot: applying pose to" @ NumSlotsToApply @ "of" @ Soldiers.Length @ "saved soldier slots (current formation NumSoldiers =" @ `PHOTOBOOTH.m_kFormationTemplate.NumSoldiers $ ")",,'BDLOG');
	for (i = 0; i < NumSlotsToApply; i++)
	{
		arrValidPoses.Length = 0;
		`PHOTOBOOTH.GetAnimations(i, arrValidPoses);
		bPoseValid = false;
		for (j = 0; j < arrValidPoses.Length; j++)
		{
			if (arrValidPoses[j].AnimationName == Soldiers[i].AnimationName)
			{
				bPoseValid = true;
				break;
			}
		}

		if (bPoseValid)
		{
			`PHOTOBOOTH.SetSoldierAnim(i, Soldiers[i].AnimationName, Soldiers[i].AnimationOffset);
			bAnyPoseApplied = true;
		}
		else
		{
			`log("PoseFix ApplySquadSlot: saved pose" @ Soldiers[i].AnimationName @ "not valid for slot" @ i @ "'s current occupant (different class/gender?) - leaving current pose unchanged",,'BDLOG');
		}
	}

	// Only adjust the camera if the pose is valid 
	if (!bAnyPoseApplied)
	{
		`log("PoseFix ApplySquadSlot: no saved poses were valid for current occupants, skipping camera update",,'BDLOG');
		NeedsPopulateData();
		return;
	}
		
	FormationActor = m_kTacticalLocation.GetFormationPlacementActor();
	GetAxes(FormationActor.Rotation, VecX, VecY, VecZ);
	RelativeOffset = CameraSettings.RotationPoint.X * VecX + CameraSettings.RotationPoint.Y * VecY + CameraSettings.RotationPoint.Z * VecZ;
	CameraSettings.RotationPoint = FormationActor.Location + RelativeOffset;
	CameraSettings.Rotation = CameraSettings.Rotation + FormationActor.Rotation;
		
	bChangingLocation = false;
	UpdateCameraToPOV(CameraSettings, true);
	NeedsPopulateData();
}

function bool ApplyLayoutSlot()
{
	if (!class'UIPoseFix_SaveLayout'.static.LoadFromSlot(class'UIPoseFix_SaveLayout'.default.SelectedLayoutSlot))
	{
		`log("PoseFix ApplyLayoutSlot: slot" @ class'UIPoseFix_SaveLayout'.default.SelectedLayoutSlot @ "is empty, nothing to apply",,'BDLOG');
		return false;
	}

	`log("PoseFix ApplyLayoutSlot: slot" @ class'UIPoseFix_SaveLayout'.default.SelectedLayoutSlot @ "loaded, applying styling",,'BDLOG');

	// Deliberately does not touch `PHOTOBOOTH.m_PosterStrings 
	`PHOTOBOOTH.m_PosterFont = class'UIPoseFix_SaveLayout'.default.PosterFonts;
	`PHOTOBOOTH.m_PosterStringColors = class'UIPoseFix_SaveLayout'.default.PosterStringColors;
	`PHOTOBOOTH.SetLayoutIndex(class'UIPoseFix_SaveLayout'.default.SavedLayoutTemplateIndex);
	
	NeedsPopulateData();
	// Defer hide poster checkbox to ensure it updates properly
	SetTimer(0.05f, false, nameof(ApplyHidePosterDelayed));
	return true;
}

function ApplyHidePosterDelayed()
{
	local int i;

	HidePosterElements(class'UIPoseFix_SaveLayout'.default.HidePoster);

	for (i = 0; i < List.ItemCount; i++)
	{
		if (GetListItem(i).Checkbox != none)
		{
			GetListItem(i).Checkbox.SetChecked(class'UIPoseFix_SaveLayout'.default.HidePoster);
			break;
		}
	}
}

simulated function bool OnUnrealCommand(int ucmd, int arg)
{
	if(`ISCONTROLLERACTIVE && !m_bGamepadCameraActive && !CheckInputIsReleaseOrDirectionRepeat(ucmd, arg))
	return false;	

	switch (ucmd)
	{
	case class'UIUtilities_Input'.const.FXS_DPAD_LEFT:
		if(!m_bGamepadCameraActive)
		{
		OnSelectPrevious();
		}
		return true;
	case class'UIUtilities_Input'.const.FXS_DPAD_RIGHT:		
		if(!m_bGamepadCameraActive)
		{
		OnSelectNext();
		}
		return true;
	case class'UIUtilities_Input'.const.FXS_BUTTON_Y:
		return true;
	case class'UIUtilities_Input'.const.FXS_BUTTON_B:
		onCancel();
		return true;
	case class'UIUtilities_Input'.const.FXS_KEY_F:
		if (IsMouseInPoster())
		{
			ZoomIn();
		}
		break;
	case class'UIUtilities_Input'.const.FXS_KEY_C:
		if (IsMouseInPoster())
		{
			ZoomOut();
		}
		break;
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN:
				
		if (IsMouseInPoster() && ((arg & class'UIUtilities_Input'.const.FXS_ACTION_PRESS) > 0 || (arg & class'UIUtilities_Input'.const.FXS_ACTION_HOLD) > 0))
		{
				m_bRightMouseIn = true;
				Movie.Pres.m_kUIMouseCursor.UpdateMouseLocation();
		}
		else if ((arg & class'UIUtilities_Input'.const.FXS_ACTION_RELEASE) > 0)
		{
			if(!m_bRightMouseIn && `GETMCMVAR(RIGHT_CLICK_EXITS_SCREEN))
			{
				OnCancel();
			}
			m_bRightMouseIn = false;
		}
		return true;
		break;
	}
	return super.OnUnrealCommand(ucmd, arg);
}

defaultproperties
{
	// Fallback until real .int entries exist.
	m_strBlacklistPoses="ALL FORMATIONS"
	m_strGroupRestrictPoses="GROUP FORMATIONS"
	m_strPoseBlacklistHeader="EXCLUDE"
}
