class UITactical_Photobooth_PoseFix extends UITactical_Photobooth;

simulated function OnInit()
{
	super.OnInit();
	`log("Ran PoseFix OnInit - NMDPhotoboothActive Status:" @ class'UIPoseFixHelpers'.default.NMDPhotoboothActive,,'BDLOG');
	If(class'UIPoseFixHelpers'.default.NMDPhotoboothActive == true)
	{
	//Do any stuff here that is specific to Nice Mission Briefings (setting formations, getting soldiers etc.)
	NMD_InitializeFormation();
	class'UIPoseFixHelpers'.default.UIPhotoboothSoldierIndex = 0;
	class'UIPoseFixHelpers'.default.NMDPhotoboothActive = false;
	}
}

function OnSetPose(UIList ContainerList, int ItemIndex)
{
	local array<AnimationPoses> arrAnimations;
	local int CurrAnimationIndex;

	CurrAnimationIndex = `PHOTOBOOTH.GetAnimations(m_iLastTouchedSoldierIndex, arrAnimations, , DefaultSetupSettings.TextLayoutState == ePBTLS_DeadSoldier);

	if (List.SelectedIndex != CurrAnimationIndex)
	{
		`PHOTOBOOTH.SetSoldierAnim(m_iLastTouchedSoldierIndex, arrAnimations[class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex + List.SelectedIndex].AnimationName, arrAnimations[class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex + List.SelectedIndex].AnimationOffset);
	}
}

function PopulateData()
{
	//bsg-jneal (5.16.17): now returning to original menu index when leaving soldier or pose selection
	local int i, previousListIndex;
	local UIButton nextItemsButton, previousItemsButton, soldierToggleButton;
	local array<XComGameState_Unit> arrSoldiers;

	BATTLE().GetHumanPlayer().GetOriginalUnits(arrSoldiers, true, true, true);

	previousListIndex = -1;		
	
	//bsg-jedwards (5.1.17) : Check if the state changed so we can clear the list items and remake them as some may have changed drastically
	if(currentState != lastState)
	{
		if(currentState != eUIPropagandaType_Base)
		{
		UIButton(self.GetChildByName('soldierToggle',false)).Remove();
		}
		if(currentState == eUIPropagandaType_SoldierData)
		{
			// Remove vbuttons and restore normal title when we back out of the pose screen
			UIButton(self.GetChildByName('previousItems',false)).Remove();
			UIButton(self.GetChildByName('nextItems',false)).Remove();
			setCategory(m_PhotoboothTitle);			
			// only check if we are returning to soldier data list
			if(lastState == eUIPropagandaType_Pose)
			{	
				previousListIndex = (m_iLastTouchedSoldierIndex * 4) + 1; //multiply index by number of list items per soldier (3 + 1 blank), also add 1 if returning from pose
			}
			else if(lastState == eUIPropagandaType_Soldier)
			{
				previousListIndex = (m_iLastTouchedSoldierIndex * 4); //multiply index by number of list items per soldier (3 + 1 blank)
			}
		}
		lastState = currentState;
		List.ClearItems();
	}
	else
	{
		HideListItems();
	}
	//bsg-jedwards (5.1.17) : end
	
	i = 0;	
	if (m_bInitialized)
	{
		switch (currentState)
		{
		case eUIPropagandaType_Base:
			class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex = 0;
			class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex = class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay;
			class'UIPoseFixHelpers'.default.UIPhotoboothPoseOffset = 0;	
			UIButton(self.GetChildByName('soldierToggle',false)).Remove();
			soldierToggleButton = Spawn(class'UIButton',self);
			soldierToggleButton.SetResizeToText(false);
			soldierToggleButton.SetPosition(75,700);
			soldierToggleButton.SetSize(375,75);
			soldierToggleButton.InitButton('soldierToggle',class'UIUtilities_Strategy'.default.m_strFast @ class'UIUtilities_Text'.default.m_strGenericToggle$":"@ arrSoldiers[class'UIPoseFixHelpers'.default.UIPhotoboothSoldierIndex].GetFullName(),onToggleNextSoldier, eUIButtonStyle_HOTLINK_BUTTON);
			PopulateDefaultList(i);
			break;
		case eUIPropagandaType_Formation:
			PopulateFormationList(i);
			break;
		case eUIPropagandaType_SoldierData:
			PopulateSoldierDataList(i);
			break;
		case eUIPropagandaType_Soldier:
			PopulateSoldierList(i);
			break;
		case eUIPropagandaType_Pose:	
			if(UIButton(self.GetChildByName('previousItems',false)) == none)
			{
			previousItemsButton = Spawn(class'UIButton',self);
			previousItemsButton.SetResizeToText(false);
			previousItemsButton.SetWidth(300);
			previousItemsButton.SetGamepadIcon(class'UIUtilities_Input'.const.ICON_DPAD_LEFT);
			previousItemsButton.SetPosition(75,864);
			previousItemsButton.InitButton('previousItems', class'UIMPShell_Leaderboards'.default.m_strPreviousPageText, onSelectPrevious, eUIButtonStyle_HOTLINK_BUTTON);
			nextItemsButton = Spawn(class'UIButton',self);		
			nextItemsButton.SetResizeToText(false);
			nextItemsButton.SetWidth(300);				
			nextItemsButton.SetGamepadIcon(class'UIUtilities_Input'.const.ICON_DPAD_RIGHT);
			nextItemsButton.SetPosition(350,864);
			nextItemsButton.InitButton('nextItems', class'UIMPShell_Leaderboards'.default.m_strNextPageText, onSelectNext, eUIButtonStyle_HOTLINK_BUTTON);				
			}
			PopulatePoseList(i);
			break;
		case eUIPropagandaType_BackgroundOptions:
			PopulateBackgroundOptionsList(i);
			break;
		case eUIPropagandaType_Background:
			PopulateBackgroundList(i);
			break;
		case eUIPropagandaType_Graphics:
			PopulateGraphicsList(i);
			break;
		case eUIPropagandaType_Fonts:
			PopulateFontList(i);
			break;
		case eUIPropagandaType_TextColor:
			PopulateTextColors(i);
			break;
		case eUIPropagandaType_GradientColor1:
			PopulateBackground1Colors(i);
			break;
		case eUIPropagandaType_GradientColor2:
			PopulateBackground2Colors(i);
			break;
		case eUIPropagandaType_TextFont:
			PopulateFontList(i);
			break;
		case eUIPropagandaType_Layout:
			PopulateLayoutList(i);
			break;
		case eUIPropagandaType_Filter:
			PopulateFilterList(i);
			break;
		case eUIPropagandaType_Treatment:
			PopulateTreatmentList(i);
			break;
		};

		//bsg-jedwards (5.1.17) : Repopulate the navigator on the list when the list refreshens
		if(`ISCONTROLLERACTIVE)
		{
			if(previousListIndex != -1)
			{
				List.SetSelectedIndex(previousListIndex);
			}
			else 
			{
				//bsg-jneal (5.23.17): updating certain list indices for poster previews on selection changed, if entering these menus set the initial pose index so the list does not init on the wrong pose
				if(currentState == eUIPropagandaType_Pose || currentState == eUIPropagandaType_Formation || currentState == eUIPropagandaType_Layout || currentState == eUIPropagandaType_Filter || currentState == eUIPropagandaType_Background || currentState == eUIPropagandaType_Treatment)
				{
					List.NavigatorSelectionChanged(m_bOriginalSubListIndex);
				}
				else if(currentState == eUIPropagandaType_Base)
				{
					List.SetSelectedIndex(m_iDefaultListIndex); //bsg-jneal (5.23.17): saving default list index for better nav
				}
				else
				{
					List.OnSelectionChanged = none; //bsg-jneal (5.23.17): clear selection changed callback for sub lists that do not use it
					List.SetSelectedIndex(List.SelectedIndex);
				}
			}
		}
		//bsg-jedwards (5.1.17) : end
	}
	//bsg-jneal (5.16.17): end
}

