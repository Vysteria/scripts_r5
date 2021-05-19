global function InitLobbyMenu

struct
{
	var  menu
	bool updatingLobbyUI = false
	bool inputsRegistered = false
	bool tabsInitialized = false
	bool newnessInitialized = false

	var postGameButton
	var newsButton
	var socialButton
	var gameMenuButton
} file

void function InitLobbyMenu()
{
	var menu = GetMenu( "LobbyMenu" )
	file.menu = menu

	RegisterSignal( "LobbyMenuUpdate" )

	RuiSetImage( Hud_GetRui( Hud_GetChild( file.menu, "Logo" ) ), "basicImage", $"rui/menu/lobby/logo" )

	AddMenuEventHandler( menu, eUIEvent.MENU_OPEN, OnLobbyMenu_Open )
	AddMenuEventHandler( menu, eUIEvent.MENU_CLOSE, OnLobbyMenu_Close )

	AddMenuEventHandler( menu, eUIEvent.MENU_SHOW, OnLobbyMenu_Show )
	AddMenuEventHandler( menu, eUIEvent.MENU_HIDE, OnLobbyMenu_Hide )

	AddMenuEventHandler( menu, eUIEvent.MENU_NAVIGATE_BACK, OnLobbyMenu_NavigateBack )

	AddMenuVarChangeHandler( "isFullyConnected", UpdateFooterOptions )
	AddMenuVarChangeHandler( "isPartyLeader", UpdateFooterOptions )
	#if DURANGO_PROG
		AddMenuVarChangeHandler( "DURANGO_canInviteFriends", UpdateFooterOptions )
		AddMenuVarChangeHandler( "DURANGO_isJoinable", UpdateFooterOptions )
	#elseif PS4_PROG
		AddMenuVarChangeHandler( "PS4_canInviteFriends", UpdateFooterOptions )
	#elseif PC_PROG
		AddMenuVarChangeHandler( "ORIGIN_isEnabled", UpdateFooterOptions )
		AddMenuVarChangeHandler( "ORIGIN_isJoinable", UpdateFooterOptions )
	#endif

	var postGameButton = Hud_GetChild( menu, "PostGameButton" )
	file.postGameButton = postGameButton
	ToolTipData postGameToolTip
	postGameToolTip.descText = "#MATCH_SUMMARY"
	Hud_SetToolTipData( postGameButton, postGameToolTip )
	HudElem_SetRuiArg( postGameButton, "icon", $"rui/menu/lobby/postgame_icon" )
	HudElem_SetRuiArg( postGameButton, "shortcutText", "%[BACK|TAB]%" )
	Hud_AddEventHandler( postGameButton, UIE_CLICK, PostGameButton_OnActivate )

	var newsButton = Hud_GetChild( menu, "NewsButton" )
	file.newsButton = newsButton
	ToolTipData newsToolTip
	newsToolTip.descText = "#NEWS"
	Hud_SetToolTipData( newsButton, newsToolTip )
	HudElem_SetRuiArg( newsButton, "icon", $"rui/menu/lobby/news_icon" )
	HudElem_SetRuiArg( newsButton, "shortcutText", "%[R_TRIGGER|ESCAPE]%" )
	Hud_AddEventHandler( newsButton, UIE_CLICK, NewsButton_OnActivate )

	var socialButton = Hud_GetChild( menu, "SocialButton" )
	file.socialButton = socialButton
	ToolTipData socialToolTip
	socialToolTip.descText = "#MENU_TITLE_FRIENDS"
	Hud_SetToolTipData( socialButton, socialToolTip )
	HudElem_SetRuiArg( socialButton, "icon", $"rui/menu/lobby/friends_icon" )
	HudElem_SetRuiArg( socialButton, "shortcutText", "%[STICK2|]%" )
	Hud_AddEventHandler( socialButton, UIE_CLICK, SocialButton_OnActivate )

	var gameMenuButton = Hud_GetChild( menu, "GameMenuButton" )
	file.gameMenuButton = gameMenuButton
	ToolTipData gameMenuToolTip
	gameMenuToolTip.descText = "#GAME_MENU"
	Hud_SetToolTipData( gameMenuButton, gameMenuToolTip )
	HudElem_SetRuiArg( gameMenuButton, "icon", $"rui/menu/lobby/settings_icon" )
	HudElem_SetRuiArg( gameMenuButton, "shortcutText", "%[START|ESCAPE]%" )
	Hud_AddEventHandler( gameMenuButton, UIE_CLICK, GameMenuButton_OnActivate )
}


