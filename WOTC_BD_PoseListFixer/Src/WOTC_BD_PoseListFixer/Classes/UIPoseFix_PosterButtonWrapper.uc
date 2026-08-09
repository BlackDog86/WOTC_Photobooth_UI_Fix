class UIPoseFix_PosterButtonWrapper extends Object;

var UIMissionSummary MissionSummary;

// NMD_UIMissionSummaryListener.OnMakePosterButton raises its own confirm
// dialog ("you won't be able to go back to mission summary") before this
// button's click reaches CloseThenOpenPhotographerScreen - stale advice
// now that exiting the photobooth returns to NMD's own debrief screen
// instead of dead-ending. Nothing in that function is reachable from here
// to disable just the dialog, so this replaces the click entirely and
// goes straight to what accepting the dialog would have done -
// EnableMissionSummaryOnLoseFocus(false) then CloseThenOpenPhotographerScreen(),
// using only base-game UIMissionSummary/UIScreen members, no NMD-specific
// types needed.
function OnPosterButtonClicked(UIButton Button)
{
	if (`ISCONTROLLERACTIVE)
	{
		MissionSummary.bHideOnLoseFocus = true;
		MissionSummary.bProcessMouseEventsIfNotFocused = false;
		MissionSummary.Hide();
	}

	MissionSummary.CloseThenOpenPhotographerScreen();
}
