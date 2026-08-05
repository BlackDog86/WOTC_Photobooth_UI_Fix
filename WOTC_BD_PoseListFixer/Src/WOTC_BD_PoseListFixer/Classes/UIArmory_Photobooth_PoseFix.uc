class UIArmory_Photobooth_PoseFix extends UIArmory_Photobooth dependson(UIPoseFix_SaveSquad);

`include(WOTC_BD_PoseListFixer\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

// Overridden so "Hide Poster" only hides the text/layout overlay, not the
// background. The base implementation toggles `PHOTOBOOTH.bShowInGame,
// which (via SetCaptureRenderChannels()) also switches which render
// channel is active: with the poster effect off, the real 3D scene renders
// instead of whatever background texture was set, discarding a custom
// background entirely rather than just hiding text on top of it. Using
// `PHOTOBOOTH.HidePosterTexture()/UpdatePosterTexture() instead (already
// used internally for a related purpose - toggling just the UIRenderTarget)
// removes only the text overlay, leaving bShowInGame/BackgroundTexture (and
// therefore the render channel choice) untouched.
// NOTE: `PHOTOBOOTH.PosterElementsHidden() - which the base game's own
// "Hide Poster" checkbox construction reads directly, bypassing this
// function - still reflects bShowInGame, which this no longer changes, so
// the checkbox's own drawn checked-state may not visually track this
// correctly. Text hiding itself is functionally correct either way. This
// affects every caller of HidePosterElements() uniformly (the checkbox's
// own click handler, and this mod's Layout preset restore).
function HidePosterElements(bool bHide)
{
	if (bHide)
	{
		`PHOTOBOOTH.HidePosterTexture();
	}
	else
	{
		`PHOTOBOOTH.UpdatePosterTexture();
	}
}

// `PHOTOBOOTH.PosterElementsHidden() reads bShowInGame, which
// HidePosterElements() above deliberately no longer touches (that's what
// preserves a custom background) - so it's permanently stale and can't be
// used to tell whether text is actually hidden anymore. This checks the
// same UIRenderTarget field HidePosterElements() itself toggles instead.
// m_kPhotoboothEffect has no privacy modifier, so this is safe to read
// directly from here.
function bool IsPosterTextHidden()
{
	return (`PHOTOBOOTH.m_kPhotoboothEffect != none) && (`PHOTOBOOTH.m_kPhotoboothEffect.UIRenderTarget == none);
}