void function OnLobbyMenu_Open()
{
	//ClientCommand( "gameCursor_ModeActive 1" )

	if ( !file.tabsInitialized )
	{
		array<var> panels = GetAllMenuPanels( file.menu )
		foreach ( panel in panels )
			AddTab( file.menu, panel, GetPanelTabTitle( panel ) )

		file.tabsInitialized = true
	}

	if ( uiGlobal.lastMenuNavDirection == MENU_NAV_FORWARD )
	{
		TabData tabData = GetTabDataForPanel( file.menu )
		ActivateTab( tabData, 0 )
	}
	else
	{
		TabData tabData = GetTabDataForPanel( file.menu )
		ActivateTab( tabData, tabData.tabIndex )
	}

	UpdateNewnessCallbacks()

	thread UpdateLobbyUI()

	Lobby_UpdatePlayPanelPlaylists()

	AddCallbackAndCallNow_OnGRXOffersRefreshed( OnGRXStateChanged )
	AddCallbackAndCallNow_OnGRXInventoryStateChanged( OnGRXStateChanged )
}


void function OnLobbyMenu_Show()
{
	thread LobbyMenuUpdate()
	RegisterInputs()

	Chroma_Lobby()
}


void function OnLobbyMenu_Hide()
{
	Signal( uiGlobal.signalDummy, "LobbyMenuUpdate" )
	DeregisterInputs()
}


void function OnLobbyMenu_Close()
{
	ClearNewnessCallbacks()
	DeregisterInputs()

	RemoveCallback_OnGRXOffersRefreshed( OnGRXStateChanged )
	RemoveCallback_OnGRXInventoryStateChanged( OnGRXStateChanged )
}


void function OnGRXStateChanged()
{
	bool ready = GRX_IsInventoryReady() && GRX_AreOffersReady()

	array<var> panels = [
		GetPanel( "CharactersPanel" ),
		GetPanel( "ArmoryPanel" ),
		//GetPanel( "PassPanel" ),
		GetPanel( "StorePanel" ),
		GetPanel( "LootPanel" ),
		GetPanel( "ECPanel" ),
		GetPanel( "CharacterPanel" ),
		GetPanel( "VCPanel" ),
	]

	foreach ( var panel in panels )
	{
		if ( !Hud_IsVisible( panel ) )
		{
			if ( panel == GetPanel( "PassPanel" ) )
				SetPanelTabEnabled( panel, ready && IsBattlePassEnabled() && (GetPlayerActiveBattlePass( ToEHI( GetUIPlayer() ) ) != null) )
			else
				SetPanelTabEnabled( panel, ready )
		}
	}

	if ( ready )
	{
		if ( ShouldShowPremiumCurrencyDialog() )
			ShowPremiumCurrencyDialog( false )
	}
}


void function UpdateNewnessCallbacks()
{
	ClearNewnessCallbacks()

	Newness_AddCallbackAndCallNow_OnRerverseQueryUpdated( NEWNESS_QUERIES.GladiatorTab, OnNewnessQueryChangedUpdatePanelTab, GetPanel( "CharactersPanel" ) )
	Newness_AddCallbackAndCallNow_OnRerverseQueryUpdated( NEWNESS_QUERIES.ArmoryTab, OnNewnessQueryChangedUpdatePanelTab, GetPanel( "ArmoryPanel" ) )
	file.newnessInitialized = true
}


