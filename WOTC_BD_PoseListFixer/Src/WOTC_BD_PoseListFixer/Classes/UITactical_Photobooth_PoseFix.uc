class UITactical_Photobooth_PoseFix extends UITactical_Photobooth;

simulated function OnInit()
{
	super.OnInit();
	//`log("Ran PoseFix OnInit - NMDPhotoboothActive Status:" @ class'UIPoseFixHelpers'.default.NMDPhotoboothActive,,'BDLOG');
	If(class'UIPoseFixHelpers'.default.NMDPhotoboothActive == true)
	{
	//Do any stuff here that is specific to Nice Mission Briefings (setting formations, getting soldiers etc.)
	NMD_InitializeFormation();
	class'UIPoseFixHelpers'.default.UIPhotoboothSoldierIndex = 0;
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
	local int i, previousListIndex, soldierIndex;
	local UIButton nextItemsButton, previousItemsButton, soldierToggleButton;
	local array<XComGameState_Unit> arrSoldiers, arrValidSoldiers;

	BATTLE().GetHumanPlayer().GetOriginalUnits(arrSoldiers, true, true, true);
	
	arrValidSoldiers.length = 0;

	for (i = 0; i < arrSoldiers.Length; ++i) // Check that we are not adding more than 6 units as no formation holds more than 6.
	{
		if (arrSoldiers[i].UnitIsValidForPhotobooth())
		{
			arrValidSoldiers.additem(arrSoldiers[i]);
		}
	}

	previousListIndex = -1;	
	
	soldierIndex = class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex + class'UIPoseFixHelpers'.default.UIPhotoboothSoldierIndex;
	if(soldierIndex == -1)
	{
	soldierIndex = 0;
	}
		
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
			if(class'UIPoseFixHelpers'.default.NMDPhotoboothActive == true)
			{
			UIButton(self.GetChildByName('soldierToggle',false)).Remove();
			soldierToggleButton = Spawn(class'UIButton',self);
			soldierToggleButton.InitButton('soldierToggle', class'UIUtilities_Strategy'.default.m_strFast @ class'UIUtilities_Text'.default.m_strGenericToggle $ " : " $ arrValidSoldiers[soldierIndex].GetFullName(),onToggleNextSoldier, eUIButtonStyle_HOTLINK_BUTTON);
			soldierToggleButton.SetGamepadIcon(class'UIUtilities_Input'.const.ICON_Y_TRIANGLE);
			soldierToggleButton.SetResizeToText(false);
			soldierToggleButton.SetTextAlign("center");
			soldierToggleButton.SetPosition(75,700);
			soldierToggleButton.SetWidth(410);			
			}			
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
			previousItemsButton = Spawn(class'UIButton',self).InitButton('previousItems', class'UIMPShell_Leaderboards'.default.m_strPreviousPageText, onSelectPrevious, eUIButtonStyle_HOTLINK_BUTTON);		
			previousItemsButton.SetGamepadIcon(class'UIUtilities_Input'.const.ICON_DPAD_LEFT);
			previousItemsButton.SetPosition(75,864);
			nextItemsButton = Spawn(class'UIButton',self).InitButton('nextItems', class'UIMPShell_Leaderboards'.default.m_strNextPageText, onSelectNext, eUIButtonStyle_HOTLINK_BUTTON);			
			nextItemsButton.SetGamepadIcon(class'UIUtilities_Input'.const.ICON_DPAD_RIGHT);
			nextItemsButton.SetPosition(350,864);		
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
	//`log("Number of Poses:" @ AnimationNames.Length,,'BDLOG');
	//`log("Start index:" @ class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex @ "End Index:" @ class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex @ "Anim Index:" @ AnimationIndex,,'BDLOG');
	
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
	//`log("Building List:",,'BDLOG');
	//`log("Start index:" @ class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex @ "End Index:" @ class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex @ "Anim Index:" @ AnimationIndex,,'BDLOG');
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
	local XComPresentationLayer Pres;

	Pres = `PRES;	

	CurrAnimationIndex = `PHOTOBOOTH.GetAnimations(m_iLastTouchedSoldierIndex, arrAnimations, , DefaultSetupSettings.TextLayoutState == ePBTLS_DeadSoldier);

	if (bWaitingOnPhoto)
		return;

	switch (currentState)
	{
	case eUIPropagandaType_Base:			
			If(`ISCONTROLLERACTIVE && class'UIPoseFixHelpers'.default.NMDPhotoboothActive == false)
			{
			//`log("Should be super closing screen here - Bool status:" @ class'UIPoseFixHelpers'.default.NMDPhotoboothActive,,'BDLOG');
			CloseScreen();
			Pres.UIMissionSummaryScreen();
			}
			else
			{
			CloseScreen();
			}
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

function GenerateDefaultSoldierSetup()
{
	local array<XComGameState_Unit> arrSoldiers, arrValidSoldiers;
	local int soldierIndex, i; 

	BATTLE().GetHumanPlayer().GetOriginalUnits(arrSoldiers, true, true, true);
	
	for (i = 0; i < arrSoldiers.Length; ++i) // Check that we are not adding more than 6 units as no formation holds more than 6.
	{
		if (arrSoldiers[i].UnitIsValidForPhotobooth())
		{
			arrValidSoldiers.additem(arrSoldiers[i]);
		}
	}

	soldierIndex = class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex;

	if(class'UIPoseFixHelpers'.default.NMDPhotoboothActive == true)
	{
		`log("Setting soldier index:" @ class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex @ "Name:" @ arrSoldiers[soldierIndex].GetFullName());
		`PHOTOBOOTH.SetSoldier(0, arrValidSoldiers[soldierIndex].GetReference());
		DefaultSetupSettings.PossibleSoldiers.AddItem(arrValidSoldiers[soldierIndex].GetReference());
		super(UIPhotoboothBase).GenerateDefaultSoldierSetup();
	}
	else
	{
	super.GenerateDefaultSoldierSetup();
	}	
}

simulated function CloseScreen()
{	
	class'Engine'.static.GetEngine().GameViewport.bRenderEmptyScene = false;
	`PRESBASE.GetPhotoboothMovie().RemoveScreen(`PHOTOBOOTH.m_backgroundPoster);
	Movie.Stack.Pop(self);
	Movie.Pres.PlayUISound(eSUISound_MenuClose);
	class'UIPoseFixHelpers'.default.NMDPhotoboothActive = false;	
}

simulated function bool OnUnrealCommand(int ucmd, int arg)
{
	if(`ISCONTROLLERACTIVE && !m_bGamepadCameraActive && !CheckInputIsReleaseOrDirectionRepeat(ucmd, arg))
	return false;	

	switch (ucmd)
	{
	case class'UIUtilities_Input'.const.FXS_DPAD_LEFT:
		if(!m_bGamepadCameraActive)
		{
		OnSelectPrevious();
		}
		return true;
	case class'UIUtilities_Input'.const.FXS_DPAD_RIGHT:		
		if(!m_bGamepadCameraActive)
		{
		OnSelectNext();
		}
		return true;
	case class'UIUtilities_Input'.const.FXS_BUTTON_Y:
		onToggleNextSoldier();
		return true;
	case class'UIUtilities_Input'.const.FXS_BUTTON_B:
		onCancel();
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

function CreatePosterCallback(StateObjectReference UnitRef)
{
	If(class'UIPoseFixHelpers'.default.NMDPhotoboothActive == true)
	{
	bWaitingOnPhoto = false;
	`PRESBASE.GetPhotoboothMovie().RemoveScreen(`PHOTOBOOTH.m_backgroundPoster);
	Movie.Pres.UICloseProgressDialog();
	CloseScreen();
	}
	else
	{
	super.CreatePosterCallback(UnitRef);
	}
}

function onToggleNextSoldier(optional UIButton soldierToggle)
{
	local int a,b,c, i, RandAnim, CurrAnimationIndex;
	local array<XComGameState_Unit> arrSoldiers, arrValidSoldiers;
	local array<AnimationPoses> arrAnimations;

	NMD_InitializeFormation();

	BATTLE().GetHumanPlayer().GetOriginalUnits(arrSoldiers, true, true, true);

	//Clear the array
	arrValidSoldiers.length = 0;

	for (i = 0; i < arrSoldiers.Length; ++i) // Check that we are not adding more than 6 units as no formation holds more than 6.
	{
		if (arrSoldiers[i].UnitIsValidForPhotobooth())
		{
			arrValidSoldiers.additem(arrSoldiers[i]);
		}
	}	
	
	a = class'UIPoseFixHelpers'.default.UIPhotoboothSoldierIndex + 1;
	b = class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex;
	c = a + b;
		
	// If we go off the end, set both to 0
	`log("c:" @ c @ "arrValidSoldiers length:" @ arrValidSoldiers.Length @ "Photobooth config var:" @ class'UIPoseFixHelpers'.default.UIPhotoboothSoldierIndex @ "Debrief Var:" @ class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex,,'BDLOG');
	if(c >= arrValidSoldiers.Length)
	{
	class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex = 0;
	class'UIPoseFixHelpers'.default.UIPhotoboothSoldierIndex = 0;
	c = 0;
	}
	
	//`log("i:"@i,,'BDLOG');
	// Fix text, se
	`PHOTOBOOTH.SetSoldier(0, arrValidSoldiers[c].GetReference());
	`PHOTOBOOTH.SetAutoTextStrings(ePBAT_SOLO, DefaultSetupSettings.TextLayoutState, DefaultSetupSettings);
	if (DefaultSetupSettings.GeneratedText.Length <= 0)
		{
			`PHOTOBOOTH.FillDefaultText(DefaultSetupSettings);
		}	
	//`log("Finished sorting out text",,'BDLOG');
	//CurrAnimationIndex = `PHOTOBOOTH.GetAnimations(m_iLastTouchedSoldierIndex, arrAnimations, , DefaultSetupSettings.TextLayoutState == ePBTLS_DeadSoldier);
	//		`log("currindex:" @ CurrAnimationIndex @  "arrAnims length:" @ arrAnimations.Length);
	//		if (arrAnimations.Length > 0)
	//		{			
	//			RandAnim = `SYNC_RAND(arrAnimations.length);
	//			`log("Array Length:" @ arrAnimations.length @ "RandAnim:" @ RandAnim,,'BDLOG');
	//			`PHOTOBOOTH.SetSoldierAnim(m_iLastTouchedSoldierIndex, arrAnimations[RandAnim].AnimationName, arrAnimations[RandAnim].AnimationOffset);
	//		}
	if(c != 0)
	{
	class'UIPoseFixHelpers'.default.UIPhotoboothSoldierIndex += 1;
	}
	
	NeedsPopulateData();	
}

