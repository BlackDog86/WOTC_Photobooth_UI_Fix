class UISL_NMD_Photobooth extends UIScreenListener;

event OnInit(UIScreen Screen)
{
    local XComPresentationLayer Pres;
	local UIPoseFix_NextClickWrapper NextWrapper;
	local UIPoseFix_PreviousClickWrapper PreviousWrapper;
	local UIButton MyNextButton;
	local UIButton MyPreviousButton;
	Pres = `PRES;	

	if (Screen.IsA('NMD_UIDebriefPhotobooth'))
    {
    `log("Nice Mission Debriefing Photobooth found",,'BDLOG');
	class'UIPoseFixHelpers'.default.NMDPhotoboothActive = true;
	class'Engine'.static.GetEngine().GameViewport.bRenderEmptyScene = false;	
	// Replace the modded photobooth with this one, containing pose next/prev
	Pres.GetPhotoboothMovie().RemoveScreen(`PHOTOBOOTH.m_backgroundPoster);
	Pres.ScreenStack.Pop(Screen);
	Pres.UIPhotographerScreen();
    }
	if (Screen.IsA('NMD_UIMissionDebriefingScreen'))
	{
	`log("We're in the NMD Mission debrief - congrats!",,'BDLOG');	
	//reset the soldier index to 0 when we init the screen
	Pres.ScreenStack.SubscribeToOnInputForScreen(Screen, OnSoldierSelectControllerCommand);
	class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex = 0;
	MyNextButton = UIButton(Screen.GetChildByName('NextButton', false));
	MyPreviousButton = UIButton(Screen.GetChildByName('PreviousButton', false));

		If(MyNextButton != none)
		{
		`log("Replacing OnNext Delegate",,'BDLOG');	
		NextWrapper = new class'UIPoseFix_NextClickWrapper';			
		NextWrapper.OnNextClick = MyNextButton.OnClickedDelegate;
		MyNextButton.OnClickedDelegate = NextWrapper.NextButtonPassIndex;
		}

		If(MyPreviousButton != none)
		{
		`log("Replacing OnPrevious Delegate",,'BDLOG');
		PreviousWrapper = new class'UIPoseFix_PreviousClickWrapper';
		PreviousWrapper.OnPreviousClick = MyPreviousButton.OnClickedDelegate;
		MyPreviousButton.OnClickedDelegate = PreviousWrapper.PreviousButtonPassIndex;
		}
	}
}

function GetNextSoldier()
{
	local array<XComGameState_Unit> arrSoldiers, arrValidSoldiers;
	local int i;
	
	XGBattle_SP(`BATTLE).GetHumanPlayer().GetOriginalUnits(arrSoldiers, true, true, true);
		
	for (i = 0; i < arrSoldiers.Length; ++i) // Check that we are not adding more than 6 units as no formation holds more than 6.
	{
		if (class'UIPoseFixHelpers'.static.IsValidNMDPhotoboothSoldier(arrSoldiers[i]))
		{
			arrValidSoldiers.additem(arrSoldiers[i]);
		}
	}	
	
	class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex +=1;
	
	if(class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex > arrValidSoldiers.Length - 1)
	{		
		class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex = 0;
	}
	
	`log("Updating soldier index - new index:" @ class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex,,'BDLOG');
}

function GetPreviousSoldier()
{
	local array<XComGameState_Unit> arrSoldiers, arrValidSoldiers;
	local int i;
	
	XGBattle_SP(`BATTLE).GetHumanPlayer().GetOriginalUnits(arrSoldiers, true, true, true);
		
	for (i = 0; i < arrSoldiers.Length; ++i) // Check that we are not adding more than 6 units as no formation holds more than 6.
	{
		if (class'UIPoseFixHelpers'.static.IsValidNMDPhotoboothSoldier(arrSoldiers[i]))
		{
			arrValidSoldiers.additem(arrSoldiers[i]);
		}
	}	
	
	class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex -=1;
	
	if(class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex < 0)
	{
		class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex = arrValidSoldiers.Length - 1;
	}		
	
	`log("Updating soldier index - new index:" @ class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex,,'BDLOG');
}

simulated protected function bool OnSoldierSelectControllerCommand(UIScreen Screen, int cmd, int arg)
{
	local bool bHandled;
	bHandled = true;

	if (!Screen.CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
	{
		return false;
	}

	switch (cmd)
	{
		case class'UIUtilities_Input'.const.FXS_BUTTON_LBUMPER:
			GetPreviousSoldier();
			Screen.OnUnrealCommand(cmd,arg);
			break;	
		
		case class'UIUtilities_Input'.const.FXS_BUTTON_RBUMPER:
			GetNextSoldier();
			Screen.OnUnrealCommand(cmd,arg);
			break;		
		
		default:
			bHandled = false;
			break;
	}
	return bHandled;
}