void function ClearNewnessCallbacks()
{
	if ( !file.newnessInitialized )
		return

	Newness_RemoveCallback_OnRerverseQueryUpdated( NEWNESS_QUERIES.GladiatorTab, OnNewnessQueryChangedUpdatePanelTab, GetPanel( "CharactersPanel" ) )
	Newness_RemoveCallback_OnRerverseQueryUpdated( NEWNESS_QUERIES.ArmoryTab, OnNewnessQueryChangedUpdatePanelTab, GetPanel( "ArmoryPanel" ) )
	file.newnessInitialized = false
}


void function UpdateLobbyUI()
{
	if ( file.updatingLobbyUI )
		return

	file.updatingLobbyUI = true

	thread UpdateMatchmakingStatus()

	WaitSignal( uiGlobal.signalDummy, "CleanupInGameMenus" )
	file.updatingLobbyUI = false
}


void function LobbyMenuUpdate()
{
	Signal( uiGlobal.signalDummy, "LobbyMenuUpdate" )
	EndSignal( uiGlobal.signalDummy, "LobbyMenuUpdate" )
	EndSignal( uiGlobal.signalDummy, "CleanupInGameMenus" )

	while ( true )
	{
		PlayPanelUpdate()
		UpdateCornerButtons()
		UpdateTabs()
		WaitFrame()
	}
}


void function UpdateCornerButtons()
{
	bool isPlayPanelActive = IsTabPanelActive( GetPanel( "PlayPanel" ) )
	var postGameButton = Hud_GetChild( file.menu, "PostGameButton" )
	Hud_SetVisible( postGameButton, isPlayPanelActive && IsPostGameMenuValid() )

	var newsButton = Hud_GetChild( file.menu, "NewsButton" )
	Hud_SetVisible( newsButton, isPlayPanelActive )

	var socialButton = Hud_GetChild( file.menu, "SocialButton" )
	Hud_SetVisible( socialButton, isPlayPanelActive )

	var accessibilityHint = Hud_GetChild( file.menu, "AccessibilityHint" )
	Hud_SetVisible( accessibilityHint, isPlayPanelActive && IsAccessibilityChatHintEnabled() )

	Hud_SetEnabled( file.gameMenuButton, !IsDialog( GetActiveMenu() ) )

	int count = GetOnlineFriendCount( false )
	if ( count > 0 )
	{
		HudElem_SetRuiArg( socialButton, "buttonText", "" + count )
		Hud_SetWidth( socialButton, Hud_GetBaseWidth( socialButton ) * 2 )
		InitButtonRCP( socialButton )
	}
	else
	{
		HudElem_SetRuiArg( socialButton, "buttonText", "" )
		Hud_ReturnToBaseSize( socialButton )
		InitButtonRCP( socialButton )
	}
}

void function UpdateTabs()
{
	if ( IsFullyConnected() )
	{
	} // todo(dw)
}


void function RegisterInputs()
{
	if ( file.inputsRegistered )
		return

	RegisterButtonPressedCallback( BUTTON_START, GameMenuButton_OnActivate )
	RegisterButtonPressedCallback( BUTTON_BACK, PostGameButton_OnActivate )
	RegisterButtonPressedCallback( KEY_TAB, PostGameButton_OnActivate )
	RegisterButtonPressedCallback( KEY_ENTER, OnLobbyMenu_FocusChat )
	RegisterButtonPressedCallback( BUTTON_TRIGGER_RIGHT, NewsButton_OnActivate )
	RegisterButtonPressedCallback( BUTTON_STICK_RIGHT, SocialButton_OnActivate )
	file.inputsRegistered = true
}


void function DeregisterInputs()
{
	if ( !file.inputsRegistered )
		return

	DeregisterButtonPressedCallback( BUTTON_START, GameMenuButton_OnActivate )
	DeregisterButtonPressedCallback( BUTTON_BACK, PostGameButton_OnActivate )
	DeregisterButtonPressedCallback( KEY_TAB, PostGameButton_OnActivate )
	DeregisterButtonPressedCallback( KEY_ENTER, OnLobbyMenu_FocusChat )
	DeregisterButtonPressedCallback( BUTTON_TRIGGER_RIGHT, NewsButton_OnActivate )
	DeregisterButtonPressedCallback( BUTTON_STICK_RIGHT, SocialButton_OnActivate )
	file.inputsRegistered = false
}


