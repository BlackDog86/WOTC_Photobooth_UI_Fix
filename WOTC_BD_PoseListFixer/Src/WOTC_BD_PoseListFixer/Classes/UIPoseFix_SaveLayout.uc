class UIPoseFix_SaveLayout extends object config(PoseFixLayout);

// Live tracking of the current poster's text (kept updated continuously by
// OnInit/PopulateData in UIArmory_Photobooth_PoseFix / UITactical_Photobooth_PoseFix).
// NOTE: no longer consumed by Load - Save/Load Layout intentionally leaves the
// randomized poster text alone. Kept only because OnInit's retry loop still
// compares NumberOfNonBlankLinesInSavedLayout against freshly-generated text
// to avoid handing out a font/color array shorter than the current text.
var config int				SavedLayoutTemplateIndex;
var config int				NumberOfNonBlankLinesInSavedLayout;
var config int				NumberOfNonBlankLinesInCurrentLayout;
var config array<string>	PosterFonts;
var config array<int>		PosterStringColors;
var config bool				bIsFirstLineBline;
var config string			lastBline;
var config string			lastAline;
var config string			lastOpline;
var config bool				hasOpline;

// Visual styling captured/restored by the layout slots. Deliberately excludes
// the poster text itself (m_PosterStrings) - that stays whatever was
// randomized for the current photo.
var config int				FirstPassFilterIndex;
var config int				SecondPassFilterIndex;
var config int				GradientColor1Index;
var config int				GradientColor2Index;

// Named layout slots. A slot snapshots everything above (except the live
// text-tracking scalars, which aren't part of a slot) at the moment of Save.
struct native SavedLayoutSlot
{
	var bool			bHasData;
	var int				SavedLayoutTemplateIndex;
	var array<string>	PosterFonts;
	var array<int>		PosterStringColors;
	var int				FirstPassFilterIndex;
	var int				SecondPassFilterIndex;
	var int				GradientColor1Index;
	var int				GradientColor2Index;
};

var config array<SavedLayoutSlot>	SavedLayouts;
var config int						SelectedLayoutSlot;

static function SaveLayoutConfigs()
{
	StaticSaveConfig();
}

static function ClearArrays()
{	
	default.PosterFonts.Length = 0;
	default.PosterStringColors.Length = 0;	
	SaveLayoutConfigs();
}

// Number of slots, configurable via UIPoseFixHelpers.NumLayoutSlots.
static function int GetNumSlots()
{
	return Max(1, class'UIPoseFixHelpers'.default.NumLayoutSlots);
}

// Call once on init from PopulateData/OnInit before touching slots, mirrors
// how the rest of the class relies on StaticSaveConfig() to persist defaults.
// Only ever grows the array to match the configured count - lowering the
// config value hides the extra slots but never deletes their saved data.
static function EnsureSlotsInitialized()
{
	if (default.SavedLayouts.Length < GetNumSlots())
	{
		default.SavedLayouts.Length = GetNumSlots();
		SaveLayoutConfigs();
	}
	if (default.SelectedLayoutSlot >= GetNumSlots())
	{
		default.SelectedLayoutSlot = GetNumSlots() - 1;
		SaveLayoutConfigs();
	}
}

// SlotIndex of -1 means "Random" - no slot is loaded or saved, leaving the
// base game's own random generation in place. SaveCurrentToSlot/LoadFromSlot
// already treat SlotIndex < 0 as invalid/no-op, so -1 works with no other
// changes needed there.
static function SetSelectedSlot(int SlotIndex)
{
	EnsureSlotsInitialized();
	default.SelectedLayoutSlot = Clamp(SlotIndex, -1, GetNumSlots() - 1);
	SaveLayoutConfigs();
}

static function bool SlotHasData(int SlotIndex)
{
	EnsureSlotsInitialized();
	if (SlotIndex < 0 || SlotIndex >= GetNumSlots())
		return false;

	return default.SavedLayouts[SlotIndex].bHasData;
}

// Snapshots the current live-tracked styling fields into SlotIndex. Text
// (lastAline/lastBline/lastOpline/etc.) is intentionally NOT part of the slot.
static function SaveCurrentToSlot(int SlotIndex)
{
	local SavedLayoutSlot NewSlot;

	EnsureSlotsInitialized();
	if (SlotIndex < 0 || SlotIndex >= GetNumSlots())
		return;

	NewSlot.bHasData = true;
	NewSlot.SavedLayoutTemplateIndex = default.SavedLayoutTemplateIndex;
	NewSlot.PosterFonts = default.PosterFonts;
	NewSlot.PosterStringColors = default.PosterStringColors;
	NewSlot.FirstPassFilterIndex = default.FirstPassFilterIndex;
	NewSlot.SecondPassFilterIndex = default.SecondPassFilterIndex;
	NewSlot.GradientColor1Index = default.GradientColor1Index;
	NewSlot.GradientColor2Index = default.GradientColor2Index;

	default.SavedLayouts[SlotIndex] = NewSlot;
	SaveLayoutConfigs();
}

// Copies SlotIndex back into the live-tracked styling fields, so existing
// OnClickedLoadSettings code (which reads from the scalar defaults) keeps
// working unmodified. Does not touch text tracking.
static function bool LoadFromSlot(int SlotIndex)
{
	EnsureSlotsInitialized();
	if (SlotIndex < 0 || SlotIndex >= GetNumSlots() || !default.SavedLayouts[SlotIndex].bHasData)
		return false;

	default.SavedLayoutTemplateIndex = default.SavedLayouts[SlotIndex].SavedLayoutTemplateIndex;
	default.PosterFonts = default.SavedLayouts[SlotIndex].PosterFonts;
	default.PosterStringColors = default.SavedLayouts[SlotIndex].PosterStringColors;
	default.FirstPassFilterIndex = default.SavedLayouts[SlotIndex].FirstPassFilterIndex;
	default.SecondPassFilterIndex = default.SavedLayouts[SlotIndex].SecondPassFilterIndex;
	default.GradientColor1Index = default.SavedLayouts[SlotIndex].GradientColor1Index;
	default.GradientColor2Index = default.SavedLayouts[SlotIndex].GradientColor2Index;

	SaveLayoutConfigs();
	return true;
}
