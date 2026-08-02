class UITactical_Photobooth_PoseFix extends UITactical_Photobooth dependson(UIPoseFix_SaveSquad);

var bool bSkipSquadSlotRestore;

`include(WOTC_BD_PoseListFixer\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

simulated function OnInit()
{
	local int			i, NumberNonBlank;
	local string		TestString;
	
	super.OnInit();

	// Hide the poster overlay until our saved slots are actually applied,
	// so the transient auto-generated layout never becomes visible - masks
	// the delay below rather than needing it to be imperceptibly short.
	HidePosterElements(true);

	class'UIPoseFix_SaveLayout'.default.lastAline = "";
	class'UIPoseFix_SaveLayout'.default.lastBline = "";
	class'UIPoseFix_SaveLayout'.default.lastOpline = "";
	class'UIPoseFix_SaveLayout'.static.SaveLayoutConfigs();
	class'UIPoseFix_SaveLayout'.static.EnsureSlotsInitialized();
	class'UIPoseFix_SaveSquad'.static.EnsureSlotsInitialized();

	//`log("Ran PoseFix OnInit - NMDPhotoboothActive Status:" @ class'UIPoseFixHelpers'.default.NMDPhotoboothActive,,'BDLOG');
	If(class'UIPoseFixHelpers'.default.NMDPhotoboothActive == true)
	{
		//Do any stuff here that is specific to Nice Mission Briefings (setting formations, getting soldiers etc.)
		NMD_InitializeFormation();
		GenerateDefaultSoldierSetup();	
		class'UIPoseFixHelpers'.default.UIPhotoboothSoldierIndex = 0;
		// Skip auto-loading the saved Pose/Camera slot in Tick() below - NMD
		// briefings set up a specific formation/soldiers for a narrative
		// purpose that a generic saved preset shouldn't override.
		bSkipSquadSlotRestore = true;
	}

	// Initialise layout settings (give up after 10 attempts of trying getting an equal number of elements to what we saved)
	for(i=0; i<10; i++)
	{
		if (`PHOTOBOOTH.m_kFormationTemplate.NumSoldiers == 1)
		{
			`PHOTOBOOTH.SetAutoTextStrings(ePBAT_SOLO);
		}
		else if (`PHOTOBOOTH.m_kFormationTemplate.NumSoldiers == 2)
		{
			`PHOTOBOOTH.SetAutoTextStrings(ePBAT_DUO);
		}
		else
		{
			`PHOTOBOOTH.SetAutoTextStrings(ePBAT_SQUAD);
		}
		NumberNonBlank = 0;
		foreach `PHOTOBOOTH.m_PosterStrings(TestString)
		{
			//`log("PosterStrings:" @ TestString,,'BDLOG');
			if(TestString != "")
			{
				NumberNonBlank += 1;
				if(IsBLine(TestString))
				{
					class'UIPoseFix_SaveLayout'.default.lastBline = TestString;
				}			
			}
		}
		if(NumberNonBlank >= class'UIPoseFix_SaveLayout'.default.NumberOfNonBlankLinesInSavedLayout)
		{		
		class'UIPoseFix_SaveLayout'.static.SaveLayoutConfigs();
		break;
		}
	}

	// The base game's own random setup (background/text/pose/camera) and
	// formation/pawn creation both continue asynchronously after OnInit
	// returns, so applying our saved slots immediately here gets overwritten
	// once that finishes. A short fixed delay before applying is simpler
	// than chasing every async completion signal. The poster is hidden above
	// so this is no longer visible as a flash - the delay just needs to be
	// long enough for that async work to actually finish. Configurable via
	// UIPoseFixHelpers.PhotoboothPresetLoadDelay (XComGame.ini) since machine
	// speed affects how long that takes - raise it if presets still aren't
	// sticking, lower it if the poster reveals with a visible pause.
	SetTimer(class'UIPoseFixHelpers'.default.PhotoboothPresetLoadDelay, false, nameof(ApplySavedPhotoboothSlots));
}

