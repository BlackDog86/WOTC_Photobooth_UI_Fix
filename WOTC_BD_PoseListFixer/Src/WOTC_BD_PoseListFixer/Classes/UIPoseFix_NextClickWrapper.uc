class UIPoseFix_NextClickWrapper extends Object;

var delegate <UIButton.OnClickedDelegate> OnNextClick;

function NextButtonPassIndex(UIButton MyNextButton)
{
	local array<XComGameState_Unit> arrSoldiers, arrValidSoldiers;
	local int i;
	
	XGBattle_SP(`BATTLE).GetHumanPlayer().GetOriginalUnits(arrSoldiers, true, true, true);
		
	for (i = 0; i < arrSoldiers.Length; ++i) // Check that we are not adding more than 6 units as no formation holds more than 6.
	{
		if (arrSoldiers[i].UnitIsValidForPhotobooth())
		{
			arrValidSoldiers.additem(arrSoldiers[i]);
		}
	}	
	if(OnNextClick != none)
	{
		OnNextClick(MyNextButton);
	
		class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex +=1;

		if(class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex > arrValidSoldiers.Length - 1)
		{
		`log("Index:" @ class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex,,'BDLOG');
		class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex = 0;
		`log("Updated soldier index - new index:" @ class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex,,'BDLOG');
		}
	}
	`log("OnNextClick is none, bailing",,'BDLOG');
}