function PopulatePoseList(out int Index)
{
	local array<string> AnimationNames;
	local int AnimationIndex, i, endIndex;
	local string poseHeader;
	local int numPages;
	local int currentPage;

	GetAnimationData(m_iLastTouchedSoldierIndex, AnimationNames, AnimationIndex);
	`log("Number of Poses:" @ AnimationNames.Length,,'BDLOG');
	`log("Start index:" @ class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex @ "End Index:" @ class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex @ "Anim Index:" @ AnimationIndex,,'BDLOG');
	
	// If we try to start at a number greater than the number of poses, go back to the first page:
	if (class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex > AnimationNames.Length)
	{
	class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex = 0;
	class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex = class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay;
	}		
	// We're going onto the last page so don't display loads of empty records
	if (class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex <= 0 || class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex >= AnimationNames.Length)
	{
	class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex = AnimationNames.Length < class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay ? 0 : (AnimationNames.Length - (AnimationNames.Length % class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay));
	class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex = AnimationNames.Length;
	}	
	else
	{
	//use default list size
	class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex = class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex + class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay;
	}

		//cover for situations where we have less poses than the 'number of elements to display'
		if (AnimationNames.Length < class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay)
		{
		endIndex = AnimationNames.Length;
		}
		else
		{
		endIndex = class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex;
		}
	`log("Building List:",,'BDLOG');
	`log("Start index:" @ class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex @ "End Index:" @ class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex @ "Anim Index:" @ AnimationIndex,,'BDLOG');
	for (i = class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex; i < endIndex; i++)
	{
		GetListItem(Index++).UpdateDataDescription(AnimationNames[i], OnConfirmPose); //bsg-jneal (5.16.17): now changing pose on selection change
	}

	numPages = FCeil(float(AnimationNames.Length) / float(class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay));
	currentPage = (class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex / class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay) +1;
	poseHeader = (m_PhotoboothTitle @ "[" $ currentPage $ "/" $ numPages $ "]");
	SetCategory(poseHeader);
	
	//bsg-jneal (5.16.17): now changing pose on selection change so need to remember initial pose when cancelling menu
	m_bOriginalSubListIndex = AnimationIndex;
	List.OnSelectionChanged = OnSetPose;
	//bsg-jneal (5.16.17): end
}


