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