simulated function OnInit()
{	
	local int			i, NumberNonBlank;
	local string		TestString;

	Super.OnInit();

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

	for(i=0; i<5; i++)
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
			`log("PosterStrings:" @ TestString,,'BDLOG');
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

	// ApplySavedPhotoboothSlots() checks m_kGenRandomState itself and retries
	// every 0.05s if the base game's own random setup isn't done yet -
	// calling it directly (rather than behind a fixed delay first) means we
	// apply as soon as it's actually safe to, instead of always waiting
	// PhotoboothPresetLoadDelay even when the base game finishes sooner.
	ApplySavedPhotoboothSlots();
}

function ApplySavedPhotoboothSlots()
{
	// The fixed startup delay alone isn't reliable - the base game's own
	// random setup (background/text/pose/camera, driven by m_kGenRandomState
	// via UpdateRandom()/Tick()) can still be mid-flight after the delay
	// fires, and overwrite an already-correct restore on a later frame.
	// Retry until it's actually done instead of assuming the delay was
	// long enough.
	if (m_kGenRandomState != eAGCS_Idle)
	{
		`log("PoseFix ApplySavedPhotoboothSlots: base game random setup still in progress (m_kGenRandomState =" @ m_kGenRandomState $ "), retrying shortly",,'BDLOG');
		SetTimer(0.05f, false, nameof(ApplySavedPhotoboothSlots));
		return;
	}

	`log("PoseFix: applying saved Pose/Camera and Layout slots after startup delay",,'BDLOG');
	// Pose/Camera first, since it can change formation; Layout after, so
	// nothing overwrites its styling.
	ApplySquadSlot();
	if (!ApplyLayoutSlot())
	{
		// No Layout slot was applied (empty/Random) - nothing set the poster's
		// visibility, so explicitly reveal it (it was hidden at OnInit purely
		// to mask this delay).
		HidePosterElements(false);
	}
}

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

function PopulateData()
{
	//bsg-jneal (5.16.17): now returning to original menu index when leaving soldier or pose selection
	local int		i, previousListIndex, NumberNonBlank;
	local			UIButton nextItemsButton, previousItemsButton;
	local string	TestString;

	previousListIndex = -1;	
	
	//bsg-jedwards (5.1.17) : Check if the state changed so we can clear the list items and remake them as some may have changed drastically
	if(currentState != lastState)
	{
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

	// Sort out layout
	NumberNonBlank = 0;

	foreach `PHOTOBOOTH.m_PosterStrings(TestString)
	{
		`log("PosterStrings:" @ TestString,,'BDLOG');			
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

	// Build main screen
	i = 0;	

	if (m_bInitialized)
	{
		switch (currentState)
		{
		case eUIPropagandaType_Base:
			class'UIPoseFixHelpers'.default.UIPhotoboothPoseStartIndex = 0;
			class'UIPoseFixHelpers'.default.UIPhotoboothPoseEndIndex = class'UIPoseFixHelpers'.default.UIPhotoboothNumberOfPosesToDisplay;
			class'UIPoseFixHelpers'.default.UIPhotoboothPoseOffset = 0;
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
				previousItemsButton = Spawn(class'UIButton',self).InitButton('previousItems', class'UIMPShell_Leaderboards'.default.m_strPreviousPageText, onSelectPrevious,eUIButtonStyle_HOTLINK_BUTTON);		
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

simulated function CloseScreen()
{
	`PRESBASE.GetPhotoboothMovie().RemoveScreen(`PHOTOBOOTH.m_backgroundPoster);
	super.CloseScreen();
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

function SetupCamera()
{
	Super.SetupCamera();
	m_kCamState.m_fMinCameraDistance = class'UIPoseFixHelpers'.default.StratMinZoomDistance;
	m_kCamState.m_fMaxCameraDistance = class'UIPoseFixHelpers'.default.StratMaxZoomDistance;
	m_fCameraFOV = class'UIPoseFixHelpers'.default.StratFOV;
}

function ZoomIn()
{
	m_kCamState.AddZoom(-class'UIPoseFixHelpers'.default.StratZoomInOutAmount);
}
function ZoomOut()
{
	m_kCamState.AddZoom(class'UIPoseFixHelpers'.default.StratZoomInOutAmount);
}

function TPOV GetCameraPOV()
{
	local TPOV outPOV;

	if(m_kHQCamera != none)
		m_kHQCamera.GetCameraViewPoint(outPOV.Location, outPOV.Rotation);

	outPOV.FOV = class'UIPoseFixHelpers'.default.StratFOV;

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

	`log("Check:" @ CheckForBline,,'BDLOG');

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

// Adds the Save Layout/Squad rows and their slot-selector spinners. Moving a
// spinner immediately loads that slot - there's no separate Load button.
// Filter and Effects (Treatment) moved into Background Options to save 2
// slots here - see the PopulateBackgroundOptionsList override below. That
// means not calling super.PopulateDefaultList() at all, since that's where
// the base class adds them - reproducing the rest of its body here instead
// (Formation/Edit Soldiers/Background Options/Layout/Text/Hide
// Poster/Camera Presets spinner/Randomize), just without Filter, Effects,
// or Reset (never added, so no need for the old Index-- reclaim trick).
// Bonus: since we're constructing the Hide Poster checkbox ourselves now,
// it uses IsPosterTextHidden() (our own correct getter) instead of the
// stale `PHOTOBOOTH.PosterElementsHidden(), fixing its initial displayed
// value in the general case - ApplyHidePosterDelayed's post-load correction
// is still needed for the specific "just loaded a preset" timing gap.
function PopulateDefaultList(out int Index)
{
	GetListItem(Index++).UpdateDataValue(m_CategoryFormations, `PHOTOBOOTH.m_kFormationTemplate.DisplayName, OnClickFormation);
	GetListItem(Index++).UpdateDataDescription(m_CategorySoldiers, OnClickSoldiers);
	GetListItem(Index++).UpdateDataDescription(m_CategoryBackgroundOptions, OnClickBackgroundOptions);
	GetListItem(Index++).UpdateDataValue(m_CategoryLayout, `PHOTOBOOTH.m_currentTextLayoutTemplate.DisplayName, OnClickTextLayout);

	GetListItem(Index++).UpdateDataDescription(m_CategoryGraphics, OnClickGraphics);
	if (bChallengeMode)
	{
		GetListItem(Index - 1).SetDisabled(true);
	}

	GetListItem(Index++).UpdateDataCheckbox(m_CategoryHidePoster, "", IsPosterTextHidden(), OnHidePoster);

	//bsg-jedwards (5.1.17) : Adds Spinner to the options when using a controller
	if(`ISCONTROLLERACTIVE)
	{
		GetListItem(Index++).UpdateDataSpinner(m_CategoryCameraPresets, m_CameraPresets_Labels[ModeSpinnerVal], UpdateMode_OnChanged);
	}
	//bsg-jedwards (5.1.17) : end

	GetListItem(Index++).UpdateDataDescription(m_CategoryRandom, OnRandomize);

	List.OnSelectionChanged = OnDefaultListChange; //bsg-jneal (5.23.17): saving default list index for better nav

	GetListItem(Index++).UpdateDataDescription(m_CategoryRandom @ m_CategoryBackground, OnClickedRandomizeBackground);
	GetListItem(Index++).UpdateDataDescription(m_CategoryRandom @ m_CategoryGraphics, OnClickedRandomizeText);
	GetListItem(Index++).UpdateDataDescription(m_CategoryRandom @ m_CategoryLayout, OnClickedRandomizeLayout);
	GetListItem(Index++).UpdateDataDescription(m_CategoryRandom @ m_PrefixPose, OnClickedRandomizePose);
	GetListItem(Index++).UpdateDataSpinner(m_CategoryLayout @ class'UIOptionsPCScreen'.default.m_strGraphicsLabel_Preset, class'UIPoseFix_SaveLayout'.default.SelectedLayoutSlot == -1 ? m_CategoryRandom : string(class'UIPoseFix_SaveLayout'.default.SelectedLayoutSlot + 1), OnLayoutSlotChanged);
	GetListItem(Index++).UpdateDataDescription(class'UIMPShell_SquadEditor_Preset'.default.m_strReadyButtonText @ m_CategoryLayout @ class'UIOptionsPCScreen'.default.m_strGraphicsLabel_Preset, OnClickedSaveLayout);
	GetListItem(Index++).UpdateDataSpinner(m_PrefixPose @ class'UIOptionsPCScreen'.default.m_strGraphicsLabel_Preset, class'UIPoseFix_SaveSquad'.static.GetSelectedSlot(class'UIPoseFix_SaveSquad'.const.CONTEXT_ARMORY) == -1 ? m_CategoryRandom : string(class'UIPoseFix_SaveSquad'.static.GetSelectedSlot(class'UIPoseFix_SaveSquad'.const.CONTEXT_ARMORY) + 1), OnSquadSlotChanged);
	GetListItem(Index++).UpdateDataDescription(class'UIMPShell_SquadEditor_Preset'.default.m_strReadyButtonText @ m_PrefixPose @ class'UIOptionsPCScreen'.default.m_strGraphicsLabel_Preset, OnClickedSaveSquad);
}

// Filter and Effects (Treatment), relocated here from PopulateDefaultList
// above to save 2 slots in the main list. Identical to the base
// implementation's own code for these two rows (GetFirstPassFilterData/
// GetSecondPassFilterData/OnClickFirstPassFilter/OnClickSecondPassFilter,
// m_CategoryFilter/m_CategoryTreatment), just called from here instead.
function PopulateBackgroundOptionsList(out int Index)
{
	local array<string> FilterNames;
	local int FilterIndex;

	super.PopulateBackgroundOptionsList(Index);

	GetFirstPassFilterData(FilterNames, FilterIndex);
	GetListItem(Index++).UpdateDataValue(m_CategoryFilter, FilterNames[FilterIndex], OnClickFirstPassFilter);

	FilterNames.Length = 0;
	GetSecondPassFilterData(FilterNames, FilterIndex);
	GetListItem(Index++).UpdateDataValue(m_CategoryTreatment, FilterNames[FilterIndex], OnClickSecondPassFilter);
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
	SpinnerControl.SetValue(NewSlot == -1 ? m_CategoryRandom : string(NewSlot + 1));
	ApplyLayoutSlot();
}

function OnSquadSlotChanged(UIListItemSpinner SpinnerControl, int Direction)
{
	local int NewSlot;

	`SOUNDMGR.PlaySoundEvent("Play_MenuSelect");
	NewSlot = class'UIPoseFix_SaveSquad'.static.GetSelectedSlot(class'UIPoseFix_SaveSquad'.const.CONTEXT_ARMORY) + Direction;
	if (NewSlot < -1)
		NewSlot = class'UIPoseFix_SaveSquad'.static.GetNumSlots() - 1;
	else if (NewSlot >= class'UIPoseFix_SaveSquad'.static.GetNumSlots())
		NewSlot = -1;

	class'UIPoseFix_SaveSquad'.static.SetSelectedSlot(class'UIPoseFix_SaveSquad'.const.CONTEXT_ARMORY, NewSlot);
	SpinnerControl.SetValue(NewSlot == -1 ? m_CategoryRandom : string(NewSlot + 1));
	ApplySquadSlot();
}

// DELEGATES

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
	class'UIPoseFix_SaveLayout'.default.HidePoster = IsPosterTextHidden();

	class'UIPoseFix_SaveLayout'.static.SaveCurrentToSlot(class'UIPoseFix_SaveLayout'.default.SelectedLayoutSlot);
	class'UIPoseFix_SaveLayout'.static.SaveLayoutConfigs();
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
	local int i;

	`SOUNDMGR.PlaySoundEvent("Play_MenuSelect");

	Soldiers.Length = 0;
	for (i = 0; i < `PHOTOBOOTH.m_kFormationTemplate.NumSoldiers; i++)
	{
		SoldierData.AnimationName = `PHOTOBOOTH.m_arrUnits[i].AnimationName;
		SoldierData.AnimationOffset = `PHOTOBOOTH.m_arrUnits[i].AnimationOffset;
		Soldiers.AddItem(SoldierData);
	}

	// Requires the XComCamState_HQ_Photobooth Highlander deprivatization PR
	// (removes `private` from m_vTargetRotationPoint/m_rTargetCameraRotation/
	// m_fTargetCameraDistance - already merged, shipping in the next beta).
	// No getter functions needed; the fields are just public now.
	CameraSettings.RotationPoint = m_kCamState.m_vTargetRotationPoint;
	CameraSettings.Rotation = m_kCamState.m_rTargetCameraRotation;
	CameraSettings.ViewDistance = m_kCamState.m_fTargetCameraDistance;

	class'UIPoseFix_SaveSquad'.static.SaveSquadToSlot(class'UIPoseFix_SaveSquad'.const.CONTEXT_ARMORY, class'UIPoseFix_SaveSquad'.static.GetSelectedSlot(class'UIPoseFix_SaveSquad'.const.CONTEXT_ARMORY), string(`PHOTOBOOTH.m_kFormationTemplate.DataName), Soldiers, CameraSettings);
}

function ApplySquadSlot(optional bool bApplyFormation = true)
{
	local array<UIPoseFix_SaveSquad.SavedSquadSoldierData> Soldiers;
	local PhotoboothCameraSettings CameraSettings;
	local array<X2PropagandaPhotoTemplate> arrFormations;
	local string FormationDataName;
	local array<AnimationPoses> arrValidPoses;
	local bool bPoseValid;
	local bool bAnyPoseApplied;
	local int i, j, NumSlotsToApply;

	if (!class'UIPoseFix_SaveSquad'.static.LoadSquadFromSlot(class'UIPoseFix_SaveSquad'.const.CONTEXT_ARMORY, class'UIPoseFix_SaveSquad'.static.GetSelectedSlot(class'UIPoseFix_SaveSquad'.const.CONTEXT_ARMORY), FormationDataName, Soldiers, CameraSettings))
	{
		`log("PoseFix ApplySquadSlot: slot" @ class'UIPoseFix_SaveSquad'.static.GetSelectedSlot(class'UIPoseFix_SaveSquad'.const.CONTEXT_ARMORY) @ "is empty, nothing to apply",,'BDLOG');
		return;
	}

	if (bApplyFormation)
	{
		`PHOTOBOOTH.GetFormations(arrFormations);
		// ChangeFormation() sets m_bFormationNeedsUpdate = true unconditionally,
		// triggering a full pawn respawn regardless of whether the formation
		// TYPE actually differs. Skip it entirely when the current formation
		// already matches the saved one, to avoid an unnecessary respawn/flicker
		// that visually looks like "the formation reset" even though it didn't.
		if (string(`PHOTOBOOTH.m_kFormationTemplate.DataName) != FormationDataName)
		{
			for (i = 0; i < arrFormations.Length; i++)
			{
				if (string(arrFormations[i].DataName) == FormationDataName)
				{
					`PHOTOBOOTH.ChangeFormation(arrFormations[i]);
					break;
				}
			}
		}
	}

	// When bApplyFormation is false, the current formation may not match
	// the one the saved pose data was captured against (different slot
	// count) - only apply pose to slots that actually exist in whatever
	// formation is currently active.
	NumSlotsToApply = Min(Soldiers.Length, `PHOTOBOOTH.m_kFormationTemplate.NumSoldiers);
	`log("PoseFix ApplySquadSlot: applying pose to" @ NumSlotsToApply @ "of" @ Soldiers.Length @ "saved soldier slots (current formation NumSoldiers =" @ `PHOTOBOOTH.m_kFormationTemplate.NumSoldiers $ ")",,'BDLOG');
	for (i = 0; i < NumSlotsToApply; i++)
	{
		// Poses are class/gender restricted (e.g. many are excluded for
		// Templar, and some mods only add poses to specific animsets), so a
		// pose saved against one soldier may not be a valid choice for
		// whoever currently occupies this slot. GetAnimations() already
		// returns exactly the poses valid for the CURRENT occupant of this
		// slot, so check the saved pose against that list rather than
		// assuming it still applies. If it's not valid, leave that one
		// soldier's current pose untouched instead of forcing an invalid
		// pose or substituting a random one.
		arrValidPoses.Length = 0;
		`PHOTOBOOTH.GetAnimations(i, arrValidPoses);
		bPoseValid = false;
		for (j = 0; j < arrValidPoses.Length; j++)
		{
			if (arrValidPoses[j].AnimationName == Soldiers[i].AnimationName)
			{
				bPoseValid = true;
				break;
			}
		}

		if (bPoseValid)
		{
			`PHOTOBOOTH.SetSoldierAnim(i, Soldiers[i].AnimationName, Soldiers[i].AnimationOffset);
			bAnyPoseApplied = true;
		}
		else
		{
			`log("PoseFix ApplySquadSlot: saved pose" @ Soldiers[i].AnimationName @ "not valid for slot" @ i @ "'s current occupant (different class/gender?) - leaving current pose unchanged",,'BDLOG');
		}
	}

	// If none of the saved poses were valid for their current occupants,
	// nothing visibly changed about the pose - moving the camera anyway
	// would look like something broke (framing snaps to the saved shot but
	// the soldiers don't match it). Only adjust the camera when the preset
	// actually did something.
	if (!bAnyPoseApplied)
	{
		`log("PoseFix ApplySquadSlot: no saved poses were valid for current occupants, skipping camera update",,'BDLOG');
		NeedsPopulateData();
		return;
	}

	UpdateCameraToPOV(CameraSettings, true);
	NeedsPopulateData();
}

function bool ApplyLayoutSlot()
{
	if (!class'UIPoseFix_SaveLayout'.static.LoadFromSlot(class'UIPoseFix_SaveLayout'.default.SelectedLayoutSlot))
	{
		`log("PoseFix ApplyLayoutSlot: slot" @ class'UIPoseFix_SaveLayout'.default.SelectedLayoutSlot @ "is empty, nothing to apply",,'BDLOG');
		return false;
	}

	`log("PoseFix ApplyLayoutSlot: slot" @ class'UIPoseFix_SaveLayout'.default.SelectedLayoutSlot @ "loaded, applying styling",,'BDLOG');

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

	// The "Hide Poster" checkbox row just got constructed by the repopulate
	// above, reading `PHOTOBOOTH.PosterElementsHidden() (bShowInGame) - which
	// HidePosterElements() below doesn't touch, so the row displays the
	// wrong state at this point. A second repopulate wouldn't help, since it
	// would just re-read the same stale getter again. Defer the actual
	// state change, then correct the already-existing checkbox widget
	// directly instead.
	SetTimer(0.05f, false, nameof(ApplyHidePosterDelayed));
	return true;
}

function ApplyHidePosterDelayed()
{
	local int i;

	HidePosterElements(class'UIPoseFix_SaveLayout'.default.HidePoster);

	// Same GetListItem(i).Checkbox pattern the base game's own
	// OnToggleRotateSoldier() uses - finds the checkbox widget already
	// sitting in the list (from the repopulate in ApplyLayoutSlot above)
	// and corrects its displayed state directly, without needing another
	// repopulate cycle that would just read the same stale getter again.
	for (i = 0; i < List.ItemCount; i++)
	{
		if (GetListItem(i).Checkbox != none)
		{
			GetListItem(i).Checkbox.SetChecked(class'UIPoseFix_SaveLayout'.default.HidePoster);
			break;
		}
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

	`PHOTOBOOTH.GetAnimations(m_iLastTouchedSoldierIndex, arrAnimations, , class'UIPoseFixHelpers'.default.enableMemorialPoseFiltering && DefaultSetupSettings.TextLayoutState == ePBTLS_DeadSoldier);

	if (bWaitingOnPhoto)
		return;

	switch (currentState)
	{
	case eUIPropagandaType_Base:
		CloseScreen();
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
	case class'UIUtilities_Input'.const.FXS_BUTTON_B:
		onCancel();
		return true;	
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
