class BD_PoseListFixer_MCMScreenListener extends UIScreenListener;

event OnInit(UIScreen Screen)
{
	local BD_PoseListFixer_MCMScreen MCMScreen;

	if (ScreenClass==none)
	{
		if (MCM_API(Screen) != none)
			ScreenClass=Screen.Class;
		else return;
	}

	MCMScreen = new class'BD_PoseListFixer_MCMScreen';
	MCMScreen.OnInit(Screen);
}

defaultproperties
{
    ScreenClass = none;
}