void function NewsButton_OnActivate( var button )
{
	if ( !IsPromoDialogAllowed() )
		return

	if ( !IsTabPanelActive( GetPanel( "PlayPanel" ) ) )
		return

	AdvanceMenu( GetMenu( "PromoDialog" ) )
}


void function SocialButton_OnActivate( var button )
{
	if ( IsDialog( GetActiveMenu() ) )
		return

	if ( !IsTabPanelActive( GetPanel( "PlayPanel" ) ) )
		return

	#if PC_PROG
		if ( !MeetsAgeRequirements() )
		{
			ConfirmDialogData dialogData
			dialogData.headerText = "#UNAVAILABLE"
			dialogData.messageText = "#ORIGIN_UNDERAGE_ONLINE"
			dialogData.contextImage = $"ui/menu/common/dialog_notice"

			OpenOKDialogFromData( dialogData )
			return
		}
	#endif

	AdvanceMenu( GetMenu( "SocialMenu" ) )
}


void function GameMenuButton_OnActivate( var button )
{
	if ( InputIsButtonDown( BUTTON_STICK_LEFT ) ) // Avoid bug report shortcut
		return

	if ( IsDialog( GetActiveMenu() ) )
		return

	AdvanceMenu( GetMenu( "SystemMenu" ) )
}


void function PostGameButton_OnActivate( var button )
{
	if ( IsDialog( GetActiveMenu() ) )
		return

	if ( !IsTabPanelActive( GetPanel( "PlayPanel" ) ) )
		return

	thread OnLobbyMenu_PostGameOrChat( button )
}


void function OnLobbyMenu_NavigateBack()
{
	if ( GetMenuActiveTabIndex( file.menu ) == 0 )
	{
		if ( !IsControllerModeActive() )
			AdvanceMenu( GetMenu( "SystemMenu" ) )
	}
	else
	{
		TabData tabData = GetTabDataForPanel( file.menu )
		ActivateTab( tabData, 0 )
	}
}

void function OnLobbyMenu_PostGameOrChat( var button )
{
	var savedMenu = GetActiveMenu()

	#if CONSOLE_PROG
	const float HOLD_FOR_CHAT_DELAY = 1.0
	float startTime = Time()
	while ( InputIsButtonDown( BUTTON_BACK ) || InputIsButtonDown( KEY_TAB ) && GetConVarInt( "hud_setting_accessibleChat" ) != 0 )
	{
		if ( Time() - startTime > HOLD_FOR_CHAT_DELAY )
		{
			if ( GetPartySize() > 1 )
			{
				printt( "starting message mode", Hud_IsEnabled( GetLobbyChatBox() ) )
				Hud_StartMessageMode( GetLobbyChatBox() )
			}
			else
			{
				ConfirmDialogData dialogData
				dialogData.headerText = "#ACCESSIBILITY_NO_CHAT_HEADER"
				dialogData.messageText = "#ACCESSIBILITY_NO_CHAT_MESSAGE"
				dialogData.contextImage = $"ui/menu/common/dialog_notice"

				OpenOKDialogFromData( dialogData )
			}
			return
		}

		WaitFrame()
	}
	#endif

	if ( IsPostGameMenuValid() && savedMenu == GetActiveMenu() )
		OpenPostGameMenu( button )
}

void function OnLobbyMenu_FocusChat( var panel )
{
#if PC_PROG
	if ( IsDialog( GetActiveMenu() ) )
		return

	if ( !IsTabPanelActive( GetPanel( "PlayPanel" ) ) )
		return

	if ( GetPartySize() > 1 )
	{
		var playPanel = Hud_GetChild( file.menu, "PlayPanel" )
		var textChat = Hud_GetChild( playPanel, "ChatRoomTextChat" )
		Hud_SetFocused( Hud_GetChild( textChat, "ChatInputLine" ) )
	}
#endif
}
