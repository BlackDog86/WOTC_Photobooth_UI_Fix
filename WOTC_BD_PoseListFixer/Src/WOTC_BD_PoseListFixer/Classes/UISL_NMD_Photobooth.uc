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
	Pres.ScreenStack.Pop(Screen);
	Pres.UIPhotographerScreen();
    }
	if (Screen.IsA('NMD_UIMissionDebriefingScreen'))
	{
	`log("We're in the NMD Mission debrief - congrats!",,'BDLOG');	

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
