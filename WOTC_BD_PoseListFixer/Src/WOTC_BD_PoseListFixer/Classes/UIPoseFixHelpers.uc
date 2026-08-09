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
// Chance that "Randomize Background" also applies a filter or effect
var config float RandomizeBackgroundFilterChancePercent;
var config float RandomizeBackgroundEffectChancePercent;
// Tactical only: chance (percent, one decimal place) that "Randomize
// Background" changes the map Location
var config float RandomizeBackgroundMapLocationChancePercent;
// Number of Layout / Pose / Background slots shown as spinners
var config int NumLayoutSlots;
var config int NumSquadSlots;
var config int NumBackgroundSlots;
// Fixed delay (seconds) after OnInit before applying the saved Layout/Pose presets
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
