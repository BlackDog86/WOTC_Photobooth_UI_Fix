class UIPoseFix_SaveLayout extends object config(PoseFixLayout);

// Live tracking of the current poster's text 
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
// Visual styling captured/restored by the layout slots - deliberately just
// the poster template and text styling. Background texture/tint/filters
// are a separate concept (see UIPoseFix_SaveBackground) - they used to
// live here too, which meant switching layout also silently changed the
// background's look.
var config bool				HidePoster;

// Named layout slots. A slot snapshots everything above (except the live
// text-tracking scalars, which aren't part of a slot) at the moment of Save.
struct native SavedLayoutSlot
{
	var bool			bHasData;
	var int				SavedLayoutTemplateIndex;
	var array<string>	PosterFonts;
	var array<int>		PosterStringColors;
	var bool			HidePoster;
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

// Called once on init from PopulateData/OnInit before touching slots
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
// base game's own random generation in place
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
	NewSlot.HidePoster = default.HidePoster;

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
	default.HidePoster = default.SavedLayouts[SlotIndex].HidePoster;

	SaveLayoutConfigs();
	return true;
}
