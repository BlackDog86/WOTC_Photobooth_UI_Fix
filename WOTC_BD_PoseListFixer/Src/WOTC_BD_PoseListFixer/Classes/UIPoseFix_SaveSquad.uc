class UIPoseFix_SaveSquad extends object config(PoseFixSquad);

struct native SavedSquadSoldierData
{
	var name					AnimationName;
	var float					AnimationOffset;
};

struct native SavedSquadSlot
{
	var bool							bHasData;
	// X2PropagandaPhotoTemplate.DataName for the formation in use when saved.
	// Re-resolved against `PHOTOBOOTH.GetFormations() on load, since templates
	// themselves aren't config-serializable.
	var string							FormationDataName;
	var array<SavedSquadSoldierData>	Soldiers; // indexed by formation slot
	var X2Photobooth.PhotoboothCameraSettings		CameraSettings;
};

// Armory and Tactical get independent slot sets, NOT a shared one. Tactical's
// SetSoldier() targets are restricted to BATTLE().GetHumanPlayer().GetOriginalUnits()
// - i.e. only soldiers actually deployed in that mission's squad - while Armory
// can place any roster soldier into any slot. A squad preset saved in Armory
// will often reference a soldier that has no valid pawn/placement in the
// current Tactical mission, so presets don't port cleanly between screens.
var config array<SavedSquadSlot>	SavedArmorySquads;
var config int						SelectedArmorySquadSlot;
var config array<SavedSquadSlot>	SavedTacticalSquads;
var config int						SelectedTacticalSquadSlot;

static function SaveSquadConfigs()
{
	StaticSaveConfig();
}

// Number of slots, configurable via UIPoseFixHelpers.NumSquadSlots.
static function int GetNumSlots()
{
	return Max(1, class'UIPoseFixHelpers'.default.NumSquadSlots);
}

// Only ever grows each array to match the configured count - lowering the
// config value hides the extra slots but never deletes their saved data.
// Also clamps any already-stored selected slot back into range.
static function EnsureSlotsInitialized()
{
	local bool bChanged;
	local int DesiredSlots;

	DesiredSlots = GetNumSlots();
	bChanged = false;
	if (default.SavedArmorySquads.Length < DesiredSlots)
	{
		default.SavedArmorySquads.Length = DesiredSlots;
		bChanged = true;
	}
	if (default.SavedTacticalSquads.Length < DesiredSlots)
	{
		default.SavedTacticalSquads.Length = DesiredSlots;
		bChanged = true;
	}
	if (default.SelectedArmorySquadSlot >= DesiredSlots)
	{
		default.SelectedArmorySquadSlot = DesiredSlots - 1;
		bChanged = true;
	}
	if (default.SelectedTacticalSquadSlot >= DesiredSlots)
	{
		default.SelectedTacticalSquadSlot = DesiredSlots - 1;
		bChanged = true;
	}
	if (bChanged)
		SaveSquadConfigs();
}

static function int GetSelectedSlot(bool bArmory)
{
	EnsureSlotsInitialized();
	return bArmory ? default.SelectedArmorySquadSlot : default.SelectedTacticalSquadSlot;
}

// SlotIndex of -1 means "Random" - no slot is loaded or saved, leaving the
// base game's own random generation in place. SaveSquadToSlot/LoadSquadFromSlot
// already treat SlotIndex < 0 as invalid/no-op, so -1 works with no other
// changes needed there.
static function SetSelectedSlot(bool bArmory, int SlotIndex)
{
	EnsureSlotsInitialized();
	if (bArmory)
		default.SelectedArmorySquadSlot = Clamp(SlotIndex, -1, GetNumSlots() - 1);
	else
		default.SelectedTacticalSquadSlot = Clamp(SlotIndex, -1, GetNumSlots() - 1);
	SaveSquadConfigs();
}

static function bool SlotHasData(bool bArmory, int SlotIndex)
{
	EnsureSlotsInitialized();
	if (SlotIndex < 0 || SlotIndex >= GetNumSlots())
		return false;

	return bArmory ? default.SavedArmorySquads[SlotIndex].bHasData : default.SavedTacticalSquads[SlotIndex].bHasData;
}

// Builds and stores a slot from caller-supplied data. The caller (the
// UIArmory_Photobooth_PoseFix / UITactical_Photobooth_PoseFix screen) is
// responsible for reading `PHOTOBOOTH state and passing bArmory=true/false
// for its own screen, since this class has no screen/`PHOTOBOOTH context of
// its own.
static function SaveSquadToSlot(bool bArmory, int SlotIndex, string FormationDataName, array<SavedSquadSoldierData> Soldiers, X2Photobooth.PhotoboothCameraSettings CameraSettings)
{
	local SavedSquadSlot NewSlot;

	EnsureSlotsInitialized();
	if (SlotIndex < 0 || SlotIndex >= GetNumSlots())
		return;

	NewSlot.bHasData = true;
	NewSlot.FormationDataName = FormationDataName;
	NewSlot.Soldiers = Soldiers;
	NewSlot.CameraSettings = CameraSettings;

	if (bArmory)
		default.SavedArmorySquads[SlotIndex] = NewSlot;
	else
		default.SavedTacticalSquads[SlotIndex] = NewSlot;
	SaveSquadConfigs();
}

// Returns false (and leaves out-params untouched) if the slot is empty.
static function bool LoadSquadFromSlot(bool bArmory, int SlotIndex, out string FormationDataName, out array<SavedSquadSoldierData> Soldiers, out X2Photobooth.PhotoboothCameraSettings CameraSettings)
{
	EnsureSlotsInitialized();
	if (SlotIndex < 0 || SlotIndex >= GetNumSlots())
		return false;

	if (bArmory)
	{
		if (!default.SavedArmorySquads[SlotIndex].bHasData)
			return false;

		FormationDataName = default.SavedArmorySquads[SlotIndex].FormationDataName;
		Soldiers = default.SavedArmorySquads[SlotIndex].Soldiers;
		CameraSettings = default.SavedArmorySquads[SlotIndex].CameraSettings;
	}
	else
	{
		if (!default.SavedTacticalSquads[SlotIndex].bHasData)
			return false;

		FormationDataName = default.SavedTacticalSquads[SlotIndex].FormationDataName;
		Soldiers = default.SavedTacticalSquads[SlotIndex].Soldiers;
		CameraSettings = default.SavedTacticalSquads[SlotIndex].CameraSettings;
	}
	return true;
}
