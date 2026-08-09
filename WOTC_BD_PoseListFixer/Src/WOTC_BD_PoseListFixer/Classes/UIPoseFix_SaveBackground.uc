class UIPoseFix_SaveBackground extends object config(PoseFixBackground);

// Armory-only: everything about how the background LOOKS (texture, tint
// colours, whether tinting is on, both filters) - independent of the
// "Layout" preset (fonts/poster template/text colours, see
// UIPoseFix_SaveLayout) and independent of pose/squad presets. Not offered
// on Tactical, where the background is the mission location itself, not
// something to preset.
var config int		SavedBackgroundIndex;
var config bool		bOverrideBackgroundTextureColor;
var config int		GradientColor1Index;
var config int		GradientColor2Index;
var config int		FirstPassFilterIndex;
var config int		SecondPassFilterIndex;

// Named background slots. A slot snapshots everything above at the moment
// of Save.
struct native SavedBackgroundSlot
{
	var bool	bHasData;
	var int		BackgroundIndex;
	var bool	bOverrideBackgroundTextureColor;
	var int		GradientColor1Index;
	var int		GradientColor2Index;
	var int		FirstPassFilterIndex;
	var int		SecondPassFilterIndex;
};

var config array<SavedBackgroundSlot>	SavedBackgrounds;
var config int							SelectedBackgroundSlot;

static function SaveBackgroundConfigs()
{
	StaticSaveConfig();
}

// Number of slots, configurable via UIPoseFixHelpers.NumBackgroundSlots.
static function int GetNumSlots()
{
	return Max(1, class'UIPoseFixHelpers'.default.NumBackgroundSlots);
}

// Called once on init from PopulateData/OnInit before touching slots
static function EnsureSlotsInitialized()
{
	if (default.SavedBackgrounds.Length < GetNumSlots())
	{
		default.SavedBackgrounds.Length = GetNumSlots();
		SaveBackgroundConfigs();
	}
	if (default.SelectedBackgroundSlot >= GetNumSlots())
	{
		default.SelectedBackgroundSlot = GetNumSlots() - 1;
		SaveBackgroundConfigs();
	}
}

// SlotIndex of -1 means "Random" - no slot is loaded or saved, leaving the
// base game's own random generation in place
static function SetSelectedSlot(int SlotIndex)
{
	EnsureSlotsInitialized();
	default.SelectedBackgroundSlot = Clamp(SlotIndex, -1, GetNumSlots() - 1);
	SaveBackgroundConfigs();
}

static function bool SlotHasData(int SlotIndex)
{
	EnsureSlotsInitialized();
	if (SlotIndex < 0 || SlotIndex >= GetNumSlots())
		return false;

	return default.SavedBackgrounds[SlotIndex].bHasData;
}

// Snapshots the current live-tracked background fields into SlotIndex.
static function SaveCurrentToSlot(int SlotIndex)
{
	local SavedBackgroundSlot NewSlot;

	EnsureSlotsInitialized();
	if (SlotIndex < 0 || SlotIndex >= GetNumSlots())
		return;

	NewSlot.bHasData = true;
	NewSlot.BackgroundIndex = default.SavedBackgroundIndex;
	NewSlot.bOverrideBackgroundTextureColor = default.bOverrideBackgroundTextureColor;
	NewSlot.GradientColor1Index = default.GradientColor1Index;
	NewSlot.GradientColor2Index = default.GradientColor2Index;
	NewSlot.FirstPassFilterIndex = default.FirstPassFilterIndex;
	NewSlot.SecondPassFilterIndex = default.SecondPassFilterIndex;

	default.SavedBackgrounds[SlotIndex] = NewSlot;
	SaveBackgroundConfigs();
}

// Copies SlotIndex back into the live-tracked background fields, so
// ApplyBackgroundSlot (which reads from the scalar defaults) keeps working
// unmodified.
static function bool LoadFromSlot(int SlotIndex)
{
	EnsureSlotsInitialized();
	if (SlotIndex < 0 || SlotIndex >= GetNumSlots() || !default.SavedBackgrounds[SlotIndex].bHasData)
		return false;

	default.SavedBackgroundIndex = default.SavedBackgrounds[SlotIndex].BackgroundIndex;
	default.bOverrideBackgroundTextureColor = default.SavedBackgrounds[SlotIndex].bOverrideBackgroundTextureColor;
	default.GradientColor1Index = default.SavedBackgrounds[SlotIndex].GradientColor1Index;
	default.GradientColor2Index = default.SavedBackgrounds[SlotIndex].GradientColor2Index;
	default.FirstPassFilterIndex = default.SavedBackgrounds[SlotIndex].FirstPassFilterIndex;
	default.SecondPassFilterIndex = default.SavedBackgrounds[SlotIndex].SecondPassFilterIndex;

	SaveBackgroundConfigs();
	return true;
}
