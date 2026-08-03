class UIPoseFixHelpers extends object config(Game);

var config int UIPhotoboothNumberOfPosesToDisplay;
var config int UIPhotoboothPoseStartIndex;
var config int UIPhotoboothPoseEndIndex;
var config int UIPhotoboothPoseOffset;
var config int UIPhotoboothSoldierIndex;
var config int UIDebriefSoldierIndex;
var config bool NMDPhotoboothActive;
var config bool EnableMemorialPoseFiltering;
var config float TacZoomInOutAmount;
var config float StratZoomInOutAmount;
var config float TacMinZoomDistance;
var config float TacMaxZoomDistance;
var config float StratMinZoomDistance;
var config float StratMaxZoomDistance;
var config float TacFOV;
var config float StratFOV;
var config int SavedLayoutTemplateIndex;
// Chance (percent, supports one decimal place e.g. 2.5) that "Randomize
// Background" also applies a non-None first-pass filter / second-pass
// filter ("effect"). Checked as SYNC_RAND(1000) < chance*10 for one decimal
// place of precision. Default via XComGame.ini: 10.0 / 2.5.
var config float RandomizeBackgroundFilterChancePercent;
var config float RandomizeBackgroundEffectChancePercent;
// Tactical only: chance (percent, one decimal place) that "Randomize
// Background" changes the map Location instead of picking a standard
// background texture. Default via XComGame.ini: 75.0.
var config float RandomizeBackgroundMapLocationChancePercent;
// Number of Layout / Pose-Camera save slots shown as spinners. Slot storage
// only ever grows to match this on load (EnsureSlotsInitialized) - lowering
// it hides the extra slots from the UI but never deletes their saved data,
// so raising it again brings them back.
var config int NumLayoutSlots;
var config int NumSquadSlots;
// Fixed delay (seconds) after OnInit before applying the saved Layout/Pose
// Camera presets. Needed because the base game's own random setup and
// formation/pawn creation both continue asynchronously after OnInit returns,
// so applying saved presets immediately gets overwritten once that finishes.
// The poster is hidden for this whole delay, so it's not visible as a flash
// - but slower machines may need a longer delay for presets to stick, while
// faster ones can shorten it. Default via XComGame.ini: 0.15.
var config float PhotoboothPresetLoadDelay;

static function bool IsValidNMDPhotoboothSoldier (XComGameState_Unit Unit)
{

	switch (Unit.GetMyTemplateName())
	{
	case 'Soldier_VIP':
	case 'Scientist_VIP':
	case 'Engineer_VIP':
	case 'FriendlyVIPCivilian':
	case 'HostileVIPCivilian':
	case 'CommanderVIP':
	case 'Engineer':
	case 'Scientist':
	case 'StasisSuitVIP':
		return false;
	}

	if (Unit.IsSoldier() && Unit.GhostSourceUnit.ObjectID == 0)
	{
		return true;
	}

	return false;
}

// DEPRECIATED STUFF - LEAVE HERE IN CASE NEEDED LATER
/*
	if(class'UIPoseFix_SaveLayout'.default.NumberOfNonBlankLinesInCurrentLayout == class'UIPoseFix_SaveLayout'.default.NumberOfNonBlankLinesInSavedLayout)
	{
		`PHOTOBOOTH.m_PosterStrings = class'UIPoseFix_SaveLayout'.default.PosterStrings;	

		if(class'UIPoseFix_SaveLayout'.default.bIsFirstLineBline)
		{
			// Clear out A Line (Always pos. 0)
			`PHOTOBOOTH.m_PosterStrings[0] = "";
		}
		else
		{
			// Clear out B Line (Always pos. 1)
			`PHOTOBOOTH.m_PosterStrings[1] = "";
		}
	}

	else if(class'UIPoseFix_SaveLayout'.default.NumberOfNonBlankLinesInCurrentLayout > class'UIPoseFix_SaveLayout'.default.NumberOfNonBlankLinesInSavedLayout)
	{
		`log(class'UIPoseFix_SaveLayout'.default.NumberOfNonBlankLinesInCurrentLayout @ "Blank lines in current - " @ class'UIPoseFix_SaveLayout'.default.NumberOfNonBlankLinesInSavedLayout @ "In saved",,'BDLOG');
		
		if(!class'UIPoseFix_SaveLayout'.default.bIsFirstLineBline)
		{
			for(i = 0; i < `PHOTOBOOTH.m_PosterStrings.Length; i++)
			{			
				`PHOTOBOOTH.m_PosterStrings[i] = "";
			}
			`PHOTOBOOTH.m_PosterStrings[0] = class'UIPoseFix_SaveLayout'.default.lastALine;
		}
		else
		{
			for(i = 0; i < `PHOTOBOOTH.m_PosterStrings.Length; i++)
			{			
				`PHOTOBOOTH.m_PosterStrings[i] = "";
			}
			`PHOTOBOOTH.m_PosterStrings[0] = class'UIPoseFix_SaveLayout'.default.lastBLine;
		}	
	}
	// There must be less blank lines in the active layout than the saved one, so we need to add additional 
	// elements back in (which we can hopefully get from the config array)
	else
	{	
		for(i = 0; i < class'UIPoseFix_SaveLayout'.default.PosterStrings.Length; i++)
		{			
		//	`log("ConfigPosterStringsOnLoad:" @ class'UIPoseFix_SaveLayout'.default.PosterStrings[i],,'BDLOG');
			currentLineIsBline = false;
			If(isBLine(class'UIPoseFix_SaveLayout'.default.PosterStrings[i]))
			{
				NumberOfBLines += 1;
				currentLineIsBline = true;
			}
			// Need to make sure we don't add multiple b-lines:
			if(`PHOTOBOOTH.m_PosterStrings[i] == "" && (NumberOfBLines <=1 || !currentLineIsBline))
			{
				`PHOTOBOOTH.SetTextBoxString(i, class'UIPoseFix_SaveLayout'.default.PosterStrings[i]);
			}
		}
	}
*/