function OnSelectNext(optional UIButton nextItemsButton)
{	
	if(currentState == eUIPropagandaType_Pose)
	{
	class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex += class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay;
	class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex += class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay;
	List.OnSelectionChanged = none;
	currentState = eUIPropagandaType_Pose;
	NeedsPopulateData();
	}
}

function OnSelectPrevious(optional UIButton previousItemsButton)
{		
	if(currentState == eUIPropagandaType_Pose)
	{
	class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex -= class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay;
	class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex -= class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay;
	List.OnSelectionChanged = none;
	currentState = eUIPropagandaType_Pose;
	NeedsPopulateData();
	}
}

function OnDefaultListChange(UIList ContainerList, int ItemIndex)
{
	class'UIPoseFixHelpers'.default.UIPhotoboothPoseOffset = class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex;
	m_iDefaultListIndex = List.SelectedIndex;
}

function OnConfirmPose()
{
	List.OnSelectionChanged = none;
	currentState = eUIPropagandaType_SoldierData;
	List.ClearItems();
	NeedsPopulateData();
}

function OnCancel()
{

	local array<AnimationPoses> arrAnimations;
	local int CurrAnimationIndex;

	CurrAnimationIndex = `PHOTOBOOTH.GetAnimations(m_iLastTouchedSoldierIndex, arrAnimations, , DefaultSetupSettings.TextLayoutState == ePBTLS_DeadSoldier);

	if (bWaitingOnPhoto)
		return;

	switch (currentState)
	{
	case eUIPropagandaType_Base:
		//bsg-hlee (05.12.17): If a picture has not been taken then show the popup.
		if(!bHasTakenPicture)
			DestructiveActionPopup();
		else //Skip the popup and just go to the cleanup and close of the screen.
			OnDestructiveActionPopupExitDialog('eUIAction_Accept');
		//bsg-hlee (05.12.17): End
		break;
	
	case eUIPropagandaType_Soldier:
		m_bRotatingPawn = false;
	case eUIPropagandaType_Pose:
		//bsg-jneal (5.16.17): now changing pose on selection change so need to remember initial pose when cancelling menu
		//List.SetSelectedIndex(m_bOriginalSubListIndex);
		`PHOTOBOOTH.SetSoldierAnim(m_iLastTouchedSoldierIndex, arrAnimations[class'UIPoseFixHelpers'.default.UIPhotoboothPoseOffset + m_bOriginalSubListIndex].AnimationName, arrAnimations[class'UIPoseFixHelpers'.default.UIPhotoboothPoseOffset + m_bOriginalSubListIndex].AnimationOffset);
		//List.SetSelectedIndex(m_bOriginalSubListIndex);
		List.OnSelectionChanged = none;		
		//bsg-jneal (5.16.17): end

		currentState = eUIPropagandaType_SoldierData;
		break;

	//bsg-jedwards (5.1.17) : Hide color selector if backing out
	//case eUIPropagandaType_GradientColor1:
	//case eUIPropagandaType_GradientColor2:
	//	ColorSelector.Hide();
	//	currentState = eUIPropagandaType_Base;
	//	break;
	//bsg-jedwards (5.1.17) : end
	//bsg-jneal (5.23.17): updating certain list indices for poster previews on selection changed
	case eUIPropagandaType_Formation:
	case eUIPropagandaType_Layout:
	case eUIPropagandaType_Filter:
	case eUIPropagandaType_Treatment:
		List.SetSelectedIndex(m_bOriginalSubListIndex);
		List.OnSelectionChanged = none;
	case eUIPropagandaType_SoldierData:
	case eUIPropagandaType_BackgroundOptions:
	case eUIPropagandaType_Graphics:
		currentState = eUIPropagandaType_Base;
		break;
	
	case eUIPropagandaType_GradientColor1:
	case eUIPropagandaType_GradientColor2:
		ColorSelector.Hide();
		SetTextColor(m_iPreviousColor);
		currentState = eUIPropagandaType_BackgroundOptions;
		break;
	case eUIPropagandaType_Background:
		List.SetSelectedIndex(m_bOriginalSubListIndex);
		List.OnSelectionChanged = none;
		currentState = eUIPropagandaType_BackgroundOptions;
		break;
	case eUIPropagandaType_TextColor:
		ColorSelector.Hide();
		SetTextColor(m_iPreviousColor);
		currentState = eUIPropagandaType_Graphics;
		break;
	//bsg-jneal (5.23.17): end
	case eUIPropagandaType_TextFont:
	case eUIPropagandaType_Fonts:
		currentState = eUIPropagandaType_Graphics;
		break;
	}
	List.ClearItems();
	NeedsPopulateData();
}

