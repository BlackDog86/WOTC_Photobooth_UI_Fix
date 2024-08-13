class UISL_NMD_Photobooth extends UIScreenListener;

event OnInit(UIScreen Screen)
{
    local XComPresentationLayer Pres;

	Pres = `PRES;	
	
	if (Screen.IsA('NMD_UIDebriefPhotobooth'))
    {
    `log("Nice Mission Debriefing Photobooth found",,'BDLOG');
	class'UIPoseFixHelpers'.default.NMDPhotoboothActive = true;
	class'UIPoseFixHelpers'.default.CloseAfterPhotoTaken = true;
	class'Engine'.static.GetEngine().GameViewport.bRenderEmptyScene = false;
	Pres.ScreenStack.Pop(Screen);
	Pres.UIPhotographerScreen();
    }
}

