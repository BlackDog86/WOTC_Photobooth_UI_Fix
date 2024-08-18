class UIPoseFix_PreviousClickWrapper extends Object;

var delegate <UIButton.OnClickedDelegate> OnPreviousClick;

function PreviousButtonPassIndex(UIButton MyPreviousButton)
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
	if(OnPreviousClick != none)
	{
		OnPreviousClick(MyPreviousButton);	
	
		class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex -=1;
	
			if(class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex < 0)
			{
			class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex = arrValidSoldiers.Length - 1;
			}		
			`log("Updating soldier index - new index:" @ class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex,,'BDLOG');
	}
	`log("OnPrevious Click none, bailing",,'BDLOG');	
}