function ApplySavedPhotoboothSlots()
{
	`log("PoseFix: applying saved Pose/Camera and Layout slots after startup delay (bSkipSquadSlotRestore =" @ bSkipSquadSlotRestore $ ")",,'BDLOG');
	// Pose/Camera first, since it can change formation; Layout after, so
	// nothing overwrites its styling. Pose/Camera restore is skipped for
	// NMD briefings - see OnInit.
	if (!bSkipSquadSlotRestore)
	{
		ApplySquadSlot();
	}
	ApplyLayoutSlot();
	HidePosterElements(false);
}

function PopulateData()
{
	//bsg-jneal (5.16.17): now returning to original menu index when leaving soldier or pose selection
	local int							i, previousListIndex, soldierIndex, NumberNonBlank;
	local								UIButton nextItemsButton, previousItemsButton, soldierToggleButton;
	local array<XComGameState_Unit>		arrSoldiers, arrValidSoldiers;
	local string						TestString;

	BATTLE().GetHumanPlayer().GetOriginalUnits(arrSoldiers, true, true, true);
	
	arrValidSoldiers.length = 0;

	for (i = 0; i < arrSoldiers.Length; ++i) // Check that we are not adding more than 6 units as no formation holds more than 6.
	{
		if (class'UIPoseFixHelpers'.static.IsValidNMDPhotoboothSoldier(arrSoldiers[i]))
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

	// Sort out layout save / load stuff
	NumberNonBlank = 0;

	foreach `PHOTOBOOTH.m_PosterStrings(TestString)
	{
		//`log("PosterStrings:" @ TestString,,'BDLOG');			
		if(TestString != "" )
		{
			NumberNonBlank += 1;
		}
	}	

	class'UIPoseFix_SaveLayout'.default.NumberOfNonBlankLinesInCurrentLayout = NumberNonBlank;
	class'UIPoseFix_SaveLayout'.default.hasOpline = false;
	
	for(i=0; i<`PHOTOBOOTH.m_PosterStrings.length; i++)
	{
		TestString = `PHOTOBOOTH.m_PosterStrings[i];

		if(isBLine(TestString))
		{
			class'UIPoseFix_SaveLayout'.default.lastBline = TestString;
		}
		else if(i==0 && `PHOTOBOOTH.m_PosterStrings[i] != "")
		{
			class'UIPoseFix_SaveLayout'.default.lastAline = TestString;
		}
		else if(`PHOTOBOOTH.m_PosterStrings[i] != "")
		{
			class'UIPoseFix_SaveLayout'.default.lastOpline = TestString;
			class'UIPoseFix_SaveLayout'.default.hasOpline = true;
		}
	}

	class'UIPoseFix_SaveLayout'.static.SaveLayoutConfigs();
	
	// Create layout and update strings
	i = 0;	
	if (m_bInitialized)
	{
		switch (currentState)
		{
		case eUIPropagandaType_Base:
			class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex = 0;
			class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex = class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay;
			class'UIPoseFixHelpers'.default.UIPhotoboothPoseOffset = 0;	
			if(class'UIPoseFixHelpers'.default.NMDPhotoboothActive == true && UIButton(self.GetChildByName('soldierToggleButton',false)) == none)
			{
				soldierToggleButton = Spawn(class'UIButton',self);
				soldierToggleButton.InitButton('soldierToggle', class'UIUtilities_Strategy'.default.m_arrStaffTypes[eStaff_Soldier] $ " : " $ arrValidSoldiers[soldierIndex].GetFullName(),, eUIButtonStyle_NONE);
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
	class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex = AnimationNames.Length <= class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay ? 0 : (AnimationNames.Length - (AnimationNames.Length % class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay));
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

function GetAnimationData(int LocationIndex, out array<String> outAnimationNames, out int outAnimationIndex)
{
	local array<AnimationPoses> arrAnimations;
	local int i;

	outAnimationIndex = `PHOTOBOOTH.GetAnimations(LocationIndex, arrAnimations, , class'UIPoseFixHelpers'.default.enableMemorialPoseFiltering && DefaultSetupSettings.TextLayoutState == ePBTLS_DeadSoldier);

	outAnimationNames.Length = 0;
	for (i = 0; i < arrAnimations.Length; ++i)
	{
		outAnimationNames.AddItem(arrAnimations[i].AnimationDisplayName);
	}
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
	//`log("Calling SetFormation - TextLayout:" @ DefaultSetupSettings.TextLayoutState,, 'BDLOG');
	SetFormation(FormationIndex);
	//`log("SetFormation Called - TextLayout:" @ DefaultSetupSettings.TextLayoutState,, 'BDLOG');
}

function GenerateDefaultSoldierSetup()
{
	local array<XComGameState_Unit> arrSoldiers, arrValidSoldiers;
	local int soldierIndex, i; 
	local XComGameState_AdventChosen ChosenState;

	BATTLE().GetHumanPlayer().GetOriginalUnits(arrSoldiers, true, true, true);
	
	for (i = 0; i < arrSoldiers.Length; ++i) // Check that we are not adding more than 6 units as no formation holds more than 6.
	{
		if (class'UIPoseFixHelpers'.static.IsValidNMDPhotoboothSoldier(arrSoldiers[i]))
		{
			arrValidSoldiers.additem(arrSoldiers[i]);
		}
	}

	soldierIndex = class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex;
	
	if(class'UIPoseFixHelpers'.default.NMDPhotoboothActive == true)
	{		
		//`log("Setting soldier index:" @ class'UIPoseFixHelpers'.default.UIDebriefSoldierIndex @ "Name:" @ arrSoldiers[soldierIndex].GetFullName());
		//`log("TextLayout:" @ DefaultSetupSettings.TextLayoutState);
		`PHOTOBOOTH.SetSoldier(0, arrValidSoldiers[soldierIndex].GetReference());		
		//`log("TextLayout AfterSetSoldier:" @ DefaultSetupSettings.TextLayoutState);
		DefaultSetupSettings.PossibleSoldiers.AddItem(arrValidSoldiers[soldierIndex].GetReference());
		//`log("Is soldier dead?:" @ arrValidSoldiers[soldierIndex].IsDead() @ "Index:" @ soldierIndex);
		//If the soldier is dead, use the memorial layout instead of the normal one
		If(arrValidSoldiers[soldierIndex].IsDead())
        {
	        DefaultSetupSettings.TextLayoutState = ePBTLS_DeadSoldier;
       		//`log("TextLayout before SetAutoStrings:" @ DefaultSetupSettings.TextLayoutState); 
			`PHOTOBOOTH.SetAutoTextStrings(ePBAT_SOLO, ePBTLS_DeadSoldier, DefaultSetupSettings);
			 //`log("TextLayout after SetAutoStrings:" @ DefaultSetupSettings.TextLayoutState); 
		}
		If(arrValidSoldiers[soldierIndex].bCaptured)
		{
			// Find out which chosen got us
			ChosenState = XComGameState_AdventChosen(`XCOMHISTORY.GetGameStateForObjectID(arrValidSoldiers[soldierIndex].ChosenCaptorRef.ObjectID));
			DefaultSetupSettings.TextLayoutState = ePBTLS_CapturedSoldier;			
			DefaultSetupSettings.BackgroundDisplayName = GetChosenBackgroundName(ChosenState);
			//`log("Background name:" @ DefaultSetupSettings.BackgroundDisplayName);
			`PHOTOBOOTH.SetBackgroundTexture(GetChosenBackgroundName(ChosenState));
			`PHOTOBOOTH.SetTextLayoutByType(eTLT_Captured);
			`PHOTOBOOTH.SetAutoTextStrings(ePBAT_SOLO, DefaultSetupSettings.TextLayoutState, DefaultSetupSettings);
		}
	//`log("TextLayout before SuperBase:" @ DefaultSetupSettings.TextLayoutState); 
	super(UIPhotoboothBase).GenerateDefaultSoldierSetup();
	//`log("TextLayout after SuperBase:" @ DefaultSetupSettings.TextLayoutState); 
	}
	else
	{
	//`log("TextLayout before Super:" @ DefaultSetupSettings.TextLayoutState); 
	super.GenerateDefaultSoldierSetup();
	//`log("TextLayout after Super:" @ DefaultSetupSettings.TextLayoutState); 
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

function string GetChosenBackgroundName(XComGameState_AdventChosen ChosenState)
{
	local string BackgroundName;
	local array<BackgroundPosterOptions> arrBackgrounds;
	local int i;

	BackgroundName = class'UIPhotoboothBase'.default.m_strEmptyOption;

	if (ChosenState != None)
	{
		`PHOTOBOOTH.GetBackgrounds(arrBackgrounds, ePBT_CHOSEN);

		for (i = 0; i < arrBackgrounds.Length; ++i)
		{
			if (arrBackgrounds[i].BackgroundDisplayName == ChosenState.GetChosenClassName())
			{
				BackgroundName = arrBackgrounds[i].BackgroundDisplayName;
				break;
			}
		}
	}
	return BackgroundName;
}

function int SetRandomAnimationPoseForSoldier(int LocationIndex, optional bool bPreventDuplicates = false, optional out array<AnimationPoses> arrAnimationsAlreadyUsed)
{
	local array<AnimationPoses> arrAnimations, arrOrigAnimations;
	local int AnimationIndex, i, Rolls;
	local XComGameState_Unit Unit;
	local array<Photobooth_AnimationFilterType> ClassFilters; // Issue #309
	local Photobooth_AnimationFilterType ClassFilter;
	local bool bUseClassPose, bPoseNotFound;

	AnimationIndex = 0;
	if (LocationIndex >= 0 && LocationIndex < `PHOTOBOOTH.m_arrUnits.Length && `PHOTOBOOTH.m_arrUnits[locationIndex].UnitRef.ObjectID > 0)
	{
		`PHOTOBOOTH.GetAnimations(LocationIndex, arrOrigAnimations, , class'UIPoseFixHelpers'.default.enableMemorialPoseFiltering && DefaultSetupSettings.TextLayoutState == ePBTLS_DeadSoldier, true);

		Rolls = bPreventDuplicates ? 100 : 1;
		while (--Rolls >= 0)
		{
			arrAnimations = arrOrigAnimations;
			ClassFilter = ePAFT_None;

			Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(`PHOTOBOOTH.m_arrUnits[locationIndex].UnitRef.ObjectID));
			if (Unit != none)
			{
				// Start Issue #309
				ClassFilters = class'X2PhotoboothHelpers'.static.GetClassFiltersForClass(Unit.GetSoldierClassTemplateName());
				ClassFilter = ClassFilters[0];
				// End Issue #309
			}

			if (ClassFilter != ePAFT_None && DefaultSetupSettings.TextLayoutState != ePBTLS_DeadSoldier)
			{
				bUseClassPose = false;
				for (i = 0; i < m_arrClassPoseChances.length; ++i)
				{
					if (m_arrClassPoseChances[i].AnimType == ClassFilter)
					{
						bUseClassPose = `SYNC_RAND(100) < m_arrClassPoseChances[i].Chance;
						break;
					}
				}

				if (bUseClassPose)
				{
					for (i = 0; i < arrAnimations.length; ++i)
					{
						if (arrAnimations[i].AnimType != ClassFilter)
						{
							arrAnimations.Remove(i--, 1);
						}
					}
				}
			}

			AnimationIndex = `SYNC_RAND(arrAnimations.length);

			if (bPreventDuplicates)
			{
				bPoseNotFound = true;
				for (i = 0; i < arrAnimationsAlreadyUsed.Length; ++i)
				{
					if (arrAnimationsAlreadyUsed[i].AnimationName == arrAnimations[AnimationIndex].AnimationName &&
						arrAnimationsAlreadyUsed[i].AnimationOffset == arrAnimations[AnimationIndex].AnimationOffset)
					{
						bPoseNotFound = false;
						break;
					}
				}

				if (bPoseNotFound)
				{
					arrAnimationsAlreadyUsed.AddItem(arrAnimations[AnimationIndex]);
					Rolls = 0;
				}
			}
		}

		`PHOTOBOOTH.SetSoldierAnim(LocationIndex, arrAnimations[AnimationIndex].AnimationName, arrAnimations[AnimationIndex].AnimationOffset);
	}

	return AnimationIndex;
}

function SetupInitialCameraAndCapturePositions()
{
	super.SetupInitialCameraAndCapturePositions();
	m_kStudioCamera.m_fMinCameraDistance = class'UIPoseFixHelpers'.default.TacMinZoomDistance;
	m_kStudioCamera.m_fMaxCameraDistance = class'UIPoseFixHelpers'.default.TacMaxZoomDistance;
	m_kStudioCamera.SetFOV(class'UIPoseFixHelpers'.default.TacFOV);
}

function ZoomIn()
{
	m_kStudioCamera.ZoomCamera(-class'UIPoseFixHelpers'.default.TacZoomInOutAmount);	
}

function ZoomOut()
{
	m_kStudioCamera.ZoomCamera(class'UIPoseFixHelpers'.default.TaczoomInOutAmount);
}

function TPOV GetCameraPOV()
{
	local TPOV outPOV;
	
	outPOV = m_kStudioCamera.GetCameraLocationAndOrientation();
	outPOV.FOV = class'UIPoseFixHelpers'.default.TacFOV;

	return outPOV;
}


function bool isBline(string CheckForBline)
{
	local AutoGeneratedLines		LinesStruct;
	local String					Bline;
	local XComGameState_Unit		SoloUnit;
	local X2SoldierClassTemplate	SoloTemplate;
	
	SoloUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(`PHOTOBOOTH.GetCurrentSoldier(0).ObjectID));
	SoloTemplate = SoloUnit.GetSoldierClassTemplate();

	//`log("Check:" @ CheckForBline,,'BDLOG');

	//Shove all possible B-Lines into local struct
	foreach `PHOTOBOOTH.m_arrSoloBlines(Bline)
		LinesStruct.BLines.AddItem(Bline);
	foreach `PHOTOBOOTH.m_arrSoloBlines_Male(Bline)
		LinesStruct.BLines.AddItem(Bline);
	foreach `PHOTOBOOTH.m_arrSoloBlines_Female(Bline)
		LinesStruct.BLines.AddItem(Bline);
	foreach `PHOTOBOOTH.m_arrSoloMemorialBlines(Bline)
		LinesStruct.BLines.AddItem(Bline);
	foreach `PHOTOBOOTH.m_arrSoloMemorialBlines_Male(Bline)
		LinesStruct.BLines.AddItem(Bline);
	foreach `PHOTOBOOTH.m_arrSoloMemorialBlines_Female(Bline)
		LinesStruct.BLines.AddItem(Bline);
	foreach `PHOTOBOOTH.m_arrDuoBLines(Bline)
		LinesStruct.BLines.AddItem(Bline);
	foreach `PHOTOBOOTH.m_arrDuoBLines_Male(Bline)
		LinesStruct.BLines.AddItem(Bline);
	foreach `PHOTOBOOTH.m_arrDuoBLines_Female(Bline)
		LinesStruct.BLines.AddItem(Bline);
	foreach `PHOTOBOOTH.m_arrSquadBLines(Bline)
		LinesStruct.BLines.AddItem(Bline);	
	foreach SoloTemplate.PhotoboothSoloBLines_Male(Bline)
		LinesStruct.BLines.AddItem(Bline);	
	foreach SoloTemplate.PhotoboothSoloBLines_Female(Bline)
		LinesStruct.BLines.AddItem(Bline);	

	//If the first element in the saved layout is a B-line return true
	if(LinesStruct.Blines.Find(CheckForBline) != INDEX_NONE)
	{
		return true;
	}

	return false;
}

// DELEGATES
function OnSetPose(UIList ContainerList, int ItemIndex)
{
	local array<AnimationPoses> arrAnimations;
	local int CurrAnimationIndex;

	CurrAnimationIndex = `PHOTOBOOTH.GetAnimations(m_iLastTouchedSoldierIndex, arrAnimations, , class'UIPoseFixHelpers'.default.enableMemorialPoseFiltering && DefaultSetupSettings.TextLayoutState == ePBTLS_DeadSoldier);

	if (List.SelectedIndex != CurrAnimationIndex)
	{
		`PHOTOBOOTH.SetSoldierAnim(m_iLastTouchedSoldierIndex, arrAnimations[class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex + List.SelectedIndex].AnimationName, arrAnimations[class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex + List.SelectedIndex].AnimationOffset);
	}
}

function OnSelectNext(optional UIButton nextItemsButton)
{	
	`SOUNDMGR.PlaySoundEvent("Generic_Mouse_Click");
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
	`SOUNDMGR.PlaySoundEvent("Generic_Mouse_Click");
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
	local XComPresentationLayer Pres;
	local UIMissionSummary SummaryScreen;
	Pres = `PRES;

	`PHOTOBOOTH.GetAnimations(m_iLastTouchedSoldierIndex, arrAnimations, , class'UIPoseFixHelpers'.default.enableMemorialPoseFiltering && DefaultSetupSettings.TextLayoutState == ePBTLS_DeadSoldier);

	if (bWaitingOnPhoto)
		return;

	switch (currentState)
	{
	case eUIPropagandaType_Base:			
			If(`ISCONTROLLERACTIVE && class'UIPoseFixHelpers'.default.NMDPhotoboothActive == false)
			{
				//`log("Should be super closing screen here - Bool status:" @ class'UIPoseFixHelpers'.default.NMDPhotoboothActive,,'BDLOG');
				CloseScreen();			
				SummaryScreen = UIMissionSummary(Pres.ScreenStack.GetLastInstanceOf(class'UIMissionSummary'));
				If(SummaryScreen != none)
				{
					SummaryScreen.Show();
				}
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

function PopulateDefaultList(out int Index)
{
	super.PopulateDefaultList(Index);

	// "Reset" is the last row the base class adds (GetListItem(Index++).
	// UpdateDataDescription(m_CategoryReset, OnReset) in UIPhotoboothBase).
	// Reclaim that slot instead of appending after it, so our first row
	// overwrites Reset rather than adding a new one below it.
	Index--;

	GetListItem(Index++).UpdateDataDescription("Randomize Background", OnClickedRandomizeBackground);
	GetListItem(Index++).UpdateDataDescription("Randomize Text", OnClickedRandomizeText);
	GetListItem(Index++).UpdateDataDescription("Randomize Layout", OnClickedRandomizeLayout);
	GetListItem(Index++).UpdateDataDescription("Randomize Pose", OnClickedRandomizePose);
	GetListItem(Index++).UpdateDataSpinner("Layout Preset", class'UIPoseFix_SaveLayout'.default.SelectedLayoutSlot == -1 ? "Random" : string(class'UIPoseFix_SaveLayout'.default.SelectedLayoutSlot + 1), OnLayoutSlotChanged);
	GetListItem(Index++).UpdateDataDescription("Save Layout", OnClickedSaveLayout);
	GetListItem(Index++).UpdateDataSpinner("Pose Camera Preset", class'UIPoseFix_SaveSquad'.static.GetSelectedSlot(false) == -1 ? "Random" : string(class'UIPoseFix_SaveSquad'.static.GetSelectedSlot(false) + 1), OnSquadSlotChanged);
	GetListItem(Index++).UpdateDataDescription("Save Pose / Camera", OnClickedSaveSquad);
}

function OnLayoutSlotChanged(UIListItemSpinner SpinnerControl, int Direction)
{
	local int NewSlot;

	`SOUNDMGR.PlaySoundEvent("Play_MenuSelect");
	NewSlot = class'UIPoseFix_SaveLayout'.default.SelectedLayoutSlot + Direction;
	if (NewSlot < -1)
		NewSlot = class'UIPoseFix_SaveLayout'.static.GetNumSlots() - 1;
	else if (NewSlot >= class'UIPoseFix_SaveLayout'.static.GetNumSlots())
		NewSlot = -1;

	class'UIPoseFix_SaveLayout'.static.SetSelectedSlot(NewSlot);
	SpinnerControl.SetValue(NewSlot == -1 ? "Random" : string(NewSlot + 1));
	ApplyLayoutSlot();
}

function OnSquadSlotChanged(UIListItemSpinner SpinnerControl, int Direction)
{
	local int NewSlot;

	`SOUNDMGR.PlaySoundEvent("Play_MenuSelect");
	NewSlot = class'UIPoseFix_SaveSquad'.static.GetSelectedSlot(false) + Direction;
	if (NewSlot < -1)
		NewSlot = class'UIPoseFix_SaveSquad'.static.GetNumSlots() - 1;
	else if (NewSlot >= class'UIPoseFix_SaveSquad'.static.GetNumSlots())
		NewSlot = -1;

	class'UIPoseFix_SaveSquad'.static.SetSelectedSlot(false, NewSlot);
	SpinnerControl.SetValue(NewSlot == -1 ? "Random" : string(NewSlot + 1));
	ApplySquadSlot();
}

function OnClickedSaveLayout()
{	
	local array<FilterPosterOptions> arrFilters;

	`SOUNDMGR.PlaySoundEvent("Play_MenuSelect");
	class'UIPoseFix_SaveLayout'.static.ClearArrays();
	class'UIPoseFix_SaveLayout'.default.SavedLayoutTemplateIndex = `PHOTOBOOTH.GetLayoutIndex();
	class'UIPoseFix_SaveLayout'.default.PosterFonts = `PHOTOBOOTH.m_PosterFont;
	class'UIPoseFix_SaveLayout'.default.PosterStringColors = `PHOTOBOOTH.m_PosterStringColors;
	class'UIPoseFix_SaveLayout'.default.FirstPassFilterIndex = `PHOTOBOOTH.GetFirstPassFilters(arrFilters);
	class'UIPoseFix_SaveLayout'.default.SecondPassFilterIndex = `PHOTOBOOTH.GetSecondPassFilters(arrFilters);
	class'UIPoseFix_SaveLayout'.default.GradientColor1Index = `PHOTOBOOTH.m_iGradientColor1Index;
	class'UIPoseFix_SaveLayout'.default.GradientColor2Index = `PHOTOBOOTH.m_iGradientColor2Index;

	class'UIPoseFix_SaveLayout'.static.SaveLayoutConfigs();
	class'UIPoseFix_SaveLayout'.static.SaveCurrentToSlot(class'UIPoseFix_SaveLayout'.default.SelectedLayoutSlot);
}

function OnClickedRandomizeBackground()
{
	local array<FilterPosterOptions> arrFilters;

	`SOUNDMGR.PlaySoundEvent("Play_MenuSelect");
	RandomSetBackground();
	// RandomSetBackground() only re-rolls the texture; the tint color indices
	// are separate state that otherwise carries over unchanged, so with the
	// tint checkbox on the background looks the same every time. Re-roll both,
	// matching the same SYNC_RAND(m_FontColors.length) pattern the base game's
	// own initial random setup uses.
	`PHOTOBOOTH.SetGradientColorIndex1(`SYNC_RAND(`PHOTOBOOTH.m_FontColors.length));
	`PHOTOBOOTH.SetGradientColorIndex2(`SYNC_RAND(`PHOTOBOOTH.m_FontColors.length));

	// Weighted chance of a non-None filter/effect, same
	// SYNC_RAND(100) < FilterChance pattern the base game's own initial
	// random setup uses for first-pass filter, extended to one decimal place
	// of precision (SYNC_RAND(1000) against chance*10) so a value like 2.5
	// works. Each click is an independent roll - reset to None on failure
	// rather than leaving whatever filter/effect was already applied.
	if (`SYNC_RAND(1000) < int(class'UIPoseFixHelpers'.default.RandomizeBackgroundFilterChancePercent * 10))
	{
		`PHOTOBOOTH.GetFirstPassFilters(arrFilters);
		`PHOTOBOOTH.SetFirstPassFilter(`SYNC_RAND(arrFilters.Length - 1) + 1);
	}
	else
	{
		`PHOTOBOOTH.SetFirstPassFilter(0);
	}

	if (`SYNC_RAND(1000) < int(class'UIPoseFixHelpers'.default.RandomizeBackgroundEffectChancePercent * 10))
	{
		`PHOTOBOOTH.GetSecondPassFilters(arrFilters);
		`PHOTOBOOTH.SetSecondPassFilter(`SYNC_RAND(arrFilters.Length - 1) + 1);
	}
	else
	{
		`PHOTOBOOTH.SetSecondPassFilter(0);
	}

	NeedsPopulateData();
}

function OnClickedRandomizeText()
{
	local array<string> SavedFonts;
	local array<int> SavedColors;
	local int SavedLayoutIndex;

	`SOUNDMGR.PlaySoundEvent("Play_MenuSelect");

	// SetAutoTextStrings() regenerates font/color/layout as a side effect of
	// generating new text (it calls SetLayoutIndex() internally and rolls new
	// fonts/colors). Snapshot those and restore them afterward so this button
	// only changes the literal text content.
	SavedFonts = `PHOTOBOOTH.m_PosterFont;
	SavedColors = `PHOTOBOOTH.m_PosterStringColors;
	SavedLayoutIndex = `PHOTOBOOTH.GetLayoutIndex();

	// Same formation-size -> auto-text-usage mapping OnInit already uses when
	// first generating text for the current formation.
	if (`PHOTOBOOTH.m_kFormationTemplate.NumSoldiers == 1)
	{
		`PHOTOBOOTH.SetAutoTextStrings(ePBAT_SOLO);
	}
	else if (`PHOTOBOOTH.m_kFormationTemplate.NumSoldiers == 2)
	{
		`PHOTOBOOTH.SetAutoTextStrings(ePBAT_DUO);
	}
	else
	{
		`PHOTOBOOTH.SetAutoTextStrings(ePBAT_SQUAD);
	}

	`PHOTOBOOTH.m_PosterFont = SavedFonts;
	`PHOTOBOOTH.m_PosterStringColors = SavedColors;
	`PHOTOBOOTH.SetLayoutIndex(SavedLayoutIndex);
	NeedsPopulateData();
}

function OnClickedRandomizeLayout()
{
	local array<string> LayoutNames;
	local array<FontOptions> arrFontOptions;
	local int i;

	`SOUNDMGR.PlaySoundEvent("Play_MenuSelect");

	GetLayoutNames(LayoutNames);
	`PHOTOBOOTH.SetLayoutIndex(`SYNC_RAND(LayoutNames.Length));

	// Re-fetch NumTextBoxes after SetLayoutIndex(), since a different layout
	// can have a different box count. Filter/effect are handled by Randomize
	// Background instead, not here.
	`PHOTOBOOTH.GetFonts(arrFontOptions);
	for (i = 0; i < `PHOTOBOOTH.m_currentTextLayoutTemplate.NumTextBoxes; i++)
	{
		`PHOTOBOOTH.SetTextBoxFont(i, arrFontOptions[`SYNC_RAND(arrFontOptions.Length)].FontName);
		`PHOTOBOOTH.SetTextBoxColor(i, `SYNC_RAND(`PHOTOBOOTH.m_FontColors.Length));
	}

	NeedsPopulateData();
}

function OnClickedRandomizePose()
{
	local int i;

	`SOUNDMGR.PlaySoundEvent("Play_MenuSelect");
	for (i = 0; i < `PHOTOBOOTH.m_kFormationTemplate.NumSoldiers; i++)
	{
		SetRandomAnimationPoseForSoldier(i);
	}
	NeedsPopulateData();
}

function OnClickedSaveSquad()
{
	local array<UIPoseFix_SaveSquad.SavedSquadSoldierData> Soldiers;
	local UIPoseFix_SaveSquad.SavedSquadSoldierData SoldierData;
	local PhotoboothCameraSettings CameraSettings;
	local Vector VecX, VecY, VecZ, WorldOffset;
	local int i;

	`SOUNDMGR.PlaySoundEvent("Play_MenuSelect");

	Soldiers.Length = 0;
	for (i = 0; i < `PHOTOBOOTH.m_kFormationTemplate.NumSoldiers; i++)
	{
		SoldierData.AnimationName = `PHOTOBOOTH.m_arrUnits[i].AnimationName;
		SoldierData.AnimationOffset = `PHOTOBOOTH.m_arrUnits[i].AnimationOffset;
		Soldiers.AddItem(SoldierData);
	}

	CameraSettings.Rotation = m_kStudioCamera.GetCameraTargetRotation();
	CameraSettings.ViewDistance = m_kStudioCamera.GetCameraDistance();

	// The camera's RotationPoint is an absolute world-space point tied to
	// whichever map "location" (m_kTacticalLocation) is currently active -
	// meaningless once the location changes, since it then points at empty
	// space where the squad used to stand. Store it as an offset relative to
	// the current formation placement point instead, decomposed along the
	// saved rotation's own axes - the same technique OnChangeStudioLocation()
	// already uses to preserve camera framing across a location change.
	WorldOffset = m_kStudioCamera.GetCameraOffset() - m_kTacticalLocation.GetFormationPlacementActor().Location;
	GetAxes(CameraSettings.Rotation, VecX, VecY, VecZ);
	CameraSettings.RotationPoint.X = WorldOffset Dot VecX;
	CameraSettings.RotationPoint.Y = WorldOffset Dot VecY;
	CameraSettings.RotationPoint.Z = WorldOffset Dot VecZ;

	class'UIPoseFix_SaveSquad'.static.SaveSquadToSlot(false, class'UIPoseFix_SaveSquad'.static.GetSelectedSlot(false), string(`PHOTOBOOTH.m_kFormationTemplate.DataName), Soldiers, CameraSettings);
}

function ApplySquadSlot()
{
	local array<UIPoseFix_SaveSquad.SavedSquadSoldierData> Soldiers;
	local PhotoboothCameraSettings CameraSettings;
	local array<X2PropagandaPhotoTemplate> arrFormations;
	local string FormationDataName;
	local Vector VecX, VecY, VecZ, RelativeOffset;
	local int i;

	if (!class'UIPoseFix_SaveSquad'.static.LoadSquadFromSlot(false, class'UIPoseFix_SaveSquad'.static.GetSelectedSlot(false), FormationDataName, Soldiers, CameraSettings))
	{
		`log("PoseFix ApplySquadSlot: slot" @ class'UIPoseFix_SaveSquad'.static.GetSelectedSlot(false) @ "is empty, nothing to apply",,'BDLOG');
		return;
	}

	`PHOTOBOOTH.GetFormations(arrFormations);
	for (i = 0; i < arrFormations.Length; i++)
	{
		if (string(arrFormations[i].DataName) == FormationDataName)
		{
			`PHOTOBOOTH.ChangeFormation(arrFormations[i]);
			break;
		}
	}

	for (i = 0; i < Soldiers.Length; i++)
	{
		`PHOTOBOOTH.SetSoldierAnim(i, Soldiers[i].AnimationName, Soldiers[i].AnimationOffset);
	}

	// CameraSettings.RotationPoint was saved as an offset relative to the
	// formation placement point (see OnClickedSaveSquad), not an absolute
	// world position - reconstruct the absolute point using wherever the
	// formation is currently placed, so this is correct regardless of which
	// map location is active.
	GetAxes(CameraSettings.Rotation, VecX, VecY, VecZ);
	RelativeOffset = CameraSettings.RotationPoint.X * VecX + CameraSettings.RotationPoint.Y * VecY + CameraSettings.RotationPoint.Z * VecZ;
	CameraSettings.RotationPoint = m_kTacticalLocation.GetFormationPlacementActor().Location + RelativeOffset;

	UpdateCameraToPOV(CameraSettings, true);
	NeedsPopulateData();
}

function ApplyLayoutSlot()
{
	if (!class'UIPoseFix_SaveLayout'.static.LoadFromSlot(class'UIPoseFix_SaveLayout'.default.SelectedLayoutSlot))
		return;

	// Deliberately does not touch `PHOTOBOOTH.m_PosterStrings - the randomized
	// poster text stays as-is. Only styling is restored.
	`PHOTOBOOTH.m_PosterFont = class'UIPoseFix_SaveLayout'.default.PosterFonts;
	`PHOTOBOOTH.m_PosterStringColors = class'UIPoseFix_SaveLayout'.default.PosterStringColors;
	`PHOTOBOOTH.SetFirstPassFilter(class'UIPoseFix_SaveLayout'.default.FirstPassFilterIndex);
	`PHOTOBOOTH.SetSecondPassFilter(class'UIPoseFix_SaveLayout'.default.SecondPassFilterIndex);
	`PHOTOBOOTH.SetGradientColorIndex1(class'UIPoseFix_SaveLayout'.default.GradientColor1Index);
	`PHOTOBOOTH.SetGradientColorIndex2(class'UIPoseFix_SaveLayout'.default.GradientColor2Index);
	`PHOTOBOOTH.SetLayoutIndex(class'UIPoseFix_SaveLayout'.default.SavedLayoutTemplateIndex);
	NeedsPopulateData();
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
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN:
				
		if (IsMouseInPoster() && ((arg & class'UIUtilities_Input'.const.FXS_ACTION_PRESS) > 0 || (arg & class'UIUtilities_Input'.const.FXS_ACTION_HOLD) > 0))
		{
				m_bRightMouseIn = true;
				Movie.Pres.m_kUIMouseCursor.UpdateMouseLocation();
		}
		else if ((arg & class'UIUtilities_Input'.const.FXS_ACTION_RELEASE) > 0)
		{
			if(!m_bRightMouseIn && `GETMCMVAR(RIGHT_CLICK_EXITS_SCREEN))
			{
				OnCancel();
			}
			m_bRightMouseIn = false;
		}
		return true;
		break;
	}
	return super.OnUnrealCommand(ucmd, arg);
}