function NMD_InitializeFormation()
{
	local array<X2PropagandaPhotoTemplate> arrFormations;
	local int i, FormationIndex;

	FormationIndex = INDEX_NONE;
	`PHOTOBOOTH.GetFormations(arrFormations);
	for (i = 0; i < arrFormations.Length; ++i)
	{
		if (arrFormations[i].DataName == name("Solo"))
		{
			FormationIndex = i;
			break;
		}
	}

	FormationIndex = FormationIndex != INDEX_NONE ? FormationIndex : `SYNC_RAND(arrFormations.Length);

	if (DefaultSetupSettings.FormationTemplate == none)
	{
		DefaultSetupSettings.FormationTemplate = arrFormations[FormationIndex];
	}

	SetFormation(FormationIndex);
}

function CreatePosterCallback(StateObjectReference UnitRef)
{
	If(class'UIPoseFixHelpers'.default.CloseAfterPhotoTaken == true)
		{
		`log("Closing after photo & setting var false");
		bWaitingOnPhoto = false;
		CloseScreen();
		class'UIPoseFixHelpers'.default.CloseAfterPhotoTaken = false;
		}
	Else
		{
		`log("Calling parent callback");
		super.CreatePosterCallback(UnitRef);
		}
}

simulated function CloseScreen()
{
	`PRESBASE.GetPhotoboothMovie().RemoveScreen(`PHOTOBOOTH.m_backgroundPoster);
	Movie.Pres.UICloseProgressDialog();class'Engine'.static.GetEngine().GameViewport.bRenderEmptyScene = false;
	Movie.Stack.Pop(self);
	Movie.Pres.PlayUISound(eSUISound_MenuClose);
	class'UIPoseFixHelpers'.default.CloseAfterPhotoTaken = false;
}

simulated function bool OnUnrealCommand(int ucmd, int arg)
{
	switch (ucmd)
	{
	case class'UIUtilities_Input'.const.FXS_DPAD_LEFT:
		OnSelectPrevious();
		return true;
	case class'UIUtilities_Input'.const.FXS_DPAD_RIGHT:		
		OnSelectNext();
		return true;
	case class'UIUtilities_Input'.const.FXS_KEY_F:
		if (IsMouseInPoster())
		{
			ZoomIn();
		}
		break;
	case class'UIUtilities_Input'.const.FXS_KEY_C:
		if (IsMouseInPoster())
		{
			ZoomOut();
		}
		break;
	}
	return super.OnUnrealCommand(ucmd, arg);
}

function onToggleNextSoldier(optional UIButton soldierToggle)
{
	local int i;
	local array<XComGameState_Unit> arrSoldiers;

	NMD_InitializeFormation();

	BATTLE().GetHumanPlayer().GetOriginalUnits(arrSoldiers, true, true, true);
	for(i=0; i < arrSoldiers.Length; ++i)
	{
	`log("Array index:" @ i @ "Soldier:" @ arrSoldiers[i].GetFullName @ "Array size:" @ arrSoldiers.Length,,'BDLOG');
	}
		
	class'UIPoseFixHelpers'.default.UIPhotoboothSoldierIndex += 1;

	if(class'UIPoseFixHelpers'.default.UIPhotoboothSoldierIndex > arrSoldiers.Length-1)
	{
	class'UIPoseFixHelpers'.default.UIPhotoboothSoldierIndex = 0;
	}

	i = class'UIPoseFixHelpers'.default.UIPhotoboothSoldierIndex;
	`log("i:"@i,,'BDLOG');
	`PHOTOBOOTH.SetSoldier(0, arrSoldiers[i].GetReference());	
	NeedsPopulateData();
}