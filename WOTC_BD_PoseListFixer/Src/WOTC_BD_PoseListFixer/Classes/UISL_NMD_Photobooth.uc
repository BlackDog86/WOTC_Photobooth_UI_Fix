class UISL_NMD_Photobooth extends UIScreenListener;

var delegate <UIButton.OnClickedDelegate> OnNextClick;
var delegate <UIButton.OnClickedDelegate> OnPreviousClick;

event OnInit(UIScreen Screen)
{
    local XComPresentationLayer Pres;
	local UIButton MyNextButton;
	local UIButton MyPreviousButton;
	local UIButton NMDTakePhotoButton;
	Pres = `PRES;	
	
	if (Screen.IsA('NMD_UIDebriefPhotobooth'))
    {
    `log("Nice Mission Debriefing Photobooth found",,'BDLOG');
	class'UIPoseFixHelpers'.default.NMDPhotoboothActive = true;
	class'Engine'.static.GetEngine().GameViewport.bRenderEmptyScene = false;
	// Replace the modded photobooth with this one, containing pose next/prev
	NMDTakePhotoButton = UIButton(Screen.GetChildByName('NextButton', false));
	Pres.ScreenStack.Pop(Screen);
	Pres.UIPhotographerScreen();
    }
	if (Screen.IsA('NMD_UIMissionDebriefingScreen'))
	{
	`log("We're in the NMD Mission debrief - congrats!",,'BDLOG');
	//Set the index to 0 on init
	class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex = 0;
	`log("Setting soldier index to 0",,'BDLOG');
	MyNextButton = UIButton(Screen.GetChildByName('NextButton', false));
	MyNextButton.StopSounds();
	MyPreviousButton = UIButton(Screen.GetChildByName('PreviousButton', false));
	MyPreviousButton.StopSounds();
	//	If(OnNextClick == none)'''e'e
	//	{
		`log("Replacing OnNext Delegate",,'BDLOG');		
		OnNextClick = MyNextButton.OnClickedDelegate;
		MyNextButton.OnClickedDelegate = NextButtonPassIndex;
	//	}
	//	If(OnPreviousClick == none)
	//	{
		`log("Replacing OnPrevious Delegate",,'BDLOG');
		OnPreviousClick = MyPreviousButton.OnClickedDelegate;
		MyPreviousButton.OnClickedDelegate = PreviousButtonPassIndex;
	//	}
	}
}

function NextButtonPassIndex(UIButton MyNextButton)
{
	local array<XComGameState_Unit> arrSoldiers;

	XGBattle_SP(`BATTLE).GetHumanPlayer().GetOriginalUnits(arrSoldiers, true, true, true);

	OnNextClick(MyNextButton);
	class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex +=1;

	if(class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex > arrSoldiers.Length - 1)
	{
	`log("Index:" @ class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex,,'BDLOG');
	class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex = 0;
	}
	
	`log("Updated soldier index - new index:" @ class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex,,'BDLOG');
}

function PreviousButtonPassIndex(UIButton MyPreviousButton)
{
	local array<XComGameState_Unit> arrSoldiers;

	XGBattle_SP(`BATTLE).GetHumanPlayer().GetOriginalUnits(arrSoldiers, true, true, true);
	
	OnPreviousClick(MyPreviousButton);
	class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex -=1;
	
	if(class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex < 0)
	{
	class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex = arrSoldiers.Length - 1;
	}		
	`log("Updating soldier index - new index:" @ class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex,,'BDLOG');
}