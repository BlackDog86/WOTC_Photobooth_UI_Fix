class UIPoseFixHelpers extends object config(Game);

var config int UIPhotoboothNumberOfPosesToDisplay;
var config int UIPhotoboothPoseStartIndex;
var config int UIPhotoboothPoseEndIndex;
var config int UIPhotoboothPoseOffset;
var config bool NMDPhotoboothActive;
var config int UIPhotoboothSoldierIndex;
var config int UIDebriefSoldierIndex;
var config bool EnableMemorialPoseFiltering;
var config float TacZoomInOutAmount;
var config float StratZoomInOutAmount;
var config float TacMinZoomDistance;
var config float TacMaxZoomDistance;
var config float StratMinZoomDistance;
var config float StratMaxZoomDistance;
var config float TacFOV;
var config float StratFOV;

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
