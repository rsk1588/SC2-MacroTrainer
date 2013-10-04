﻿;-----------------------
;	For updates:
;	Change version number in exe and config file
;	Upload the changelog, file version  and new exe files to the ftp server
; 	check dont have debugging hotkeys and clipboards at end of script
;	check dont have the 'or debug' uncommented
;-----------------------
;	git add -A
;	git commit -m "Msg"
;	git push
;-----------------------


; if script re-copied from github should save it using UTF-8 with BOM (otherwise some of the ascii symbols like • wont be displayed correctly)
/*	Things to do



	Update unit panel structure so can add build progress and hallucination properties
	Check if chrono structures are powered - It seems to be a behaviour ' Power User (Queue) '
	Team send warn message after clicking building..maybe
*/

/*	
	Known Problems:
		Pressing Esc to cancel chat while having one base selected will cancel auto production for 4.5 seconds

	SC2 will not respond to a 'tab'-next subgroup command if the chat is open even when its not in focus
	the Shift+Tab (previous subgroup) does however work
*/

/*
	For Updates: 
	Disable Auto-Inject
	Disable Auto Grouping
	Disable Hostile colour assist
	Change ToggleWorkerState to #F2
	Local player colour
	Disable Spread and RemoveUnit

*/

/*
		MEMORY BENCHMARKS  	- 	NUMGET VS NORMAL METHOD
		
		Numget is ~20x faster when iterating the unit structure and gleaming same amount of information.
			(this is achieved by dumping the entire unit structure, then using numget to retrieve the info for the units)
		It is ~10x faster when iterating same unit structure but getting 2x the information

		To just dump the raw unit structure for 993 units takes 0.050565 ms 
			(this is done via ReadMemoryDump(B_uStructure, GameIdentifier, MVALUE, 0x1C0 * getHighestUnitIndex()))

		Numget is still faster even for a single memory read!
		for example, it takes 0.007222 ms for a single normal memory read e.g. unit x position
		numget (when dumping the entire unit i.e 0x1c0 bytes) takes 0.004794 ms
		numget (when dumping just the int/ x position - 4 bytes) takes 0.004575 ms

		These numbers were averaged over 10,000 reads.

*/
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance force
#MaxHotkeysPerInterval 99999	; a user requested feature (they probably have their own macro script)
#InstallMouseHook
#InstallKeybdHook
#UseHook
#Persistent
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#MaxThreads 20 ; don't know if this will affect anything
SetStoreCapslockMode, off ; needed in case a user bind something to the capslock key in sc2 - other AHK always sends capslock to adjust for case.
ListLines(False) 
SetControlDelay -1 	; make this global so buttons dont get held down during controlclick
SetKeyDelay, -1	 	; Incase SendInput reverts to Event - and for controlsend delay
SetMouseDelay, -1
SendMode Input 
SetBatchLines, -1
Menu, Tray, Icon 
if !A_IsAdmin 
{
	if (A_OSVersion = "WIN_XP") ; apparently the below command wont work on XP
		RunAsAdmin()
	else try  Run *RunAs "%A_ScriptFullPath%"
	ExitApp
}
OnExit, ShutdownProcedure
; Process, Priority, , H
; Process, Priority, , A
Menu Tray, Add, &Settings && Options, options_menu
Menu Tray, Add, &Check For Updates, TrayUpdate
Menu Tray, Add, &Homepage, Homepage
Menu Tray, Add, &Reload, g_reload
Menu Tray, Add, Exit, ExitApp ;this is actually a label not the command!
Menu Tray, Default, &Settings && Options
If A_IsCompiled
	Menu Tray, NoStandard
Else
{
	Menu Tray, Icon, Included Files\Used_Icons\Starcraft-2.ico

	debug := 1
	debug_name := "Kalamity"
	hotkey, ^+!F12, g_GiveLocalPalyerResources
}
RegRead, wHookTimout, HKEY_CURRENT_USER, Control Panel\Desktop, LowLevelHooksTimeout
if (ErrorLevel || wHookTimout < 650)
	RegWrite, REG_DWORD, HKEY_CURRENT_USER, Control Panel\Desktop, LowLevelHooksTimeout, 650
; This will up the timeout from  300 (default). Though probably isn't required


If 0 ; ignored by script but installed by compiler
{
  	FileInstall, Included Files\ahkH\AutoHotkeyMini.dll, this param is ignored
   	FileInstall, Included Files\ahkH\AutoHotkey.dll, this param is ignored
}
aThreads := []
aThreads.Speech := AhkDllThread("Included Files\ahkH\AutoHotkeyMini.dll")
aThreads.Speech.ahktextdll(generateSpeechScript())


start:
config_file := "MT_Config.ini"
old_backup_DIR := "Old Macro Trainers"
url := []
url.vr := "http://www.users.on.net/~jb10/macro_trainer_version.txt"
url.changelog := "http://www.users.on.net/~jb10/MT_ChangeLog.html"
url.HelpFile := "http://www.users.on.net/~jb10/MTSite/helpfulAdvice.html"
url.ChronoRules := "http://www.users.on.net/~jb10/MTSite/chronoBoost.html"
url.Homepage := "http://www.users.on.net/~jb10/MTSite/overview.html"
url.buyBeer := "http://www.users.on.net/~jb10/MTSite/buyBeer.html"
url.PixelColour := url.homepage "Macro Trainer/PIXEL COLOUR.htm"

MT_CurrentInstance := [] ; Used to store random info about the current run
program := []
program.info := {"IsUpdating": 0} ; program.Info.IsUpdating := 0 ;has to stay here as first instance of creating infor object

ProgramVersion := 2.982

l_GameType := "1v1,2v2,3v3,4v4,FFA"
l_Races := "Terran,Protoss,Zerg"
GLOBAL GameWindowTitle := "StarCraft II"
GLOBAL GameIdentifier := "ahk_exe SC2.exe"
GLOBAL GameExe := "SC2.exe"

; For some reason this has to come before Gdip_Startup() for reliability 
DllCall("RegisterShellHookWindow", UInt, getScriptHandle())

pToken := Gdip_Startup()
Global aUnitID, aUnitName, aUnitSubGroupAlias, aUnitTargetFilter, HexColour, MatrixColour
SetupUnitIDArray(aUnitID, aUnitName)
getSubGroupAliasArray(aUnitSubGroupAlias)
setupTargetFilters(aUnitTargetFilter)
SetupColourArrays(HexColour, MatrixColour)

Menu, Tray, Tip, MT_V%ProgramVersion% Coded By Kalamity

If InStr(A_ScriptDir, old_backup_DIR)
{
	Msgbox, 4372, Launch Directoy?, This program has been launched from the "%old_backup_DIR%" directory.`nThis could be caused by running  the program via a shortcut/link after the program has updated.`nThis is due to the fact that the windows shortcut is updated to the old versions 'new/backup' location.`nIn future, please don't run this program using shortcuts.`n`nI recommend pressing NO to EXIT.`n`n %A_Tab% Continue?
	IfMsgBox No
		ExitApp
}
Gosub, pre_startup ; go read the ini file

if MTCustomIcon 
	Menu, Tray, Tip, %A_Space% ;clear the tool tip on mouse over

SetProgramWaveVolume(programVolume)

;	this is required to enable drag and drop onto AHK control on vista and above 
;	systems while running with admin privileges 
; 	this has a 'process wide' scope (tested it, and it seems to mean what it says i.e. 
;	it reverts on closing)

if A_OSVersion in WIN_8,WIN_7,WIN_VISTA
{  
	DllCall("ChangeWindowMessageFilter", uint, 0x49, uint, 1) 	; WM_COPYGLOBALDATA 1 allows message to be received 
	DllCall("ChangeWindowMessageFilter", uint, 0x233, uint, 1) 	; WM_DROPFILES
}

;-----------------------
;	Startup
;-----------------------

InstallSC2Files()
#include %A_ScriptDir%\Included Files\Gdip.ahk
#include %A_ScriptDir%\Included Files\Colour Selector.ahk
#include %A_ScriptDir%\Included Files\Class_BufferInputFast.AHk
#include %A_ScriptDir%\Included Files\Class_ChangeButtonNames.AHk
;#Include <xml> ; in the local lib folder
#Include <SC2_MemoryAndGeneralFunctions> ;In the library folder
#Include <setLowLevelInputHooks> ;In the library folder

CreatepBitmaps(a_pBitmap, aUnitID)
aUnitInfo := []
a_pBrush := []

If (auto_update AND A_IsCompiled AND CheckForUpdates(ProgramVersion, url.vr ))
{
;	changelog_text := Url2Var(url.changelog)
	Gui, New
	Gui +Toolwindow	+LabelAUpdate_On
	Gui, Add, Picture, x12 y10 w90 h90 , %A_Temp%\Starcraft-2.ico
	Gui, Font, S10 CDefault Bold, Verdana
	Gui, Add, Text, x112 y10 w220, An update is available.
	Gui, Font, Norm 
	Gui, Add, Text, x112 y35 w560, Click UPDATE to download the latest version.
	Gui, Add, Text, x112 y+10 w560, Click CANCEL to continue running this version.
	Gui, Add, Text, x112 y+10 w560, Click DISABLE to stop the program automatically checking for updates.
	Gui, Font, S8 CDefault, Verdana
	Gui, Add, Text, x112 y+5 w560, %A_Tab% (You can still update via right clicking the tray icon.)
	Gui, Font, S10
	Gui, Add, Text, x112 y+10, You're currently running version %ProgramVersion%
	Gui, Font, S8 CDefault Bold, Verdana
	Gui, Add, Text, x10 y+5 w80, Changelog:
	Gui, Font, Norm

;	Gui, Add, Edit, x12 y+10 w560 h220 readonly -E0x200, % LTrim(changelog_text)
	Gui Add, ActiveX, x12  w560 h220  vWB, Shell.Explorer
	WB.Navigate(url.changelog)
	Gui, Font, S8 CDefault Bold, Verdana
	Gui, Add, Button, Default x50 y+20 w100 h30 gUpdate, &Update
	Gui, Font, Norm 
	Gui, Add, Button, x+100 yp w100 h30 gLaunch vDisable_Auto_Update, &Disable
	Gui, Add, Button, x+100 yp w100 h30 gLaunch vCancel_Auto_Update, &Cancel
	Gui, Show, w600, Macro Trainer Update
	Return				
}

Launch:

If (A_GuiControl = "Disable_Auto_Update")
	Iniwrite, % auto_update := 0, %config_file%, Misc Settings, auto_check_updates
If (A_GuiControl = "Disable_Auto_Update" OR A_GuiControl = "Cancel_Auto_Update")
	Gui Destroy

If launch_settings
	gosub options_menu

if (MTCustomProgramName && A_ScriptName != MTCustomProgramName && A_IsCompiled)
{
	FileCopy, %A_ScriptName%, %MTCustomProgramName%, 1
	FullPath := A_ScriptDir "\" MTCustomProgramName
	if (A_OSVersion = "WIN_XP") ; apparently the below command wont work on XP
		try RunAsAdmin(FullPath, A_ScriptDir)
	else try Run *RunAs "%FullPath%"
	ExitApp
}

if (!instr(getSystemLanguage(), "English") && !MT_HasWarnedLanguage)
{
	IniWrite, 1, %config_file%, Misc Info, MT_HasWarnedLanguage
	msgbox % "It seems you are using a non-English language/character-set.`nThis program may not function correctly with non-English keyboard layouts."
			. "`n`nIf you experience problems, perhaps try changing your keyboard layout/language to English."
			. "`n`nYou will not see this warning again."
}

; 	Note:	Emergency Restart Hotkey - Something to keep in mind if actually using the Real BlockInput Command 
;	Certain types of hook hotkeys can still be triggered when BlockInput is on. 
;	Examples include MButton (mouse hook) and LWin & Space
;	 ***(KEYBOARD HOOK WITH EXPLICIT PREFIX RATHER THAN MODIFIERS "$#")***.
;	hence <#Space wont work

CreateHotkeys()			;create them before launching the game in case users want to edit them
process, exist, %GameExe%
If !errorlevel
{
	MT_CurrentInstance.SCWasRunning := False
	try run % StarcraftExePath()
}
else MT_CurrentInstance.SCWasRunning := True
Process, wait, %GameExe%	
	
	; 	waits for starcraft to exist
	; 	give time for SC2 to fully launch. This may be required on slower or stressed computers
	;	to give time for the  window to fully launch and activate to allow the
	; 	WinGet("EXStyle") style checks to workto work properly
	;  	Placed here, as it will also give extra time before trying to get 
	;	base address (though it shouldn't be required for this)

if !MT_CurrentInstance.SCWasRunning
	sleep 2000 
while (!(B_SC2Process := getProcessBaseAddress(GameIdentifier)) || B_SC2Process < 0)		;using just the window title could cause problems if a folder had the same name e.g. sc2 folder
	sleep 400				; required to prevent memory read error - Handle closed: error 		
SC2hWnd := WinExist(GameIdentifier)
OnMessage(DllCall("RegisterWindowMessage", Str,"SHELLHOOK" ), "ShellMessage")

loadMemoryAddresses(B_SC2Process)	

; it would have been better to assign all the addresses to one super global object
; but i tried doing this once before and it caused issues because i forgot to update some address 
; names in the functions.... so i cant be bothered taking the risk
settimer, clock, 250
settimer, timer_exit, 5000, -100
; no using a shell monitor to keep destroy overlays
;SetTimer, OverlayKeepOnTop, 1000, -20	;better here, as since WOL 2.0.4 having it in the "clock" section isn't reliable 	

l_Changeling := aUnitID["ChangelingZealot"] "," aUnitID["ChangelingMarineShield"] ","  aUnitID["ChangelingMarine"] 
				. ","  aUnitID["ChangelingZerglingWings"] "," aUnitID["ChangelingZergling"]


if A_OSVersion in WIN_7,WIN_VISTA 
{
	if !DwmIsCompositionEnabled() && !MT_DWMwarned && !MT_Restart && A_IsCompiled ; so not restarted via hotkey or icon 
	{
		ChangeButtonNames.set("DWM is Disabled?", "Help", "Ignore") 
		; msgbox with exclamation and Ok, Cancel Buttons
		MsgBox, 49, DWM is Disabled?
		,	% "Desktop Widows Management (DWM) is disabled!`n`n" 
		.	"This will cause significant performance issues while using this program.`n"
		.  	"Your FPS can be expected to decrease by 70%`n`n" 
		.	"Click  'Help' to launch some URLs explaining how to do enable DWM.`n`n"
		.	"You will not see this warning again!"	
		IniWrite, % MT_DWMwarned := True, %config_file%, Misc Info, MT_DWMwarned
		ifMsgbox Ok ; 'Help'
		{
			run http://answers.microsoft.com/en-us/windows/forum/windows_vista-desktop/need-to-enable-desktop-window-manager/7e011e13-1005-467b-8dc0-10342f8f71e6
			run http://www.petri.co.il/enable_windows_vista_aero_graphics.htm
		}
	}
}

; SC2 Window Modes EXStyle
; Windowed FullScreen 	:= 0x00040000
; FullScreen 			:= 0x00040008
; Windowed 				:= 0x00040100
 
; Breakdown
; WS_THICKFRAME       =   0x00040000 ; WindowedFullScreen
; WS_EX_TOPMOST       =   0x00000008
; WS_EX_WINDOWEDGE    =   0x00000100
; winset fails when attempting to modify these values

; 	Style or ExStyle: Retrieves an 8-digit hexadecimal number representing style 
;	or extended style (respectively) of a window. 
;	If there are no matching windows, OutputVar is made blank. 
SC2WindowEXStyles := []
	SC2WindowEXStyles.WindowedFullScreen := 0x00040000
	SC2WindowEXStyles.FullScreen := 0x00040008
	SC2WindowEXStyles.Windowed := 0x00040100

If WinGet("EXStyle", GameIdentifier) = SC2WindowEXStyles.FullScreen
&& (DrawMiniMap || DrawAlerts || DrawSpawningRaces
|| DrawIncomeOverlay || DrawResourcesOverlay || DrawArmySizeOverlay
|| DrawWorkerOverlay || DrawIdleWorkersOverlay || DrawLocalPlayerColourOverlay
|| DrawUnitOverlay)
&& !MT_Restart && A_IsCompiled ; so not restarted via hotkey or icon 
{
	ChangeButtonNames.set("SC2 Is NOT in 'windowed Fullscreen' mode!", "Disable", "Continue") 
	; OK/Cancel messagebox
	MsgBox, 49, SC2 Is NOT in 'windowed Fullscreen' mode!
	, % "Starcraft seems to be in 'fullscreen' mode and you have overlays enabled within"
	. " the Macro Trainer.`n`n"
	. "The Minimap hack and overlays will only be visible while in 'windowed Fullscreen' mode.`n`n"
	. "This setting can be changed within the SC2 options menu.`n`n"
	. "Click 'Disable' to turn off all the overlays in Macro Trainer.`n"
	. "Click 'Continue' if you intend on changing the SC2 Window Mode."
	ifMsgbox Ok ; 'Disable'
	{
		DrawMiniMap := DrawAlerts := DrawSpawningRaces := DrawIncomeOverlay := DrawResourcesOverlay
		:= DrawArmySizeOverlay := DrawWorkerOverlay := DrawIdleWorkersOverlay 
		:= DrawLocalPlayerColourOverlay := DrawUnitOverlay := 0
		gosub, ini_settings_write
	}
}
settimer, g_CheckForScriptToGetGameInfo, -3600000 ; 1hour
return

;-----------------------
; End of execution
;-----------------------
;2147483647  - highest priority so if i ever give something else a high priority, this key combo will still interupt (if thread isnt critical)
;#MaxThreadsBuffer on
;<#Space::
g_EmergencyRestart:	
;Thread, Priority, 2147483647 ; doubt this does anything. But due to problem with using the hotkeycommand try it
		releaseAllModifiers() 					;This will be active irrespective of the window
		RestoreModifierPhysicalState()		;input on ; this doesnt really do anything now - not needed
		settimer, EmergencyInputCountReset, 5000, -100	
		EmergencyInputCount++		 
		If (EmergencyInputCount = 1)
		{
			BufferInputFast.disableHotkeys()
			BufferInputFast.createHotkeys(aButtons.List) 
			CreateHotkeys()
		}
		else If (EmergencyInputCount >= 3)
		{
			IniWrite, Hotkey, %config_file%, Misc Info, RestartMethod ; could have achieved this using running the new program with a parameter then checking %1%
		g_reload:
			if (A_ThisLabel = "g_reload")
				IniWrite, Icon, %config_file%, Misc Info, RestartMethod
			SoundPlay, %A_Temp%\Windows Ding.wav
			if (time && alert_array[GameType, "Enabled"])
				doUnitDetection(unit, type, owner, "Save")	;these first 3 vars are nothing - they wont get Read
		;	try  Run "%A_ScriptFullPath%"
			if (A_OSVersion = "WIN_XP") ; apparently the below command wont work on XP
				try RunAsAdmin()
			else try  Run *RunAs "%A_ScriptFullPath%"
			ExitApp	;does the shutdown procedure.
		}
		SoundPlay, %A_Temp%\Windows Ding2.wav	
	return	
;#MaxThreadsBuffer Off

EmergencyInputCountReset:
	settimer, EmergencyInputCountReset, off
	EmergencyInputCount := 0
	Return

; this is required as the 'exit' on the tray icon can only launch labels
; and if it actually goes to " ShutdownProcedure: " the shudown procedure will actually get run twice! (not a big deal....)
; Once from the label, and a second time due to the first use of ExitApp command 
ExitApp:
	ExitApp ; invokes the shutdown procedure
return 

g_ListVars:
	ListVars
	return

g_GetDebugData:
	clipboard := debugData := DebugData()
	IfWinExist, DebugData Vr: %ProgramVersion%
		WinClose
	Gui, New 
	Gui, Add, Edit, x12 y+10 w980 h640 readonly -E0x200, % LTrim(debugData)
	Gui, Show,, DebugData Vr: %ProgramVersion%
return

Stealth_Exit:
	ExitApp
	return

g_PlayModifierWarningSound:
	SoundPlay, %A_Temp%\ModifierDown.wav
return
ping:
	send, !g
	sleep 10
	Click
	Return

g_DoNothing:
Return			

g_LbuttonDown:	;Get the location of a dragbox
	MouseGetPos, MLDownX, MLDownY
return 

; Not currently Used
/*
g_RbuttonDown:
LastMousePress(A_TickCount)
Return

LastMousePress(newTick := 0)
{
	static LastPressTick
	if !newTick
		return A_TickCount - LastPressTick
	LastPressTick := newTick
	return
}	
*/

g_GiveLocalPalyerResources:
	SetPlayerMinerals()
	SetPlayerGas()
return	

g_GLHF:
	ReleaseModifiers(0)
	SetStoreCapslockMode, On ;as I turned it off in the auto Exec section
	if !isChatOpen()
		send, +{Enter}
	send, GL{ASC 3}HF{!}
	SetStoreCapslockMode, Off ; this isn't really needed as it is no off by default for new threads
return

g_DeselectUnit:
if (getSelectionCount() > 1)
{
	ClickUnitPortrait(0, X, Y, Xpage, Ypage) ; -1 as selection index begins at 0 i.e 1st unit at pos 0 top left
	MTclick(X, Y, "Left", "+")
}
return


;	This ReleaseModifiers function needs to wait an additional amount of time, as SC2 can be slow to 
;	update its keystate and/or it buffers input/keys for a while. Perhaps checking logical keystate would be better
;	but this isnt solid as the game state is still slower to change than this.
; 	I have added the AdditionalKeys which is mainly used for zerg burrow
;	and i have provided an additional 15 ms sleep time if burrow is being held down
; 	can't use critical inside function, as that will delay all timers too much

ReleaseModifiers(Beep = 1, CheckIfUserPerformingAction = 0, AdditionalKeys = "", CheckAllKeys := 0, timeout := "", LastButtonPress := 0) ;timout in ms
{

	startTime := A_Tickcount

	While getkeystate("Shift", "P") || getkeystate("Control", "P") || getkeystate("Alt", "P")
	|| getkeystate("LWin", "P") || getkeystate("RWin", "P")		
	|| getkeystate("Shift") || getkeystate("Control") || getkeystate("Alt")
	|| getkeystate("LWin") || getkeystate("RWin")
	|| getkeystate("LButton", "P") || getkeystate("LButton")
	|| getkeystate("RButton", "P") || getkeystate("RButton")
	|| readModifierState() 
	|| (AdditionalKeys && isaKeyPhysicallyOrLogicallyDown(AdditionalKeys))  ; ExtraKeysDown should actually return the actual key
	|| (CheckAllKeys && checkAllKeyStates())  
	|| (isPerformingAction := CheckIfUserPerformingAction && isUserPerformingAction()) ; have this function last as it can take the longest if lots of units selected
	|| (LastButtonPress && MT_InputIdleTime() < LastButtonPress)
	{
		if (timeout && A_Tickcount - startTime >= timeout)
			return 1 ; was taking too long
		if (A_Index = 1 && Beep && !isPerformingAction)	;wont beep if casting or burrow AKA 'extra key' is down
			SoundPlay, %A_Temp%\ModifierDown.wav	
		sleep, 1 ;sleep(5)
	}

	return
}

isaKeyPhysicallyOrLogicallyDown(Keys)
{
  if isobject(Keys)
  {
    for Index, Key in Keys
      if getkeystate(Key, "P") || getkeystate(Key)
        return key
  }
  else if getkeystate(Keys, "P") || getkeystate(Keys)
  	return Keys ;keys!
  return 0
}

g_SendBaseCam:
	send, {Backspace}
return
g_CreateBaseCam1:
	send, +{F2}
Return
g_CreateBaseCam2:
	send, +{F3}
Return
g_CreateBaseCam3:
	send, +{F4}
Return
g_BaseCam1:
	send, {F2}
Return
g_BaseCam2:
	send, {F3}
Return
g_BaseCam3:
	send, {F4}
Return	

g_FineMouseMove:
	FineMouseMove(A_ThisHotkey)
Return

FineMouseMove(Hotkey)
{
	MouseGetPos, MX, MY
	if (Hotkey = "Left")
		mousemove, (MX-1), MY
	else if (Hotkey = "Right")
		mousemove, (MX+1), MY
	else if (Hotkey = "Up")
		mousemove, MX, MY-1
	else if (Hotkey = "Down")
		mousemove, MX, MY+1
}

g_FindTestPixelColourMsgbox:
	IfWinExist, Pixel Colour Finder
	{	
		WinActivate
		Return 					
	}
	Gui, New
	Gui +Toolwindow	+AlwaysOnTop
	Gui, Font, S10 CDefault Bold, Verdana
	Gui, Add, Text, x+40 y+10 w220, Colour Finder:
	Gui, Font,
	Gui, Add, Text, x20 y+10, Click " Help "  to learn how to set the pixel colour.
	Gui, Add, Text, x20 Y+10, Click " Start "  to begin.
	Gui, Add, Text, x20 y+10, Click " Cancel "  to leave.
	Gui, Add, Button, Default x30 y+30 w100 h30 default gg_PixelColourFinderHelpFile, &Help
	Gui, Add, Button, Default x+30  w100 h30 gg_FindTestPixelColour, Start
	Gui, Add, Button, Default x+30  w100 h30 gGuiReturn, Cancel
	Gui, Font, Norm 
	gui, show,, Pixel Colour Finder
return

g_PixelColourFinderHelpFile:
	IfWinExist, Pixel Finder - How To:
	{	WinActivate
		Return 					
	}
	Gui, New 
	Gui Add, ActiveX, xm w980 h640 vWB, Shell.Explorer
	WB.Navigate(url.PixelColour)
	Gui, Show,, Pixel Finder - How To:
Return

g_FindTestPixelColour:
	Gui, Destroy
	g_FindTestPixelColour()
Return

g_FindTestPixelColour()
{ 	global AM_MiniMap_PixelColourAlpha, AM_MiniMap_PixelColourRed, AM_MiniMap_PixelColourGreen, AM_MinsiMap_PixelColourBlue
	SoundPlay, %A_Temp%\Windows Ding.wav
	l_DirectionalKeys := "Left,Right,Up,Down"
	loop, parse, l_DirectionalKeys, `,
		hotkey, %A_loopfield%, g_FineMouseMove, on
	loop
	{
		pBitMap := GDIP_BitmapFromScreen()
		MouseGetPos, MX, MY
		FoundColour := GDIP_GetPixel(pbitmap, MX, MY) ;ARGB format
		GDIP_DisposeImage(pBitMap)
		tooltip, % "Found Colour: "  A_Tab FoundColour "`n`nUse the Left/Right/Up/Down Arrows to move the mouse accurately`n`n" A_Tab "Press Enter To Save`n`n" A_Tab "Press Backspace To Cancel", MX+50, MY-70
		if getkeystate("Enter", "P")
		{
			SoundPlay, %A_Temp%\Windows Ding.wav
			Gdip_FromARGB(FoundColour, A, R, G, B)	
			guicontrol, Options:, AM_MiniMap_PixelColourAlpha, %A%
			guicontrol, Options:, AM_MiniMap_PixelColourRed, %R%
			guicontrol, Options:, AM_MiniMap_PixelColourGreen, %G%
			guicontrol, Options:, AM_MinsiMap_PixelColourBlue, %B%
			break
		}
		else if getkeystate("Backspace", "P")
			break
	}
	tooltip
	loop, parse, l_DirectionalKeys, `,
		hotkey, %A_loopfield%, g_FineMouseMove, off
return
}

g_PrevWarning:
	If PrevWarning
	{
		tSpeak(PrevWarning.speech)
		MiniMapWarning.insert({"Unit": PrevWarning.unitIndex, "Time": Time})
	}
	Else tSpeak("There have been no alerts")
Return

Adjust_overlay:
	Dragoverlay := 1
	{
		gosub overlay_timer
		if DrawUnitOverlay
			gosub g_unitPanelOverlay_timer
	;	SetTimer, OverlayKeepOnTop, off	
		SetTimer, overlay_timer, 50, 0		; make normal priority so it can interupt this thread to move
		SetTimer, g_unitPanelOverlay_timer, 50, 0
		SoundPlay, %A_Temp%\On.wav
	}	
	sleep 500
	KeyWait, %AdjustOverlayKey%, T40
	Dragoverlay := 0	 	
	{
	;	SetTimer, OverlayKeepOnTop, 1000, -20
		SetTimer, overlay_timer, %OverlayRefresh%, -8
		SetTimer, g_unitPanelOverlay_timer, %UnitOverlayRefresh%, -9
		SoundPlay, %A_Temp%\Off.wav
		WinActivate, %GameIdentifier%
	}
Return	

Toggle_Identifier:
	If OverlayIdent = 3
		OverlayIdent := 0
	Else OverlayIdent ++
	Iniwrite, %OverlayIdent%, %config_file%, Overlays, OverlayIdent
	gosub, overlay_timer
	gosub, g_unitPanelOverlay_timer
Return


Overlay_Toggle:
	if (A_ThisHotkey = CycleOverlayKey)
	{
		tooltip, %A_ThisHotkey%, 500, 500
		If ((ActiveOverlays := DrawIncomeOverlay + DrawResourcesOverlay + DrawArmySizeOverlay + DrawUnitOverlay) > 1)
		{
			DrawResourcesOverlay := DrawArmySizeOverlay := DrawIncomeOverlay := DrawUnitOverlay := 0
			DrawResourcesOverlay(-1), DrawArmySizeOverlay(-1), DrawIncomeOverlay(-1), DrawUnitOverlay(-1)
		}
		Else If (ActiveOverlays = 0)
			DrawIncomeOverlay := 1
		Else
		{
			If DrawIncomeOverlay
				DrawResourcesOverlay := !DrawIncomeOverlay := DrawUnitOverlay := 0, DrawIncomeOverlay(-1) 				
			Else If DrawResourcesOverlay
				DrawArmySizeOverlay := !DrawResourcesOverlay := DrawUnitOverlay := 0, DrawResourcesOverlay(-1)
			Else If DrawArmySizeOverlay
				DrawUnitOverlay := !DrawResourcesOverlay := DrawArmySizeOverlay :=  0, DrawArmySizeOverlay(-1)
			Else If DrawUnitOverlay 	; turn them all on
				DrawResourcesOverlay := DrawArmySizeOverlay := DrawIncomeOverlay := 1 	
		}
		gosub, overlay_timer
		gosub, g_unitPanelOverlay_timer
	}	
	Else If (A_ThisHotkey = ToggleIncomeOverlayKey)
	{
		If (!DrawIncomeOverlay := !DrawIncomeOverlay)
			DrawIncomeOverlay(-1)	
	}
	Else If (A_ThisHotkey = ToggleResourcesOverlayKey)
	{
		If (!DrawResourcesOverlay := !DrawResourcesOverlay)
			DrawResourcesOverlay(-1)
	}
	Else If (A_ThisHotkey = ToggleArmySizeOverlayKey)
	{
		If (!DrawArmySizeOverlay := !DrawArmySizeOverlay)
			DrawArmySizeOverlay(-1)	
	}
	Else If (A_ThisHotkey = ToggleWorkerOverlayKey)
	{
		If (!DrawWorkerOverlay := !DrawWorkerOverlay)
			DrawWorkerOverlay(-1)
	}	
	Else If (A_ThisHotkey = ToggleIdleWorkersOverlayKey)
	{
		If (!DrawIdleWorkersOverlay := !DrawIdleWorkersOverlay)
			DrawIdleWorkersOverlay(-1)
	}	
	Else If (A_ThisHotkey = ToggleUnitOverlayKey)
	{
		If (!DrawUnitOverlay := !DrawUnitOverlay)
			DrawUnitOverlay(-1)
		gosub, g_unitPanelOverlay_timer
		return
	}	
	Else If (A_ThisHotkey = ToggleMinimapOverlayKey)
	{
		; Disable the minimap, but still draws detected units/non-converted gates
		DrawMiniMap := !DrawMiniMap
		gosub, MiniMap_Timer 
		return	
	}
	gosub, overlay_timer ;this makes the change take effect immediately. 
Return

mt_pause_resume:
	if (mt_Paused := !mt_Paused)
	{
		game_status := "lobby" ; with this clock = 0 when not in game 
		timeroff("clock", "money", "gas", "scvidle", "supply", "worker", "inject", "unit_bank_read", "Auto_mine", "Auto_Group", "AutoGroupIdle", "MiniMap_Timer", "overlay_timer", "g_unitPanelOverlay_timer", "g_autoWorkerProductionCheck", "cast_ForceInject")
		inject_timer := 0	;ie so know inject timer is off
		Try DestroyOverlays()
		tSpeak("Macro Trainer Paused")
	}	
	Else
	{
		settimer, clock, 250
		tSpeak("Macro Trainer Resumed")
	}
return
;------------
;	clock
;------------
clock:
	time := GetTime()
	if (!time && game_status = "game") || (UpdateTimers) ; time=0 outside game
	{	
		game_status := "lobby" ; with this clock = 0 when not in game (while in game at 0s clock = 44)	
		timeroff("money", "gas", "scvidle", "supply", "worker", "inject", "unit_bank_read", "Auto_mine", "Auto_Group", "AutoGroupIdle", "MiniMap_Timer", "overlay_timer", "g_unitPanelOverlay_timer", "g_autoWorkerProductionCheck", "cast_ForceInject")
		inject_timer := TimeReadRacesSet := UpdateTimers := Overlay_RunCount := PrevWarning := WinNotActiveAtStart := ResumeWarnings := 0 ;ie so know inject timer is off
		if aThreads.MiniMap.ahkReady()
			aThreads.MiniMap.ahkPostFunction("gameChange")
		Try DestroyOverlays()
		setLowLevelInputHooks(False)
	}
	Else if (time && game_status != "game") && (getLocalPlayerNumber() != 16 || debug) ; Local slot = 16 while in lobby/replay - this will stop replay announcements
	{
		game_status := "game", warpgate_status := "not researched", gateway_count := warpgate_warning_set := 0
		AW_MaxWorkersReached := TmpDisableAutoWorker := 0
		MiniMapWarning := [], a_BaseList := [], aGatewayWarnings := []
		aResourceLocations := []
		MT_CurrentGame := []	; This is a variable which from now on will store
								; Info about the current game for other functions 
								; An easy way to have the info cleared each match
		Global aUnitModel := []

		If (DrawMiniMap || DrawAlerts || DrawSpawningRaces)
		{
			if !aThreads.MiniMap.ahkReady()
			{
				aThreads.MiniMap := AhkDllThread("Included Files\ahkH\AutoHotkey.dll")
				aThreads.MiniMap.ahkdll(A_ScriptDir "\threadMiniMap.ahk")
			}
			aThreads.MiniMap.ahkPostFunction("gameChange")
		}
		Else if aThreads.MiniMap.ahkReady()
			aThreads.MiniMap.ahkPostFunction("exitApp") ; use post function so don't have to wait and delay the routine below
	


		; Install the hook here. In case it got removed.
		; Remove it at the end of the game.
		; Also scrolling GUI listboxes with the hook installed
		; causes the scroll to lag. Obviously it will still lag if user opens the
		; gui while in a game the scroll will still lag.

		setLowLevelInputHooks(True)
		BufferInputFast.disableHotkeys() ; disable any previously created buffered hotkeys in case user has changed the key blocking list
		BufferInputFast.createHotkeys(aButtons.List) ; re-create the hotkeys	
		if WinActive(GameIdentifier)
			ReDrawMiniMap := ReDrawIncome := ReDrawResources := ReDrawArmySize := ReDrawWorker := RedrawUnit := ReDrawIdleWorkers := ReDrawLocalPlayerColour := 1
		if idle_enable	;this is the idle AFK
			settimer, user_idle, 1000, -5
		if (MaxWindowOnStart && time < 5 && !WinActive(GameIdentifier)) 
		{	
			WinActivate, %GameIdentifier%
			MouseMove A_ScreenWidth/2, A_ScreenHeight/2
			WinNotActiveAtStart := 1
		}
		global aPlayer, aLocalPlayer
		getPlayers(aPlayer, aLocalPlayer)
		GameType := GetGameType(aPlayer)
		if (ResumeWarnings || UserSavedAppliedSettings && alert_array[GameType, "Enabled"])  
			doUnitDetection(unit, type, owner, "Resume")	;these first 3 vars are nothing - they wont get Read
		Else
			doUnitDetection(unit, type, owner, "Reset") ; clear the variables within the function
		If (F_Inject_Enable && aLocalPlayer["Race"] = "Zerg")
		{
			zergGetHatcheriesToInject(oHatcheries)
			settimer, cast_ForceInject, %FInjectHatchFrequency%	
		}
		aResourceLocations := getMapInforMineralsAndGeysers()
		if	mineralon
			settimer, money, 500, -5
		if	gas_on
			settimer, gas, 1000, -5
		if idleon		;this is the idle worker
			settimer, scvidle, 500, -5	; the idle scv pointer changes every game
		if supplyon
			settimer, supply, 200, -5
		if workeron
			settimer, worker, 1000, -5
		LocalPlayerRace := aLocalPlayer["Race"] ; another messy lazy variable
		if (EnableAutoWorker%LocalPlayerRace%Start && (aLocalPlayer["Race"] = "Terran" || aLocalPlayer["Race"] = "Protoss") )
		{
			SetTimer, g_autoWorkerProductionCheck, 200
			EnableAutoWorker%LocalPlayerRace% := True
		}
		if ( Auto_Read_Races AND race_reading ) && 	!((ResumeWarnings || UserSavedAppliedSettings) && time > 12)
			SetTimer, find_races_timer, 1000, -20
		If (aLocalPlayer["Race"] = "Terran")
			SupplyType := aUnitID["SupplyDepot"]
		Else If (aLocalPlayer["Race"] = "Protoss")
			SupplyType := aUnitID["Pylon"]		
		if (alert_array[GameType, "Enabled"] || warpgate_warn_on || supplyon) 
			settimer, unit_bank_read, %UnitDetectionTimer_ms%, -5
		global minimap		
		SetMiniMap(minimap)
		setupMiniMapUnitLists()
		l_ActiveDeselectArmy := setupSelectArmyUnits(l_DeselectArmy, aUnitID)
		ShortRace := substr(LongRace := aLocalPlayer["Race"], 1, 4) ;because i changed the local race var from prot to protoss i.e. short to long - MIGHT NO be needed  now
		setupAutoGroup(aLocalPlayer["Race"], A_AutoGroup, aUnitID, A_UnitGroupSettings)
		If A_UnitGroupSettings["AutoGroup", aLocalPlayer["Race"], "Enabled"]
		{
			settimer, Auto_Group, %AutoGroupTimer% 						; set to 30 ms via config ini default
																		; WITH Normal 1 priority so it should run once every 30 ms
			settimer, AutoGroupIdle, %AutoGroupTimerIdle%, -9999 		; default ini value 5 ms - Lowest priority so will only run when script is idle! And wont interrupt any other timer
																		; and so wont prevent the minimap or overlay being drawn
																		; note may delay some timers from launching for a fraction of a ms while its in thread, no timers interupt mode (but it takes less than 1 ms to run anyway)
		} 																; Hence with these two timers running autogroup will occur at least once every 30 ms, but generally much more frequently
		CreateHotkeys()
		if !A_IsCompiled
		{
			Hotkey, If, WinActive(GameIdentifier) && time && !BufferInputFast.isInputBlockedOrBuffered()
			hotkey, >!g, g_GLHF
			Hotkey, If
		}	
	;	If (DrawMiniMap OR DrawAlerts OR DrawSpawningRaces)
	;		SetTimer, MiniMap_Timer, %MiniMapRefresh%, -7		
		SetTimer, overlay_timer, %OverlayRefresh%, -8	
		SetTimer, g_unitPanelOverlay_timer, %UnitOverlayRefresh%, -9	

		EnemyBaseList := GetEBases()		
		UserSavedAppliedSettings := 0
		If IsInList(aLocalPlayer.Type, "Referee", "Spectator")
			timeroff("money", "gas", "scvidle", "supply", "worker", "inject"
				, "unit_bank_read", "Auto_mine", "Auto_Group", "AutoGroupIdle"
				, "MiniMap_Timer", "overlay_timer", "g_unitPanelOverlay_timer"
				, "g_autoWorkerProductionCheck", "cast_ForceInject")
	}
return



setupSelectArmyUnits(l_input, aUnitID)
{
	aUnits := []
	StringReplace, l_input, l_input, %A_Space%, , All ; Remove Spaces
	l_input := Trim(l_input, " `t , |")
	loop, parse, l_input, `,
		l_army .= aUnitID[A_LoopField] ","
	return 	l_army := Trim(l_army, " `t , |")
}


;-------------------------
;	End of Game 'Setup'
;-------------------------

Cast_ChronoStructure:
	UserPressedHotkey := A_ThisHotkey ; as this variable can get changed very quickly
	Thread, NoTimers, True
	BufferInputFast.BlockInput()
	if (UserPressedHotkey = Cast_ChronoStargate_Key)
		Cast_ChronoStructure(aUnitID.Stargate)
	Else if (UserPressedHotkey = Cast_ChronoForge_Key)
		Cast_ChronoStructure(aUnitID.Forge)
	Else if (UserPressedHotkey = Cast_ChronoNexus_Key)
		Cast_ChronoStructure(aUnitID.Nexus)
	Else If (UserPressedHotkey = Cast_ChronoGate_Key)
		Cast_ChronoStructure(aUnitID.WarpGate) ; this will also do gateways	
	Else If (UserPressedHotkey = Cast_ChronoRoboticsFacility_Key)
		Cast_ChronoStructure(aUnitID.RoboticsFacility) ; this will also do gateways
	BufferInputFast.disableBufferingAndBlocking()
return


Cast_ChronoStructure(StructureToChrono)
{	GLOBAL aUnitID, CG_control_group, chrono_key, CG_nexus_Ctrlgroup_key, CG_chrono_remainder, ChronoBoostSleep
	, HumanMouse, HumanMouseTimeLo, HumanMouseTimeHi, NextSubgroupKey

	oStructureToChrono := [], a_gateways := [], a_gatewaysConvertingToWarpGates := [], a_WarpgatesOnCoolDown := []

	numGetControlGroupObject(oNexusGroup, CG_nexus_Ctrlgroup_key)
	for index, unit in oNexusGroup.units
	{
		if (unit.type = aUnitID.Nexus && !isUnderConstruction(unit.unitIndex))
			nexus_chrono_count += Floor(unit.energy/25)
;		cant really do this check with a control group
;		if !isUnitAStructure(object.unitIndex) ; as units will have higher priority and appear in group 0/top left control card - and this isnt compatible with this macro
;		{
;			tSpeak("Error in Base Control Group.")
;			return 
;		}
	}

	IF !nexus_chrono_count
		return

	Unitcount := DumpUnitMemory(MemDump)

	if (StructureToChrono = aUnitID.WarpGate)
	{
		while (A_Index <= Unitcount)
		{
			unit := A_Index - 1
			if isTargetDead(TargetFilter := numgetUnitTargetFilter(MemDump, unit)) || !isOwnerLocal(numgetUnitOwner(MemDump, Unit))
			|| isTargetUnderConstruction(TargetFilter)
		       Continue
	    	Type := numgetUnitModelType(numgetUnitModelPointer(MemDump, Unit))
	    	IF ( type = aUnitID["WarpGate"] && !isUnitChronoed(unit)) && (cooldown := getWarpGateCooldown(unit))
				a_WarpgatesOnCoolDown.insert({"Unit": unit, "Cooldown": cooldown})
			Else IF (type = aUnitID["Gateway"] && !isUnitChronoed(unit))
			{
				if isGatewayConvertingToWarpGate(unit)
					a_gatewaysConvertingToWarpGates.insert(unit) 
				else 
				{		
					progress :=  getBuildStats(unit, QueueSize)	; need && QueueSize as if progress reports 0 when idle it will be added to the list
					if ( (progress < .95 && QueueSize) || QueueSize > 1) ; as queue size of 1 means theres only 1 item being produced
						a_gateways.insert({Unit: unit, QueueSize: QueueSize, progress: progress})
				}	

			}															  
		}	

		if a_WarpgatesOnCoolDown.MaxIndex()
			bubbleSort2DArray(a_WarpgatesOnCoolDown, "Cooldown", 0)	;so warpgates with longest cooldown get chronoed first
		if a_gatewaysConvertingToWarpGates.MaxIndex()	
			RandomiseArray(a_gatewaysConvertingToWarpGates)
		if a_gateways.MaxIndex()
		{
			bubbleSort2DArray(a_gateways, "progress", 1) 				; so the strucutes with least progress gets chronoed (providing have same queue size)
			bubbleSort2DArray(a_gateways, "QueueSize", 0) 			; so One with the longest queue gets chronoed first
		}

		for index, Warpgate in a_WarpgatesOnCoolDown 			; so Warpgates will get chronoed 1st
			oStructureToChrono.insert({Unit: Warpgate.Unit})	; among warpgates longest cooldown gets done first

		for index, gateway in a_gatewaysConvertingToWarpGates 	; gateways converting to warpgates get chronoed next
			oStructureToChrono.insert({Unit:gateway}) 			; among these gateways, order is random

		for index, object in a_gateways 						; gateways producing a unit come last
			oStructureToChrono.insert({Unit: object.Unit})		; among these it goes first by queue size, then progress
	}
	else 
	{
		while (A_Index <= Unitcount)
		{
			unit := A_Index - 1
			if isTargetDead(TargetFilter := numgetUnitTargetFilter(MemDump, unit)) || !isOwnerLocal(numgetUnitOwner(MemDump, Unit))
			|| isTargetUnderConstruction(TargetFilter)
		       Continue
	    	Type := numgetUnitModelType(numgetUnitModelPointer(MemDump, Unit))
	    	IF ( type = StructureToChrono && !isUnitChronoed(unit) ) 
			{	
				progress :=  getBuildStats(unit, QueueSize)	; need && QueueSize as if progress reports 0 when idle it will be added to the list
				if ( (progress < .95 && QueueSize) || QueueSize > 1) ; as queue size of 1 means theres only 1 item being produced
					oStructureToChrono.insert({Unit: unit, QueueSize: QueueSize, progress: progress})
			}
		}
		;	structures with the longest queues will be chronoed first
		; 	if queue size is equal, chronoed by progress (least progressed chronoed 1st)

		bubbleSort2DArray(oStructureToChrono, "progress", 1) ; so the strucutes with least progress gets chronoed (providing have same queue size)
		bubbleSort2DArray(oStructureToChrono, "QueueSize", 0) ; so One with the longest queue gets chronoed first
	}
	
	If !oStructureToChrono.maxIndex()
		return
	
	MouseGetPos, start_x, start_y
	HighlightedGroup := getSelectionHighlightedGroup()
	max_chronod := nexus_chrono_count - CG_chrono_remainder
	MTsend("^" CG_control_group CG_nexus_Ctrlgroup_key)
	sleep, 10 	; Can use real sleep here as not a silent automation
	for  index, oject in oStructureToChrono
	{
		If (A_index > max_chronod)
			Break	
		
		sleep, %ChronoBoostSleep%
		getUnitMiniMapMousePos(oject.unit, click_x, click_y)
		MTsend(chrono_key)
		If HumanMouse
			MouseMoveHumanSC2("x" click_x "y" click_y "t" rand(HumanMouseTimeLo, HumanMouseTimeHi))
		MTclick(click_x, click_y)
	}
	If HumanMouse
		MouseMoveHumanSC2("x" start_x "y" start_y "t" rand(HumanMouseTimeLo, HumanMouseTimeHi))
	MTsend(CG_control_group)
	sleep, 10
	if HighlightedGroup
		MTsend(sRepeat(NextSubgroupKey, HighlightedGroup))
	Return 
}
AutoGroupIdle:
	AutoGroup(A_AutoGroup, AG_Delay)
	Return

Auto_Group:
	AutoGroup(A_AutoGroup, AG_Delay)
	Return

AutoGroup(byref A_AutoGroup, AGDelay = 0)
{ 	global GameIdentifier, aButtons
	static PrevSelectedUnits, SelctedTime
	Thread, NoTimers, true

	numGetUnitSelectionObject(oSelection)
	, SelectedTypes := oSelection.Types
	for index, Unit in oSelection.Units
	{
		type := unit.type				
		If !isOwnerLocal(Unit.owner)
		{
			 	WrongUnit := 1
				break
		}
		CurrentlySelected .= "," unit.UnitIndex
		found := 0
		For Player_Ctrl_Group, ID_List in A_AutoGroup	;check the array - player_ctrl_group = key 1,2,3 etc, ID_List is the value
		{
			if type in %ID_List%
			{
				found := 1
				If !InStr(CtrlList, type) ;ie not in it
				{
					CtrlType_i ++	;probably don't really need this count mechanism anymore
					CtrlList .= type "|"
					CtrlGroupSet .= Player_Ctrl_Group "|"						
				}
				If !isInControlGroup(Player_Ctrl_Group, unit.UnitIndex)  ; add to said ctrl group If not in group
					Player_Ctrl_GroupSet := Player_Ctrl_Group
				break		
			}				
		}
		if !found
		{
			WrongUnit := 1
			break
		}

	}
	if (CurrentlySelected <> PrevSelectedUnits || WrongUnit)
	{
		PrevSelectedUnits := CurrentlySelected
		SelctedTime := A_Tickcount
	}
	if (A_Tickcount - SelctedTime >= AGDelay) && oSelection.Count && !WrongUnit  && (CtrlType_i = SelectedTypes) && (Player_Ctrl_GroupSet <> "") && WinActive(GameIdentifier) && !isGamePaused() ; note <> "" as there is group 0! cant use " Player_Ctrl_GroupSet "
	{		
		Sort, CtrlGroupSet, D| N U			
		CtrlGroupSet := RTrim(CtrlGroupSet, "|")	
		Loop, Parse, CtrlGroupSet, |
			AG_Temp_count := A_Index	;this counts the number of different ctrl groups ie # 1's  and 2's etc - must be only 1
		If (AG_Temp_count = 1) && !isMenuOpen()
		&& !(getkeystate("Shift", "P") && getkeystate("Control", "P") && getkeystate("Alt", "P")
		&& getkeystate("LWin", "P") && getkeystate("RWin", "P")		
		&& getkeystate("LWin", "L") && getkeystate("RWin", "L")		
		&& getkeystate("Shift") && getkeystate("Control") && getkeystate("Alt")
		|| readModifierState() 
		|| MT_InputIdleTime() <= 30)

		;&& !getkeystate("LWin") && !getkeystate("RWin")
		;&& !(getkeystate("Shift", "P") || getkeystate("Control", "P") || getkeystate("Alt", "P")
		;|| getkeystate("LWin", "P") || getkeystate("RWin", "P")	
		;|| getkeystate("LButton", "P") || getkeystate("RButton", "P")
		;|| readModifierState() 
		;|| checkAllKeyStates() 
		;|| MT_InputIdleTime() <= 30)
		{
			;BufferInputFast.BufferInput()
			input.hookBlock(True, True)
			sleep := Input.releaseKeys()
			critical, 1000
			input.hookBlock(False, False)
			if sleep
				DllCall("Sleep", Uint, 15) ;  sleep, 5
			; if the user has a delay for grouping, this increases the risk of the unit selection changing before the
			; sent ctrl+group command is received/processed. Therefore a small sleep here should make it more robust
			; in theory this should not be required with a delay of 0 (for the most part), as there is the idle grouping
			; timer which is continually running (be it with a low priority) so as soon as the units/buffer change, it
			; will group them if required. And this should occur before anything help happens in game

			if AGDelay ; the MTDelay should prevent the need for a sleep
			{
				if !sleep 
					DllCall("Sleep", Uint, 3)
				;sleep 5 ; so rounds to no more than 10ms.
				;Sleep(2) ; give time for selection buffer to update. This along with blocking input should cover pre- and post-selection delay buffer changes
				numGetUnitSelectionObject(oSelection)
				for index, Unit in oSelection.Units
					PostDelaySelected .= "," unit.UnitIndex
			}
			if (!AGDelay || CurrentlySelected = PostDelaySelected)
			{
			;	send, +%Player_Ctrl_GroupSet%
				MTsend("+" Player_Ctrl_GroupSet)
				sleepOnExit := True
				settimer, AutoGroupIdle, Off
				settimer, Auto_Group, Off				
			}
			Input.revertKeyState()
			critical, off
		}

	}
	; could do something like only sleep check when agdelay > 0 or when time since last check > 1ms 

	Thread, NoTimers, false
	; someone said that the autogroup would make there camera jump to the building
	; probably due to slow computer and the program reading the unit hasn't been grouped and so 
	; sends the group command twice very quickly
	if sleepOnExit  
	{
		sleep 60
		settimer, AutoGroupIdle, On, -9999 ;on re-enables timers with previous period
		settimer, Auto_Group, On		
	}
	Return
}

g_LimitGrouping:
	LimitGroup(A_AutoGroup, A_ThisHotkey)
Return

LimitGroup(byref UnitList, Hotkey)
{ 
	; CtrlList := "" ;if unit type not in listt add to it - give count of list type
	group := substr(Hotkey, 0)
	If (ID_List := UnitList[group]) ; ie not blank
	{
		loop, % getSelectionCount()		;loop thru the units in the selection buffer
		{
			type := getUnitType(getSelectedUnitIndex(A_Index - 1)) 					;note no -1 (as ctrl index starts at 0)
			if type NOT in %ID_List%
				Return
		}
	}
	input.hookBlock(True, True)
	sleep := Input.releaseKeys()
	critical 1000
	input.hookBlock(False, False)
	if sleep
		DllCall("Sleep", Uint, 10) 
	MTsend(Hotkey)
	Input.revertKeyState()
	Return
}	

inject_start:
	if inject_timer
	{
		inject_timer := !inject_timer
		settimer, inject, off
		tSpeak("Inject off")
	}
	else
	{
		inject_set := time
		inject_timer := !inject_timer
		settimer, inject, 250
		tSpeak("Inject on")
	}
	return

inject_reset:
	inject_set := time
	settimer, inject, off
	settimer, inject, 250
	inject_timer := 1
	tSpeak("Reset")
	return

Cast_DisableInject:	
	If (F_Inject_Enable := !F_Inject_Enable)
	{
		tSpeak("Injects On")
		zergGetHatcheriesToInject(oHatcheries)
		settimer, cast_ForceInject, %FInjectHatchFrequency%	
	}
	Else
	{
		settimer, cast_ForceInject, off
		tSpeak("Injects Off")
	}
	Return




; As Im not accounting for mouse buttons (just want to see how well this works)
; make sure to check Mousebuttons are not down before calling releaseKeys()
; Same with Windows keys (as releasing these will cause the windows menu to appear) - although the automation
; may still work

; Note** Do not call releaseKeys() while thread is in critical! As the LL-Hooks wont process the input
; until the thread comes out of critical, or an AHK sleep command is used
; Also note, any AHK command which has an internal sleep (including eg controlsend) will cause AHK to check its msg queue
; and the hooks will then process any user pressed key which could interrupt the automation!

class Input 
{
	static keys := ["LControl", "RControl", "LAlt", "RAlt", "LShift", "RShift", "LWin", "RWin"
				, "AppsKey", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"
				, "Left", "Right", "Up", "Down", "Home", "End", "PgUp", "PgDn", "Del", "Ins", "BS", "Capslock", "Numlock", "PrintScreen" 
				, "Pause", "Space", "Enter", "Tab", "Esc", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "B", "C", "D", "E", "F", "G"
				, "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
	 	,	MouseButtons := ["LButton", "RButton", "MButton", "XButton1", "XButton2"]
		,	downSequence
		,	MouseBlocked := False
		,	KybdBlocked := False

	releaseKeys()
	{
		this.downSequence := ""
		SetFormat, IntegerFast, hex
		for index, key in this.keys 
			if GetKeyState(key) 	; check the logical state
				upsequence .= "{VK" GetKeyVK(key) " Up}", this.downSequence .= "{" key " Down}" 
		SetFormat, IntegerFast, d
		if upsequence
		{
			SendInput, {BLIND}%upsequence%
			return upsequence 	; This will indicate that we should sleep for 15ms (after activating critical)
		}	 					; to prevent out of order command sequence with sendinput vs. post message
		return 
	}

	revertKeyState()
	{
		if this.downSequence
			pSend(this.downSequence)
		return							
	}
	userInputModified()
	{
		return this.downSequence
	}

	pClickDelay(newDelay := "")
	{
		static clickDelay := -1
		if newDelay is number
			clickDelay := newDelay
		return clickDelay
	}

	pSendDelay(newDelay := "")
	{
		static SendDelay := -1
		if newDelay is number 
			SendDelay := newDelay
		return SendDelay
	}	
	hookBlock(kybd := False, mouse := False)
	{
		this.KybdBlocked := kybd
		this.MouseBlocked := mouse
		return
	}
	iskeyboardBlocked()
	{
		return this.KybdBlocked
	}
	isMouseBlocked()
	{
		return this.KybdBlocked 
	}
}

;	5/9/13
;	Now using postMessage to send clicks. Note, not going to block or revert key states for the user invoked
;	one-button inject. As Users may have really high internal sleep times which could cause the installed hooks to 
; 	be removed by windows. Also, since the user is invoking this action, they shouldnt be pressing any other keys anyway.
;	also using AHK internal sleep for this function.

cast_inject:
	If (isGamePaused() || isMenuOpen())
		return ;as let the timer continue to check during auto injects
		;menu is always 1 regardless if chat is up
		;chat is 0 when  menu is in focus
	Thread, NoTimers, true  ;cant use critical with input buffer, as prevents hotkey threads launching and hence tracking input				
	MouseGetPos, start_x, start_y
	BufferInputFast.BlockInput()
	castInjectLarva(auto_inject, 0, auto_inject_sleep) ;ie nomral injectmethod
	If HumanMouse
		MouseMoveHumanSC2("x" start_x "y" start_y "t" HumanMouseTimeLo)
	BufferInputFast.disableBufferingAndBlocking()
	Thread, NoTimers, false
	inject_set := getTime()  
	if auto_inject_alert
		settimer, auto_inject, 250
	If GetKeyState(cast_inject_key, "P")
		KeyWait, %cast_inject_key%, T.25	; have to have this short, as sometimes the script sees this key as down when its NOT and so waits for the entire time for it to be let go - so if a user presses  this key multiple times to inject (as hatches arent ready) some of those presses will be ingnored
Return


cast_ForceInject:
	if !F_Inject_Enable
	{
		settimer, cast_ForceInject, off	
		return 
	}
	;For Index, CurrentHatch in oHatcheries
	;	if (CurrentHatch.NearbyQueen && !isHatchInjected(CurrentHatch.Unit)) ;probably should check if hatch is alive and still a hatch...

	If getGroupedQueensWhichCanInject(aControlGroup, 1) ; 1 so it checks their movestate
	{
		For Index, CurrentHatch in oHatcheries
			For Index, Queen in aControlGroup.Queens
				if (isQueenNearHatch(Queen, CurrentHatch, MI_QueenDistance) && Queen.Energy >= 25  && !isHatchInjected(CurrentHatch.Unit)) 
				{
					sleep % rand(0, 1000)	
					startInjectWait := A_TickCount
					while getkeystate("LWin", "P") || getkeystate("RWin", "P")	
					|| getkeystate("LWin") || getkeystate("RWin")	
					|| getkeystate("LButton", "P") || getkeystate("RButton", "P")
					|| getkeystate("LButton") || getkeystate("RButton")
					|| getkeystate("Shift") || getkeystate("Ctrl") || getkeystate("Alt")
					|| getkeystate("Shift", "P") || getkeystate("Ctrl", "P") || getkeystate("Alt", "P")	
					|| getkeystate("Enter") ; required so chat box doesnt get reopened when user presses enter to close the chatbox
					|| isUserPerformingAction()
					|| MT_InputIdleTime() < 50  ;probably best to leave this in, as every now and then the next command wont be shift modified
					|| getPlayerCurrentAPM() > FInjectAPMProtection
					{
						if (A_TickCount - startInjectWait > 650)
							return
						sleep 1
					}
					if (!WinActive(GameIdentifier) || isGamePaused() || isMenuOpen() || !isSelectionGroupable(oSelection)) 
						return
					input.hookBlock(True, True)
					Sleep := Input.releaseKeys()
					critical 1000
					input.hookBlock(False, False)
					if sleep
						DllCall("Sleep", Uint, 15) ;  sleep, 5
					else DllCall("Sleep", Uint, 2) ; give 2 ms to allow for selection buffer to fully update so we are extra safe. 
					if isSelectionGroupable(oSelection) ; in case it somehow changed/updated 
						castInjectLarva("MiniMap", 1, 0)	
					Input.revertKeyState()						
					return
				}
	}
	return


/* ; Shouldnt need this anymore
	
	;should probably add a blockinput for the burrow check
	if (getBurrowedQueenCountInControlGroup(MI_Queen_Group, UnburrowedQueenCount) > 1)
	{
		TooManyBurrowedQueens := 1
		SetKeyDelay, %EventKeyDelay%	;this only affects send events - so can just have it, dont have to set delay to original as its only changed for current thread
		SetMouseDelay, %EventKeyDelay%	;again, this wont affect send click (when input/play is in use) - I think some other commands may be affected?
	;	ReleaseModifiers(0, 1, HotkeysZergBurrow)
		ReleaseModifiers(0, 1, HotkeysZergBurrow, True, False, 40) ; check all keys
		Thread, NoTimers, true  ;cant use critical with input buffer, as prevents hotkey threads launching and hence tracking input

		sendSequence := "^" Inject_control_group MI_Queen_Group		
		if UnburrowedQueenCount
			sendSequence .= NextSubgroupKey ; sleep(2) ; After restoring a control group, needs at least 1 ms so tabs will register
	
		sendSequence .= HotkeysZergBurrow Inject_control_group
		MTsend(sendSequence)
		TooManyBurrowedQueens := 0
		Thread, NoTimers, false
	}
	else TooManyBurrowedQueens := 0
*/
 

getBurrowedQueenCountInControlGroup(Group, ByRef UnburrowedCount="")
{	GLOBAL aUnitID
	UnburrowedCount := BurrowedCount := 0
	numGetControlGroupObject(oControlGroup, Group)
	for index, unit in oControlGroup.units
		if (unit.type = aUnitID.QueenBurrowed)
			BurrowedCount ++
		else if (unit.type = aUnitID.Queen)
			UnburrowedCount++
	return BurrowedCount
}

getCurrentlyHighlightedUnitType(ByRef SampleTargetFilter="")
{
;	PreviousCritical := A_IsCritical 	

	Thread, NoTimers, true 	;shouldn't use critical here, incase i'm trying to track user input
;	critical, on ;otherwise takes too long! still takes a a bit of time for lots of selected units! 16ms for 295 and 63ms for 540 supply selected units when sorting them

	CurrentGroup := -1 ; so 1st timein for loop != ++ will be 0
	if numGetUnitSelectionObject(oSelection, "Sort") ; returns selection count
		for index, Unit in oSelection.Units
		{
			if (unit.type != previousType)
			{
				CurrentGroup++	
				previousType := unit.type
				if (CurrentGroup = oSelection.HighlightedGroup)
				{
					SampleTargetFilter := getUnitTargetFilterFast(unit.UnitIndex) ; so can be used as a basic test of unit type eg is it a structure
					return Unit.Type
				}
			}
		}
	Return 0 ;either error or no units selected
}

;not sure if this works
findunitTypeTabPosition(l_searchType, ByRef SampleTargetFilter="") ; l_searchType a commo delimited list
{
;	PreviousCritical := A_IsCritical
;	critical, on ;otherwise takes too long! still takes a a bit of time for lots of selected units! 16ms for 295 and 63ms for 540 supply selected units when sorting them
	Thread, NoTimers, true 	;shouldn't use critical here, incase i'm trying to track user input
	CurrentGroup := -1 ; so 1st timein for loop != ++ will be 0
	if numGetUnitSelectionObject(oSelection, "Sort") ; returns selection count
		for index, Unit in oSelection.Units
		{
			if (unit.type != previousType)
			{
				CurrentGroup++	
				previousType := unit.type
				type := unit.type
				if type in %l_searchType%
				{
					SampleTargetFilter := getUnitTargetFilterFast(unit.UnitIndex) ; so can be used as a basic test of unit type eg is it a structure
					return CurrentGroup
				}
			}
		}
	Return 0 ;either error or no units selected
}


isUserPerformingAction()
{	GLOBAL
;	Local Type, worker
;	type := getCurrentlyHighlightedUnitType()
;	if aUnitTargetFilter.Structure & TargetFilter
;		return 0 ; as it's a building and the user cant really be doing anything - perhaps set rally point for hatches via 'y'... Dont need to do this anymore
;	If (aLocalPlayer["Race"] = "Terran")
;		worker := "SCV"	
;	Else If (aLocalPlayer["Race"] = "Protoss")
;		worker := "Probe"
;	Else Worker := "Drone"

;	if ( type = aUnitID[Worker] && isUserBusyBuilding() )  || IsUserMovingCamera() || IsMouseButtonActive() ; so it wont do anything if user is holding down a mousebutton! eg dragboxing

	if ( isUserBusyBuilding() || IsUserMovingCamera() || IsMouseButtonActive() 	; so it wont do anything if user is holding down a mousebutton! eg dragboxing
	||  pointer(GameIdentifier, P_IsUserPerformingAction, O1_IsUserPerformingAction) ) ; this gives 256 when reticle/cast cursor is present
		return 1
	else return 0
}

isUserPerformingActionIgnoringCamera()
{	GLOBAL
	if ( isUserBusyBuilding() || IsMouseButtonActive() 	; so it wont do anything if user is holding down a mousebutton! eg dragboxing
	||  pointer(GameIdentifier, P_IsUserPerformingAction, O1_IsUserPerformingAction) ) ; this gives 256 when reticle/cast cursor is present
		return 1
	else return 0
}

; this gives 256 when reticle/casting cursor is present (includes attacking)
isCastingReticleActive()
{	GLOBAL
	return pointer(GameIdentifier, P_IsUserPerformingAction, O1_IsUserPerformingAction)
}


; for the second old pointer
; This will return 1 if the basic or advanced building selection card is up (even if all structures greyed out)
; This will also return 1 when user is trying to place the structure
isUserBusyBuilding()	
{ 	GLOBAL
	; if 6, it means that either the basic or advanced build cards are displayed - even if all are greyed out (and hence a worker is selected) - give 1 for most other units, but gives 7 for targeting reticle
	if ( 6 = pointer(GameIdentifier, P_IsBuildCardDisplayed, 01_IsBuildCardDisplayed, 02_IsBuildCardDisplayed, 03_IsBuildCardDisplayed)) 
		return 1 ; as it seems 6 is only displayed when the worker build cards are up, so don't need to double check with below pointer
	;	return pointer(GameIdentifier, P_IsUserBuildingWithWorker, 01_IsUserBuildingWithWorker, 02_IsUserBuildingWithWorker, 03_IsUserBuildingWithWorker, 04_IsUserBuildingWithWorker)
	else return 0
}
	



;----------------------
;	Auto Mine
;-----------------------	
Auto_mine:
If (time AND Time <= Start_Mine_Time + 8) && getIdleWorkers()
	{
		Settimer, Auto_mine, Off
		IF (A_ScreenWidth <> 1920) OR (A_ScreenHeight <> 1080)
			AutoMineMethod := "MiniMap"
		ReleaseModifiers()
	;	BlockInput, On
		A_Bad_patches := []
		A_Bad_patchesPatchCount := 0
		local_mineral_list := local_minerals(LocalBase, "Distance")	;Get list of local minerals	
		MouseMove A_ScreenWidth/2, A_ScreenHeight/2
		if !WinActive(GameIdentifier)
		{	WinNotActiveAtStart := 1
			WinActivate, %GameIdentifier%
			sleep 1500 ; give time for slower computers to make sc2 window 'truely' active
			DestroyOverlays()
			ReDrawMiniMap := ReDrawIncome := ReDrawResources := ReDrawArmySize := ReDrawWorker := RedrawUnit := 1
		}
		Gosub overlay_timer	; here so can update the overlays
		If (DrawMiniMap OR DrawAlerts OR DrawSpawningRaces)
			DrawMiniMap()
		sleep 300
		Critical 
		If (Auto_mineMakeWorker && SelectHomeMain(LocalBase))	
			MakeWorker(aLocalPlayer["Race"])
		While (Start_Mine_Time > time := GetTime())
		{	sleep 140
			while (time = GetTime())	;opponent left game
			{	sleep 100
				if (A_index >= 10)	;game has been paused/victory screen for 1 second 
				{ 	BlockInput, Off
					Return
				}	
			}
		}
		While (GetTime() <= (Start_Mine_Time + 8) OR !A_IsCompiled) ; As if only hitting one patch, cant take more that 6 to get all minning
			if (AutoMineMethod = "MiniMap" || A_ScreenWidth <> 1920 || A_ScreenHeight <> 1080)
			{	
				if castAutoSmartMineMiniMap(local_mineral_list, AM_PixelColour, AM_MiniMap_PixelVariance/100)
					break
			}
			else 
				if castAutoMineBMap(local_mineral_list, A_Bad_patches)
					break	
		sleep 100
		Send, %escape% ; deselect gather mineral
		IF  (Auto_Mine_Set_CtrlGroup && SelectHomeMain(LocalBase))
			Send, ^%Base_Control_Group_Key%
		If (A_ScreenWidth = 1920 && A_ScreenHeight = 1080)
		{
			local_mineral_list := SortUnitsByMapOrder(local_mineral_list)	;list the patches from left to right OR up to down 
			local_mineral_list := SortByMedian(local_mineral_list) 			;converts the above list so 
			loop, parse, local_mineral_list, | 								;the patches are from middle to outer 
			{																;this trys to rally the worker to aprox middle of the field/mineral line
				if !Bad_patches[A_LoopField, "Error"]
				{	
					Get_Bmap_pixel(A_LoopField, click_x, click_y)
					send {click Left %click_x%, %click_y%}	
					sleep, % Auto_Mine_Sleep2/2 ;seems to need 1 ms
					If (getSelectionCount() = 1) AND (getSelectionType(0) = 253) 
					{
						SelectHomeMain(LocalBase)
						send {click Right %click_x%, %click_y%}	
						break
					}
				}
			}
		}
		BlockInput, Off
		Critical Off		
	}
	Else If (Time >= Start_Mine_Time + 10) ; kill the timer if problem - done this way incase timer interupt and change time
		Settimer, Auto_mine, Off
Return	

SelectHomeMain(LocalBase)		
{	global	base_camera, aUnitID
	If (getSelectionCount() = 1) &&	((unit := getSelectionType(0)) = aUnitID["CommandCenter"] || Unit = aUnitID["Nexus"] || Unit = aUnitID["Hatchery"])
		return 1		
	else if (A_ScreenWidth = 1920 && A_ScreenHeight = 1080 && !Get_Bmap_pixel(LocalBase, click_x_base, click_y_base))
		send {click Left %click_x_base%, %click_y_base%}
	else 
	{
		mousemove, (X_MidScreen := A_ScreenWidth/2), (Y_MidScreen := A_ScreenHeight/2), 0 ; so the mouse cant move by pushing edge of screen 
		SendBaseCam()		
		send {click Left %X_MidScreen%, %Y_MidScreen%}
	}
	sleep 100 ; Need some time to update selection
	If (getSelectionCount() = 1) &&	((unit := getSelectionType(0)) = 48 || Unit = 90 || Unit = 117)
		return 1
	else return 0
}

MakeWorker(Race = "")
{ 	global
	if !Race
		Race := aLocalPlayer["Race"]
	If ( Race = "Terran" )
		Send, %Make_Worker_T_Key%
	Else If ( Race = "Protoss" )
		Send, %Make_Worker_P_Key%
	Else If ( Race = "Zerg" )
		Send, %Make_Worker_Z1_Key%%Make_Worker_Z2_Key%
}

SplitWorkers(Type="")
{ 	global
	if (Type = "2x3")
		Send, %Idle_Worker_Key%+%Idle_Worker_Key%+%Idle_Worker_Key%%Gather_Minerals_key%
	else if (Type = "3x2")
		Send, %Idle_Worker_Key%+%Idle_Worker_Key%%Gather_Minerals_key%
	else if (Type = "6x1")
		Send, %Idle_Worker_Key%%Gather_Minerals_key%	
	else ;select all of them
		Send, ^%Idle_Worker_Key%%Gather_Minerals_key%
}
SendBaseCam(sleep=120, blocked=1)
{ global
;	if blocked
;		send % base_camera
	send, %base_camera%
	sleep, %sleep%	; needs ~70ms to update camera
}
SortByMedian(List, Delimiter = "|", Sort = 0)		;This is used to list the mineral patches
{													; starting at the center and Working outwards
	if Sort
		Sort, list, D%Delimiter% N U
	StringSplit, Array, List, %Delimiter%		; this array isn't a real object :(
	n := Array0, MedianVal :=  round(.5*(n+1))
	Result :=  Array%MedianVal% "|"
	loop, % n
	{
		If ((HiIndex := MedianVal + A_index) <= n)
			Result .= Array%HiIndex% "|"
		If ((LoIndex := MedianVal - A_index) > 0)	;0 stores array count (hence > and not >=)
			Result .= Array%LoIndex% "|"
	}
	 return RTrim(Result, "|")
}

castAutoMineBMap(MineralList, byref A_BadPatches, Delimiter = "|") ;normal/main view/bigmap
{	global Auto_Mine_Sleep2, WorkerSplitType
	while (A_index < 4)	;just adds another safety net
		loop, parse, MineralList, %Delimiter% 
		{
			If (!(IdlePrev_i:=getIdleWorkers())) OR (BadPatches_i >= 8) 
				return 1
			If A_BadPatches[A_LoopField, "Error"]
				Continue	;hence skipping the bogus Click location	
			if !Get_Bmap_pixel(A_LoopField, click_x, click_y) || (!BasecamSent_i && (BasecamSent_i := SendBaseCam()) && !Get_Bmap_pixel(A_LoopField, click_x, click_y))
			{	;Get_Bmap_pixel returns 1 if x,y is on edge of screen --> move screen
				send {click Left %click_x%, %click_y%}		
				sleep, % Auto_Mine_Sleep2/2 ;seems to need 1 ms to update
				If (getSelectionCount() = 1) AND (getSelectionType(0) = 253) ;mineral field
				{	
					SplitWorkers(WorkerSplitType)
					Send, {click Left %click_x%, %click_y%}
					sleep, % Auto_Mine_Sleep2/2
					If getIdleWorkers() < IdlePrev_i
						continue
				}
			}
			A_BadPatches[A_LoopField, "Error"] := 1
			BadPatches_i ++
		}
	return 1
}
castAutoSmartMineMiniMap(MineralList, PixelColour, PixelVariance = 0, Delimiter = "|")	
{	global WorkerSplitType, Auto_Mine_Sleep2		; but the minimap inaccuray + the small mineral patches makes it difficult on some maps
	CoordMode, Mouse, Screen
	A_BadPatches := []	;keep this local variable, else it will affect the rally point which is done via normal view/big map
	RandMod := 1
	while (A_index < 8)	;just adds another safety net - as if only hitting one patch, with 1 worker per turn - max turns required = 6
	{
		OuterIndex := A_Index
		loop, parse, MineralList, %Delimiter% 
		{
			If (!(IdlePrev_i:=getIdleWorkers()))
			{	
				CoordMode, Mouse, Window 
				return 1	;return no idle workers
			}
			If (A_BadPatches[A_LoopField, "Error"] && OuterIndex >6 )
			{
				A_BadPatches[A_LoopField, "Error"] := ""		; this just helps increase the +/- random factor  
				RandMod := 2				; to help find a patch if the first goes have been bad
			}	
			If A_BadPatches[A_LoopField, "Error"]
				Continue
			if (OuterIndex > 5 && !selectedall)
			{
					selectedall := 1
					SplitWorkers() ; this select all of them just once
			}
			else 		
				 SplitWorkers(WorkerSplitType)
			sleep,  Auto_Mine_Sleep2 * .30		;due to game startup lag somtimes camera gets moved around. This might help?
			while (A_index < 3)
			{			
				getUnitMiniMapMousePos(A_LoopField, X, Y)
				if !PixelSearch(PixelColour, X, Y, PixelVariance, A_index*RandMod, A_index*RandMod)
					continue
			;	msgbox % "Patch:" A_LoopField "`n" "x,y:" x ", " y "`n" "loop: " A_index "`n" "Bad x,y:" A_BadPatches[A_LoopField, "X"] ", " A_BadPatches[A_LoopField, "Y"] "`nXRand:" XRand ", " YRand
				send {click Left %X%, %Y%}
				sleep,  Auto_Mine_Sleep2	; needs ~25 ms to update idle workers else it will move camera via left - but more online due to startup lag
				if (getIdleWorkers() < IdlePrev_i)	; clicking minimap without the 'gather minerals' state being active				
					continue, 2									; we cant try the offset before the random	
			}
			A_BadPatches[A_LoopField, "Error"] := 1
		}
	}
	CoordMode, Mouse, Window 
	return 1
}

PixelSearch(Colour, byref X, byref Y,variance=0, X_Margin=6, Y_Margin=6)
{	;supply the approx location via X & Y. Then pixel is returned
	pBitMap := GDIP_BitmapFromScreen()		;im not sure if i have to worry about converting coord mode here
	Gdip_FromARGB(Colour, A, R, G, B)		;i dont belive so, as it should all be relative
	X_Max := X+X_Margin, Y_Max := Y+Y_Margin
	while ((X := X-X_Margin+A_Index-1) <= X_Max)
		while ((Y := Y-Y_Margin+A_Index-1) <= Y_Max)			
			if	((found := !Gdip_FromARGB(GDIP_GetPixel(pbitmap, X, Y), FA, FR, FG, FB) ;Gdip_FromARGB doesnt return a value hence !
			&& (FA >= A - A*variance && FA <= A + A*variance)
			&& (FR >= R - R*variance && FR <= R + R*variance)
			&& (FG >= G - G*variance && FG <= G + G*variance)
			&& (FB >= B - B*variance && FB <= B + B*variance)))
				break, 2
	GDIP_DisposeImage(pBitMap)
	if found
		return 1
	else return 0
}



;----------------------
;	races
;-----------------------
find_races_timer:
If (time < 8)
	Return
SetTimer, find_races_timer, off		

find_races:
If (A_ThisLabel = "find_races")
	TimeReadRacesSet := time
if !time	;leave this in, so if they press the hotkey whileoutside of game, wont get gibberish
	return
Else EnemyRaces := GetEnemyRaces()
if (race_clipboard && WinActive(GameIdentifier))
	clipboard := EnemyRaces
if race_speech
	tSpeak(EnemyRaces)
return

;--------------------------------------------
;    Minerals -------------
;--------------------------------------------
money:
	if (mineraltrigger <= getPlayerMinerals())
	{
			if (Mineral_i <= sec_mineral)	; sec_mineral sets how many times the alert should be read
			{
				tSpeak(w_mineral)
				settimer, money, % additional_delay_minerals *1000	; will give the second warning after additional seconds
			}
			else 	; this ensures follow up warnings are not delayed by waiting for additional seconds before running timmer
				settimer, money, 500
			Mineral_i ++
	}
	else
	{
		Mineral_i = 0
		settimer, money, 500
	}
return

;--------------------------------------------
;    Gas -------------
;--------------------------------------------
gas:	
	if (gas_trigger <= getPlayerGas())
	{
			if (Gas_i <= sec_gas)	; sec_mineral sets how many times the alert should be read
			{
				tSpeak(w_gas)
				settimer, gas, % additional_delay_gas *1000	; will give the second warning after additional seconds
			}
			if (Gas_i >= sec_gas )
				settimer, gas, 1000
			Gas_i ++
	}
	else
	{
		Gas_i = 0
		settimer, gas, 1000
	}
return				


;--------------------------------------------
;    worker production -------------
;--------------------------------------------
worker:	
	If (aLocalPlayer["Race"] = "Terran" || aLocalPlayer["Race"] = "Protoss")
		WorkerInProductionWarning(a_BaseList, workerProductionTPIdle, 1 + sec_workerprod, additional_delay_worker_production, 120)
	else
	{
		if ( OldWorker_i <> NewWorker_i := getPlayerWorkerCount())
		{	;A worker has been produced or killed
			reset_worker_time := time, Worker_i = 0
			workerproduction_time_if := workerproduction_time
		}
		else
		{ 
			if  (time - reset_worker_time) > workerproduction_time_if AND (Worker_i <= sec_workerprod) ; sec_workerprod sets how many times to play warning.
			{
				If ( aLocalPlayer["Race"] = "Terran"  )
					tSpeak(w_workerprod_T)
				Else If ( aLocalPlayer["Race"] = "Protoss" )
					tSpeak(w_workerprod_P)
				Else If ( aLocalPlayer["Race"] = "Zerg" )
					tSpeak(w_workerprod_Z)
				Else 
					tSpeak("Build Worker")
				workerproduction_time_if := additional_delay_worker_production ; will give the second warning after 12 ingame seconds
				reset_worker_time := time		; This allows for the additional warnings to be delayed relative to the 1st warning
				Worker_i ++
			}
		}
		 OldWorker_i := NewWorker_i
	}
	return

WorkerInProductionWarning(a_BaseList, maxIdleTime, maxWarnings, folloupWarningDelay, MaxWorkerCount)	;add secondary delay and max workers
{	global aLocalPlayer, w_workerprod_T, w_workerprod_P, w_workerprod_Z
	static lastWorkerInProduction, warningCount, lastwarning

	if (getPlayerWorkerCount() >= MaxWorkerCount)	;stop warnings enough workers
		return

	time := getTime()
	for index, Base in a_BaseList
	{

		if (state := isWorkerInProduction(Base))
		{
			warningCount := 0
			lastWorkerInProduction := time
			return
		}
		else if (state < 0)
			morphingBases++
		else lazyBases++	;hence will only warn if there are no workers in production
							; and at least 1 building is capable of making workers i.e not flying/moring
	}
	if !lazyBases && morphingBases
		lastWorkerInProduction := time	;this prevents you getting a warning immeditely after the base finishes morphing

	if lazybases && (time - lastWorkerInProduction >= maxIdleTime) && ( warningCount < maxWarnings)
	{
		if (warningCount && time - lastwarning < folloupWarningDelay)
			return
		lastwarning := time
		warningCount++
		If ( aLocalPlayer["Race"] = "Terran" )
			tSpeak(w_workerprod_T)
		Else If ( aLocalPlayer["Race"] = "Protoss" )
			tSpeak(w_workerprod_P)
		Else If ( aLocalPlayer["Race"] = "Zerg" )
			tSpeak(w_workerprod_Z)
		Else 
			tSpeak("Build Worker")	;dont update the idle time so it gets bigger
	}
	return 
}
;--------------------------------------------
;    suply -------------
;--------------------------------------------

supply:
	sup:= getPlayerSupply(), SupCap := getPlayerSupplyCap() ; Returns 0 when memory returns Fail
	if  ( !sup or sup < minimum_supply )  		;this prevents the onetime speaking before a value has been read for sup - Note 0 instead of fail due to math procedures above
		return 
	Else If ( sup < supplylower )
		trigger := sub_lowerdelta
	Else If ( sup >= supplylower AND sup < supplymid )	
		trigger := sub_middelta
	Else If ( sup >= supplymid AND sup < supplyupper )	
		trigger := sub_upperdelta
	Else if ( sup >= supplyupper )
		trigger := above_upperdelta
	if ( ( sup + trigger ) >= supcap AND supcap < 200 And !SupplyInProduction)	
	{
									; <= sec_supply, as this includes the 1st primary warning
		if (Supply_i <= sec_supply )  ; sec_supply sets how many times alert will be played it should be counted.
		{
			tSpeak(w_supply)	;this is the supply warning
			settimer, supply, % additional_delay_supply *1000
		}
		Else	; this ensures follow up warnings are not delayed by waiting for additional seconds before running timmer
			settimer, supply, 200
		Supply_i ++	
	}
	else
	{
		Supply_i = 0 	; reset alert count
		settimer, supply, 200
	}
return


;-------
; scv idle
;-------

scvidle:
	if ( time < 5 ) OR ("Fail" = idle_count := getIdleWorkers())
		return
	if ( idle_count >= idletrigger )
	{
		if (Idle_i <= sec_idle )
		{
			tSpeak(w_idle)
			settimer, scvidle, % additional_idle_workers *1000
		}
		Else
			settimer, scvidle, 500
		Idle_i ++
	}
	else
	{
		Idle_i = 0
		settimer, scvidle, 500
	}
	return

;------------
;	Inject	Timers
;------------
inject:
	if ( time - inject_set >= manual_inject_time )		;for manual dumb inject alarm  (i.e. dings every X seconds)
	{
		inject_timer := 1
		inject_set:=time

		If W_inject_ding_on
			SoundPlay, %A_Temp%\Windows Ding.wav  ;SoundPlay *-1
		If W_inject_speech_on
			tSpeak(w_inject_spoken)	
	}		
	return

; This is for the One-Button Injects (not the fully automated injects)

auto_inject:
	if ( time - inject_set >= auto_inject_time ) && (!F_Inject_Enable)
	{
		settimer, auto_inject, off
		If W_inject_ding_on
			loop, 2
			{
				SoundPlay, %A_Temp%\Windows Ding.wav  ;SoundPlay *-1
				sleep 150
			}	
		If W_inject_speech_on
			tSpeak(w_inject_spoken)
	}
	return

Return
	
;----------------
;	User Idle
;----------------
user_idle:
; If only one hook is installed, only its type of physical input affects A_TimeIdlePhysical (the other/non-installed hook's input, both physical and artificial, has no effect).
	time := getTime()
	If ( time > UserIdle_LoLimit AND time < UserIdle_HiLimit) AND  (A_TimeIdlePhysical > idle_time *1000)	;
	{	
		settimer, user_idle, off
		pause_check := getTime()
		sleep, 500			
		if ( pause_check = getTime())
			return	; the game is already paused		
		send, +{enter}%chat_text%{enter} 
		Send, %pause_game%
	}
	Else If ( time > 10 )
		settimer, user_idle, off	
return

;------------
;	Worker Count
;------------
worker_count:
	worker_origin := A_ThisHotkey ; so a_hotkey notchanged via thread interuption
	IF 	( !time ) ; ie = 0 
	{
		tSpeak("The game has not started")
		return
	}
	If ( worker_origin = worker_count_enemy_key)
	{
		if ( GameType <> "1v1" )
		{
			tSpeak("Enemy worker count is only available in 1v1")
			return
		}	
		For slot_number in aPlayer
		{
			If ( aLocalPlayer["Team"] <> aPlayer[slot_number, "Team"] )
			{
				playernumber := slot_number	
				player_race := aPlayer[slot_number, "Race"]
				Break
			}
		}
	}
	Else
	{
		playernumber := aLocalPlayer["Slot"]
		player_race := 	aLocalPlayer["Race"]
	}
	if ( "Fail" = newcount := getPlayerWorkerCount(playernumber))
	{
		tSpeak("Try Again in a few seconds")
		return
	}
	Else If ( player_race = "Terran" )
		tSpeak(newcount "SCVs")
	Else If ( player_race = "Protoss" )
		tSpeak(newcount "Probes")
	Else If ( player_race = "Zerg" )
		tSpeak(newcount "Drones")
	Else 
		tSpeak(newcount "Workers")
return	

;--------------------
;	WarpGate Warning
;--------------------

;	I think the problem here is if a user converts a warpate while the timer isnt running and then another warpgate finishes
;	it will rewarn the user even though it hasn't really waited the correct amount of time
;  also remeber that it only updates gateway/warpgate count after doing a unit bank read /iteration

; note: wargate warning only drawn for a set amount of time as the 'time' is only read in once in the unit bank section - so if user has a long follow up delay, that wont be accompanied by a minimap alert

warpgate_warn:
	if  (warpgate_status != "researched")
		return
	if gateway_count  ; this prvents the minmap warning showing converted gateways until they naturally time out in the drawing section
		for index, object in aGatewayWarnings
			if ( getUnitType(object.unit) != aUnitID["Gateway"] || isUnitDead(object.unit) || !isUnitLocallyOwned(object.unit) ) ;doing this in case unit dies or becomes other players gateway as this list onyl gets cleared when gateway count = 0
			{
				for minimapIndex, minimapObject in MiniMapWarning
					if (minimapObject.unit = object.unit)
					{
						MiniMapWarning.remove(minimapIndex, "") 
						break
					}
				aGatewayWarnings.remove(index, "") ; "" so deleting doesnt stuff up for loop		
			}

	if (gateway_count AND !warpgate_warning_set)
	{
		warpgateGiveWarningAt := getTime() + delay_warpgate_warn
		warpgate_warning_set := 1
	}
	else if ( !gateway_count  )
	{
		warpgate_warn_count := 0
		warpgate_warning_set := 0

		for index, object in aGatewayWarnings
			for minimapIndex, minimapObject in MiniMapWarning
				if (minimapObject.unit = object.unit)
					minimapObject.remove(minimapIndex, "")        ;lets clear the list of old gateway warnings. This gets rid of the x as soon as the gateway becomes a warpgate
		aGatewayWarnings := []

	}
	else if ( warpgate_warn_count <= sec_warpgate && time > warpgateGiveWarningAt) 
	{
		warpgate_warn_count ++
		warpgateGiveWarningAt := getTime() + delay_warpgate_warn_followup

		for index, object in aGatewayWarnings
		{
			object.time := time ; so this will display an x even with long  follow up delay
			MiniMapWarning.insert(object)
		}

		if aGatewayWarnings.maxindex()
			tSpeak(w_warpgate)	
	}

return

;------------------
;	Unit Bank Read	; I wrote this when I was first startings. I should really clean it up, but I cant be fucked.
;------------------
unit_bank_read:
SupplyInProductionCount := gateway_count := warpgate_count := 0
a_BaseListTmp := []
UnitBankCount := DumpUnitMemory(UBMemDump)
while (A_Index <= UnitBankCount)
{
	u_iteration := A_Index -1

	pUnitModel := numgetUnitModelPointer(UBMemDump, u_iteration)

	unit_type := numgetUnitModelType(pUnitModel)
	unit_owner := numgetUnitOwner(UBMemDump, u_iteration) 
	Filter := numgetUnitTargetFilter(UBMemDump, u_iteration)
	; unit_HP := MAXHP - sustained dmg
	; unit_HP := (ReadMemory((( ReadMemory(B_uStructure + ((A_Index - 1) * S_uStructure) + O_uModelPointer,"StarCraft II") << 5) & 0xFFFFFFFF) + u_MaxHP_Off,"StarCraft II") /4096) - (ReadMemory(B_uStructure + ((A_Index - 1) * S_uStructure) + 0x10C,"StarCraft II")/4096)

	If (Filter & DeadFilterFlag)
		Continue
	if (unit_owner = aLocalPlayer["Slot"])
	{
		IF (unit_type = supplytype AND Filter & aUnitTargetFilter.UnderConstruction)
				SupplyInProductionCount ++		
		if ( warpgate_warn_on AND (unit_type = aUnitID["Gateway"] OR unit_type = aUnitID["WarpGate"]) 
			AND !(Filter & aUnitTargetFilter.UnderConstruction))
		{
			if ( unit_type = aUnitID["Gateway"]) 
			{
				gateway_count ++	
				if warpgate_warning_set
				{
					isinlist := 0
					For index in aGatewayWarnings
					{
						if aGatewayWarnings[index,"Unit"] = u_iteration
						{	isinlist := 1
							Break
						}		
					}
					if !isinlist
						aGatewayWarnings.insert({"Unit": u_iteration, "Time": Time})
				} 
			}
			Else if (unit_type = aUnitID["WarpGate"] && warpgate_status <> "researched") ; as unit_type must = warpgate_id
			{
				warpgate_status := "researched"
			;	settimer warpgate_warn, 1000
			}
		}
		if (unit_type = aUnitID["Nexus"] || unit_type = aUnitID["CommandCenter"] 
		|| unit_type =  aUnitID["PlanetaryFortress"] || unit_type =  aUnitID["OrbitalCommand"])
		&&  !(Filter & aUnitTargetFilter.UnderConstruction)
			a_BaseListTmp.insert(u_iteration)
	}
	else if (alert_array[GameType, "Enabled"] && aPlayer[unit_owner, "Team"] <> aLocalPlayer["Team"])	
		doUnitDetection(u_iteration, unit_type, unit_owner)
} ; While ((UnitRead_i + EndCount) / getUnitCount() < 1.1)
if warpgate_warn_on
	gosub warpgate_warn
SupplyInProduction := SupplyInProductionCount
a_BaseList := a_BaseListTmp
return


doUnitDetection(unit, type, owner, mode = "")
{	global 
	static Alert_TimedOut := [], Alerted_Buildings := [], Alerted_Buildings_Base := []
	static l_WarningArrays := "Alert_TimedOut,Alerted_Buildings,Alerted_Buildings_Base"
	if (Mode = "Reset")
	{
		Alert_TimedOut := [],, Alerted_Buildings := [], Alerted_Buildings_Base := []
		return
	}
	else If (Mode = "Save")
	{

		loop, parse, l_WarningArrays, `,
		{
			For index, Object in %A_loopfield%
			{
				if (A_index <> 1)
					l_AlertShutdown .= ","
				if (A_loopfield = "Alert_TimedOut")
					For PlayerNumber, object2 in Object	;index = player name
						For Alert, warned_base in Object2
							l_AlertShutdown .= PlayerNumber " " Alert " " warned_base
				else
					For PlayerNumber, warned_base in Object	;index = player number
						l_AlertShutdown .= PlayerNumber " " warned_base	;use the space as the separator - not allowed in sc2 battletags	
			}
			Iniwrite, %l_AlertShutdown%, %config_file%, Resume Warnings, %A_loopfield%		
			l_AlertShutdown := ""
		}
		Iniwrite, 1, %config_file%, Resume Warnings, Resume
		return
	}
	Else if (Mode = "Resume")
	{
		Alert_TimedOut := [], Alerted_Buildings := [], Alerted_Buildings_Base := []
		Iniwrite, 0, %config_file%, Resume Warnings, Resume
		loop, parse, l_WarningArrays, `,
		{
			ArrayName := A_loopfield
			%ArrayName% := []
			Iniread, string, %config_file%, Resume Warnings, %ArrayName%, %A_space%
			if string
				loop, parse, string, `,
				{
					StringSplit, VarOut, A_loopfield, %A_Space%
					if (ArrayName = "Alert_TimedOut")
						%ArrayName%[A_index, VarOut1, VarOut2] := VarOut3
					else
						%ArrayName%[A_index, VarOut1] := VarOut2	
				}
		}
		IniDelete, %config_file%, Resume Warnings
		return
	}

		;i should really compare the unit type, as theres a chance that the warned unit has died and was replaced with another unit which should be warned
	loop_AlertList:
		loop, % alert_array[GameType, "list", "size"]
		{ 			; the below if statement for time		
			Alert_Index := A_Index	;the alert index number which corresponds to the ini file/config
			if  ( type = aUnitID[alert_array[GameType, A_Index, "IDName"]] ) ;So if its a shrine and the player is not on ur team
			{
				if ( time < alert_array[GameType, A_Index, "DWB"] OR time > alert_array[GameType, A_Index, "DWA"]  ) ; too early/late to warn - add unit to 'warned list'
				{			
					For index, object in Alert_TimedOut	; ;checks if the exact unit is in the time list already (eg if time > dont_warn_before, the original if statement wont be true so BAS_Warning will remain "give warning")			
						if ( unit = object[owner, Alert_Index] ) ;checks if type is in the list already
							continue, loop_AlertList ; dont break, as could be other alerts for same unit but with different times later/lower in list									
					Alert_TimedOut[Alert_TimedOut.maxindex() ? Alert_TimedOut.maxindex()+1 : 1, owner, Alert_Index] := unit
					continue, loop_AlertList
				}
				Else
				{	;during warn time lets check if the unit has already been warned			
					For index, object in Alert_TimedOut	; ;checks if the exact unit is in the time list already (eg if time > dont_warn_before, the original if statement wont be true so BAS_Warning will remain "give warning")			
						if ( unit = object[owner, Alert_Index] ) ;checks if type is in the list already									
								break loop_AlertList

					If  !alert_array[GameType, A_Index, "Repeat"] ;else check if this unit type has already been warned												
						For index, warned_type in Alerted_Buildings ;	if ( type = Alerted_Buildings[index, owner] ) ;checks if type is in the list already						
							if ( Alert_Index = warned_type[owner] ) ;checks if alert index i.e. alert 1,2,3 is in the list already						
								break loop_AlertList			

					For index, warned_unit in Alerted_Buildings_Base  ; this list contains all the exact units which have already been warned				
						if ( unit = warned_unit[owner] ) ;checks if type is in the list already				
							break loop_AlertList ; this warning is for the exact unitbase Address																				
				}										
				MiniMapWarning.insert({"Unit": unit, "Time": Time})

				If ( alert_array[GameType, "Clipboard"] && WinActive(GameIdentifier))
					clipboard := alert_array[GameType, A_Index, "Name"] " Detected - " aPlayer[owner, "Colour"] " - " aPlayer[owner, "Name"]
				PrevWarning := []
				PrevWarning.speech := alert_array[GameType, A_Index, "Name"]
				PrevWarning.unitIndex := unit
				tSpeak(alert_array[GameType, A_Index, "Name"])
				if (!alert_array[GameType, A_Index, "Repeat"])	; =0 these below setup a list like above, but contins the type - to prevent rewarning
					Alerted_Buildings.insert({(owner): Alert_Index})
					;Alerted_Buildings[Alerted_Buildings.maxindex() ? Alerted_Buildings.maxindex()+1 : 1, owner] :=  Alert_Index					
				Alerted_Buildings_Base.insert({(owner): unit})
				;Alerted_Buildings_Base[Alerted_Buildings_Base.maxindex() ? Alerted_Buildings_Base.maxindex()+1 : 1, owner] := unit	; prevents the same exact unit beings warned on next run thru
				break loop_AlertList	
			} ;End of if unit is on list and player not on our team 
		} ; loop, % alert_array[GameType, "list", "size"]
	return
}

; used to monitor the activation/min of the sc2 window
; Also for removing and reinstalling hooks
; for drawing overlays (rather than a timer)
; lParam is the sc2 hWnd
; 4 params are passed if you add more params to shell message definition
; but i dont know what these are.
ShellMessage(wParam, lParam) 
{
	Global
	Static ReDrawOverlays

	if (wParam = 32772 || wParam = 4) ;  HSHELL_WINDOWACTIVATED := 4 or 32772
	{
	;	WinGetClass, class, A 
	;	if (class != "Starcraft II" && !ReDrawOverlays && !Dragoverlay)
		if (SC2hWnd != lParam && !ReDrawOverlays && !Dragoverlay)
		{

			ReDrawOverlays 	:= ReDrawMiniMap := ReDrawIncome := ReDrawResources 
							:= ReDrawArmySize := ReDrawWorker := ReDrawIdleWorkers 
							:= RedrawUnit := ReDrawLocalPlayerColour := True
			DestroyOverlays()
		}
		else if (SC2hWnd = lParam && getTime())
		{
			; Safer to just remove then reinstall the hook when the widow becomes activated again
			; Should be impossible for the hook to be removed without being reinstalled
			; rather than removing it when window loses focus, then reinstalling it 
			; when window regains focus
			setLowLevelInputHooks(False)
			setLowLevelInputHooks(True)
			;mt_Paused otherwise will redisplay the hidden and frozen overlays
			if (ReDrawOverlays  && !mt_Paused && !IsInList(aLocalPlayer.Type, "Referee", "Spectator")) ; This will redraw immediately - but this isn't needed at all
			{  											; need time to check if in game
				gosub, MiniMap_Timer 					; also need to check player type
				gosub, overlay_timer
				gosub, g_unitPanelOverlay_timer
				ReDrawOverlays := False
			}
		}
	}
	return
}

; Shell is used instead of this timer now 
OverlayKeepOnTop:
	if (!ReDrawOverlays  && !WinActive(GameIdentifier))
	{	
		ReDrawOverlays := ReDrawMiniMap := ReDrawIncome := ReDrawResources := ReDrawArmySize := ReDrawWorker := ReDrawIdleWorkers 
				:= RedrawUnit := ReDrawLocalPlayerColour := 1
		DestroyOverlays()
	}
	else ReDrawOverlays := 0
Return

MiniMap_Timer:
return ;testing minimapthread
	if WinActive(GameIdentifier)
		DrawMiniMap()
Return

g_HideMiniMap:
; This will temporarily disable the minimap, but still draw detected units/non-converted gates
	if DrawMiniMap
	{
	;	Try Gui, MiniMapOverlay: Destroy 
		DrawMiniMap := False
		gosub, MiniMap_Timer ; so minimap dissapears instantly 
		sleep, 2500
		DrawMiniMap := True
		gosub, MiniMap_Timer
	;	ReDrawMiniMap := 1
	}
return

overlay_timer: 	;DrawIncomeOverlay(ByRef Redraw, UserScale=1, PlayerIdent=0, Background=0,Drag=0)
	If (WinActive(GameIdentifier) || Dragoverlay) ;really only needed to ressize/scale not drag - as the movement is donve via  a post message - needed as overlay becomes the active window during drag etc
	{
		If DrawIncomeOverlay
			DrawIncomeOverlay(ReDrawIncome, IncomeOverlayScale, OverlayIdent, OverlayBackgrounds, Dragoverlay)
		If DrawResourcesOverlay
			DrawResourcesOverlay(ReDrawResources, ResourcesOverlayScale, OverlayIdent, OverlayBackgrounds, Dragoverlay)
		If DrawArmySizeOverlay
			DrawArmySizeOverlay(ReDrawArmySize, ArmySizeOverlayScale, OverlayIdent, OverlayBackgrounds, Dragoverlay)
		If DrawWorkerOverlay
			DrawWorkerOverlay(ReDrawWorker, WorkerOverlayScale, Dragoverlay) ;2 less parameters
		If DrawIdleWorkersOverlay
			DrawIdleWorkersOverlay(ReDrawIdleWorkers, IdleWorkersOverlayScale, dragOverlay)
		if (DrawLocalPlayerColourOverlay && (GameType != "1v1" || GameType != "FFA"))   ;easier just to redraw it each time as otherwise have to change internal for when dragging
			DrawLocalPlayerColour(ReDrawLocalPlayerColour, LocalPlayerColourOverlayScale, DragOverlay)
	}
Return

g_unitPanelOverlay_timer: 
	If (DrawUnitOverlay && (WinActive(GameIdentifier) || Dragoverlay))
	{
		getEnemyUnitCount(aEnemyUnits, aEnemyBuildingConstruction, aUnitID)
		FilterUnits(aEnemyUnits, aEnemyBuildingConstruction, aUnitPanelUnits, aUnitID, aPlayer)
	;	if DrawUnitOverlay
		DrawUnitOverlay(RedrawUnit, UnitOverlayScale, OverlayIdent, Dragoverlay)
	}
return



Homepage:
	run % url.homepage
	return

g_buyBeer:
	run % url.buyBeer
	return

;------------
;	Exit
;------------

timer_Exit:
{
	process, exist, %GameExe%
	if !errorlevel 		;errorlevel = 0 if not exist
		ExitApp ; this will run the shutdown routine below
}
return

ShutdownProcedure:
	setLowLevelInputHooks(False)
	Closed := ReadMemory()
	Closed := ReadRawMemory()
	Closed := ReadMemory_Str()
	Gdip_Shutdown(pToken)

	if aThreads.Speech.ahkReady() 	; if exists
		aThreads.Speech.ahkTerminate(500) ; needs 5 so thread doesn't persist	
	if aThreads.miniMap.ahkReady() 	
		aThreads.miniMap.ahkTerminate(500) 

	Iniwrite, % round(GetProgramWaveVolume()), %config_file%, Volume, program

	ExitApp
Return

;------------
;	Updates
;------------

GuiReturn:
	Gui Destroy
	Return 

OptionsGuiClose:
OptionsGuiEscape:
Gui, Options:-Disabled  
Gui Destroy
Gosub pre_startup	;so the correct values get read back for time *1000 conversion from ms/s vice versa
Return				

GuiClose:
GuiEscape:
	Gui, Options:-Disabled ; as the colour selector comes here, no need to reenable the options
	Gui Destroy
Return	

AUpdate_OnClose: ;from the Auto Update GUI
	Gui Destroy
	Goto Launch

TrayUpdate:
	IfWinExist, Macro Trainer Update
	{	WinActivate
		Return 					
	}
	IF (CheckForUpdates(ProgramVersion, url.vr ))
	{
;		changelog_text := Url2Var(url.changelog)
		Gui, New
		Gui +Toolwindow	
		Gui, Add, Picture, x12 y10 w90 h90 , %A_Temp%\Starcraft-2.ico
		Gui, Font, S10 CDefault Bold, Verdana
		Gui, Add, Text, x112 y10 w220, An update is available.
		Gui, Font, Norm 
		Gui, Add, Text, x112 y35 w300, Click UPDATE to download the latest version.
		Gui, Add, Text, x112 y+5, You're currently running version %ProgramVersion%
		Gui, Font, S8 CDefault Bold, Verdana
		Gui, Add, Text, x112 y+5 w80, Changelog:
		Gui, Font, Norm 

	;	Gui, Add, Edit, x12 y+10 w560 h220 readonly -E0x200, % LTrim(changelog_text)
		Gui Add, ActiveX, x12 y+10 w560 h220  vWB, Shell.Explorer
		WB.Navigate(url.changelog)

		Gui, Font, S8 CDefault Bold, Verdana
		Gui, Add, Button, Default x122 y330 w100 h30 gUpdate, &Update
		Gui, Font, Norm 
		Gui, Add, Button, x342 y330 w100 h30 gGuiReturn, Cancel
		Gui, Show, x483 y242 h379 w593, Macro Trainer Update
		Return				
	}
	Else
	{
		Gui, New
		Gui +Toolwindow +AlwaysOnTop	
		Gui, Add, Picture, x12 y10 w90 h90 , %A_Temp%\Starcraft-2.ico
		Gui, Font, S10 CDefault, Verdana
		Gui, Add, Text, x112 y15  , You already have the latest version.
		Gui, Add, Text, xp yp+20  , Version:
		Gui, Font, S10 CDefault Bold, Verdana
		Gui, Add, Text, xp+60 yp  , %ProgramVersion%
		Gui, Font, Norm 
		Gui, Font, S8 CDefault Bold, Verdana
		Gui, Font, Norm 
		Gui, Add, Button, Default x160 yp+40  w100 h30 gGuiReturn, &OK
		Gui, Show, , Macro Trainer Update
		Return
	}
Update:
	; latestVersion is a global variable set by the checkforupdate()
	EXE_url := "http://www.users.on.net/~jb10/Macro Trainer V" latestVersion ".exe"
	save := "Macro Trainer V" latestVersion ".exe"
	If ( InternetFileRead( binData, EXE_url ) > 0 && !ErrorLevel )
	If VarZ_Save( binData, save ) 
	{
		Sleep 200
		DLP(1,1,"Download Complete") ; 1 file of 1 with message on complete
		MsgBox, 262145, Update, Download complete.`n`nClick Ok to run the latest version (Vr %latestVersion%)`nClick cancel to continue running this version.
		IfMsgBox Ok ;msgbox 1 = ok/cancel buttons
		{	
			FileCreateDir, %old_backup_DIR%
			FileMove, %A_ScriptName%, %old_backup_DIR%\%A_ScriptName%, 1 ;ie 1 = overwrite	
			Run %save%	
			ExitApp
		}
		Else	DLP( False ) ;removes the progress
		FileCopy, %A_ScriptName%, %old_backup_DIR%\%A_ScriptName%, 1
	}
	Return

	
;------------
;	Startup/Reading the ini file
;------------
pre_startup:

if FileExist(config_file) ; the file exists lets read the ini settings
{
	readConfigFile()
	if ( ProgramVersion > read_version ) ; its an update and the file exists - better backup the users settings
	{
		program.Info.IsUpdating := 1
		FileCreateDir, %old_backup_DIR%
		FileCopy, %config_file%, %old_backup_DIR%\v%read_version%_%config_file%, 1 ;ie 1 = overwrite
		Filemove, Macro Trainer V%read_version%.exe, %old_backup_DIR%\Macro Trainer V%read_version%.exe, 1 ;ie 1 = overwrite		
		FileInstall, MT_Config.ini, %config_file%, 1 ; 1 overwrites
		if (read_version >= 2.980)
			Gosub, ini_settings_write ;to write back users old settings
		Gosub, pre_startup ; Read the ini settings again - this updates the 'read version' and also helps with Control group 'ERROR' variable 
		;IniRead, read_version, %config_file%, Version, version, 1	;this is a safety net - and used to prevent keeping user alert lists in update pre 2.6 & Auto control group 'ERROR'
		;msgbox It seems that this is the first time that you have ran this version.`n`nYour old %config_file% & Macro Trainer have been backed up to `"\%old_backup_DIR%`". A new config file has been installed which contains your previous personalised settings`n`nPress OK to continue.
		Pressed := CMsgbox( "Macro Trainer Vr" ProgramVersion , "It seems that this is the first time that you have ran this version.`n`nYour old " config_file " and Macro Trainer have been backed up to '\" old_backup_DIR "'.`nA new config file has been installed which contains your previous personalised settings`n`nPress Launch to run SC2 and pwn noobs.`n`nOtherwise press Options to open the options menu.", "*Launch|&Options", 560, 160, 45, A_Temp "\Starcraft-2.ico", 110, 0, 12)
		If ( Pressed = "Options")
			gosub options_menu
	}
	else program.Info.IsUpdating := 0		
}
Else If A_IsCompiled  ; config file doesn't exist
{
	FileInstall, MT_Config.ini, %config_file%, 0 ; includes and install the ini to the working directory - 0 prevents file being overwritten
	CMsgbox( "Macro Trainer Vr" ProgramVersion ,"This appears to be the first time you have run this program.`n`nPlease take a moment to read the help file and edit the settings in the options menu as you see fit.`n`n", "*OK", 500, 130, 10, A_Temp "\Starcraft-2.ico", 110)
	Gosub pre_startup
	gosub options_menu
}
Return	; to the startup procedure
	

;------------
;	Backing up the users ini settings
;------------
ini_settings_write:
	; Iniwrites
	Tmp_GuiControl := A_GuiControl ; store this result otherwise it will be empty when it gets to the bottom
	if (Tmp_GuiControl = "save" OR Tmp_GuiControl = "Apply") ;I come from the save menu options Not an update and writing back user settings
	{
		Try 
		{
			Hotkey, If, WinActive(GameIdentifier) && !BufferInputFast.isInputBlockedOrBuffered() 						
			hotkey, %warning_toggle_key%, off			; 	deactivate the hotkeys
														; 	so they can be updated with their new keys
														;	
														; 
														; Anything with a try command has an 'if setting is on' section in the
														; create hotkeys section
														; still left the overall try just incase i missed something
														; gives the user a friendlier error

			Hotkey, If, WinActive(GameIdentifier) && time && !BufferInputFast.isInputBlockedOrBuffered()	
			hotkey, %worker_count_local_key%, off
			hotkey, %worker_count_enemy_key%, off
			hotkey, %Playback_Alert_Key%, off
			hotkey, %TempHideMiniMapKey%, off
			hotkey, %AdjustOverlayKey%, off
			hotkey, %ToggleIdentifierKey%, off
			hotkey, %ToggleMinimapOverlayKey%, off
			hotkey, %ToggleIncomeOverlayKey%, off
			hotkey, %ToggleResourcesOverlayKey%, off
			hotkey, %ToggleArmySizeOverlayKey%, off			
			hotkey, %ToggleWorkerOverlayKey%, off	
			hotkey, %ToggleUnitOverlayKey%, off						
			hotkey, %CycleOverlayKey%, off		
		Try	hotkey, %read_races_key%, off
		try	hotkey, %inject_start_key%, off
		try	hotkey, %inject_reset_key%, off	

			Hotkey, If, WinActive(GameIdentifier) && time && !isMenuOpen() && SelectArmyEnable && !BufferInputFast.isInputBlockedOrBuffered()
			hotkey, %castSelectArmy_key%, off
			Hotkey, If, WinActive(GameIdentifier) && time && !isMenuOpen() && SplitUnitsEnable && !BufferInputFast.isInputBlockedOrBuffered()
			hotkey, %castSplitUnit_key%, off
			Hotkey, If, WinActive(GameIdentifier) && time && !isMenuOpen() && RemoveUnitEnable && !BufferInputFast.isInputBlockedOrBuffered()
			hotkey, %castRemoveUnit_key%, off
			Hotkey, If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Zerg") && (auto_inject <> "Disabled") && time && !BufferInputFast.isInputBlockedOrBuffered()
			hotkey, %cast_inject_key%, off
			hotkey, %F_InjectOff_Key%, Cast_DisableInject, on	
			Hotkey, If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Protoss") && CG_Enable && time && !BufferInputFast.isInputBlockedOrBuffered()
			hotkey, %Cast_ChronoGate_Key%, off
			Hotkey, If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Protoss") && ChronoBoostEnableForge && time && !BufferInputFast.isInputBlockedOrBuffered()
			hotkey, %Cast_ChronoForge_Key%, off
			Hotkey, If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Protoss") && ChronoBoostEnableStargate && time && !BufferInputFast.isInputBlockedOrBuffered()
			hotkey, %Cast_ChronoStargate_Key%, off		
			Hotkey, If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Protoss") && ChronoBoostEnableNexus && time && !BufferInputFast.isInputBlockedOrBuffered()
			hotkey, %Cast_ChronoNexus_Key%, off
			Hotkey, If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Protoss") && ChronoBoostEnableRoboticsFacility && time && !BufferInputFast.isInputBlockedOrBuffered()
			hotkey, %Cast_ChronoRoboticsFacility_Key%, off
			Hotkey, If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Terran" || aLocalPlayer["Race"] = "Protoss")  && time && !BufferInputFast.isInputBlockedOrBuffered()	
			hotkey, %ToggleAutoWorkerState_Key%, off		
			Hotkey, If, WinActive(GameIdentifier) && !isMenuOpen() && time && !BufferInputFast.isInputBlockedOrBuffered()
			Hotkey, %ping_key%, off		
			while (10 > i := A_index - 1)
			{
				try hotkey, ^%i%, off
				try hotkey, +%i%, off
				try hotkey, ^+%i%, off
			}			
			Hotkey, If	
		}
		Catch, Error	;error is an object
		{
			clipboard := "Error: " error.message "`nLine: " error.line "`nExtra: "error.Extra
			msgbox % "There was an error while updating the hotkey state.`n`nYour previous hotkeys may still be active until you restart the program.`n`nIf you have just edited the options, then this error is NOT very important, but it has been copied to the clipboard if you wish to report it.`n`nNote:`nIf you have just started the program and are receiving this error, then either your hotkeys in your MT_config.ini are corrupted or you are using a non-English keyboard layout. If the latter, you can try changing your keyboard layout to ""English"".`n`nError: " error.message "`nLine: " error.line "`nSpecifically: " error.Extra
		}
		IF (Tmp_GuiControl = "save")
		{
			Gui, Submit
			Gui, Destroy
		}
		Else Gui, Submit, NoHide
	}
	
	;[Auto Inject]
	IniWrite, %auto_inject%, %config_file%, Auto Inject, auto_inject_enable
	IniWrite, %auto_inject_alert%, %config_file%, Auto Inject, alert_enable
	IniWrite, %auto_inject_time%, %config_file%, Auto Inject, auto_inject_time
	IniWrite, %cast_inject_key%, %config_file%, Auto Inject, auto_inject_key
	IniWrite, %Inject_control_group%, %config_file%, Auto Inject, control_group
	IniWrite, %Inject_spawn_larva%, %config_file%, Auto Inject, spawn_larva
	IniWrite, %HotkeysZergBurrow%, %config_file%, Auto Inject, HotkeysZergBurrow

	;[Manual Inject Timer]
	IniWrite, %manual_inject_timer%, %config_file%, Manual Inject Timer, manual_timer_enable
	IniWrite, %manual_inject_time%, %config_file%, Manual Inject Timer, manual_inject_time
	IniWrite, %inject_start_key%, %config_file%, Manual Inject Timer, start_stop_key
	IniWrite, %inject_reset_key%, %config_file%, Manual Inject Timer, reset_key
	
	;[Inject Warning]
	IniWrite, %W_inject_ding_on%, %config_file%, Inject Warning, ding_on
	IniWrite, %W_inject_speech_on%, %config_file%, Inject Warning, speech_on
	IniWrite, %w_inject_spoken%, %config_file%, Inject Warning, w_inject	
	
		;[Forced Inject]
	section := "Forced Inject"
	IniWrite, %F_Inject_Enable%, %config_file%, %section%, F_Inject_Enable
	IniWrite, %FInjectHatchFrequency%, %config_file%, %section%, FInjectHatchFrequency
	IniWrite, %FInjectHatchMaxHatches%, %config_file%, %section%, FInjectHatchMaxHatches
	IniWrite, %FInjectAPMProtection%, %config_file%, %section%, FInjectAPMProtection
	IniWrite, %F_InjectOff_Key%, %config_file%, %section%, F_InjectOff_Key

	;[Idle AFK Game Pause]
	IniWrite, %idle_enable%, %config_file%, Idle AFK Game Pause, enable
	IniWrite, %idle_time%, %config_file%, Idle AFK Game Pause, idle_time
	IniWrite, %UserIdle_LoLimit%, %config_file%, Idle AFK Game Pause, UserIdle_LoLimit
	if (UserIdle_HiLimit < UserIdle_LoLimit)
		UserIdle_HiLimit := UserIdle_LoLimit + 5
	IniWrite, %UserIdle_HiLimit%, %config_file%, Idle AFK Game Pause, UserIdle_HiLimit
	IniWrite, %chat_text%, %config_file%, Idle AFK Game Pause, chat_text


	;[Starcraft Settings & Keys]
	IniWrite, %pause_game%, %config_file%, Starcraft Settings & Keys, pause_game
	IniWrite, %base_camera%, %config_file%, Starcraft Settings & Keys, base_camera
	IniWrite, %NextSubgroupKey%, %config_file%, Starcraft Settings & Keys, NextSubgroupKey
	IniWrite, %escape%, %config_file%, Starcraft Settings & Keys, {escape}
	
	; [MiniMap Inject]
	section := "MiniMap Inject"
	IniWrite, %MI_Queen_Group%, %config_file%, %section%, MI_Queen_Group
	IniWrite, %MI_QueenDistance%, %config_file%, %section%, MI_QueenDistance
	
	;[Backspace Inject Keys]
	section := "Backspace Inject Keys"
	IniWrite, %BI_create_camera_pos_x%, %config_file%, %section%, create_camera_pos_x
	IniWrite, %BI_camera_pos_x%, %config_file%, %section%, camera_pos_x
	
	;[Forgotten Gateway/Warpgate Warning]
	section := "Forgotten Gateway/Warpgate Warning"
	IniWrite, %warpgate_warn_on%, %config_file%, %section%, enable
	IniWrite, %sec_warpgate%, %config_file%, %section%, warning_count
	IniWrite, %delay_warpgate_warn%, %config_file%, %section%, initial_time_delay
	IniWrite, %delay_warpgate_warn_followup%, %config_file%, %section%, follow_up_time_delay
	IniWrite, %w_warpgate%, %config_file%, %section%, spoken_warning

	
	;[Chrono Boost Gateway/Warpgate]
	section := "Chrono Boost Gateway/Warpgate"
	IniWrite, %CG_Enable%, %config_file%, %section%, enable
	IniWrite, %Cast_ChronoGate_Key%, %config_file%, %section%, Cast_ChronoGate_Key
	IniWrite, %CG_control_group%, %config_file%, %section%, CG_control_group
	IniWrite, %CG_nexus_Ctrlgroup_key%, %config_file%, %section%, CG_nexus_Ctrlgroup_key
	IniWrite, %chrono_key%, %config_file%, %section%, chrono_key
	IniWrite, %CG_chrono_remainder%, %config_file%, %section%, CG_chrono_remainder
	IniWrite, %ChronoBoostSleep%, %config_file%, %section%, ChronoBoostSleep
	IniWrite, %ChronoBoostEnableForge%, %config_file%, %section%, ChronoBoostEnableForge
	IniWrite, %ChronoBoostEnableStargate%, %config_file%, %section%, ChronoBoostEnableStargate
	IniWrite, %ChronoBoostEnableNexus%, %config_file%, %section%, ChronoBoostEnableNexus
	IniWrite, %ChronoBoostEnableRoboticsFacility%, %config_file%, %section%, ChronoBoostEnableRoboticsFacility	
	IniWrite, %Cast_ChronoForge_Key%, %config_file%, %section%, Cast_ChronoForge_Key
	IniWrite, %Cast_ChronoStargate_Key%, %config_file%, %section%, Cast_ChronoStargate_Key
	IniWrite, %Cast_ChronoNexus_Key%, %config_file%, %section%, Cast_ChronoNexus_Key
	IniWrite, %Cast_ChronoRoboticsFacility_Key%, %config_file%, %section%, Cast_ChronoRoboticsFacility_Key
	
	;[Auto Control Group]
	Short_Race_List := "Terr|Prot|Zerg"
	section := "Auto Control Group"		
	Loop, Parse, l_Races, `, ;Terran ie full name
		while (10 > i := A_index - 1)
		{
			if (Tmp_GuiControl = "save" OR Tmp_GuiControl = "Apply") ; this ensure wont blank the field when version updates
				A_UnitGroupSettings["LimitGroup", A_LoopField, i, "Enabled"] := LG_%A_LoopField%%i%
			IniWrite, % A_UnitGroupSettings["LimitGroup", A_LoopField, i,"Enabled"], %config_file%, %section%, %A_LoopField%_LimitGroup_%i%
		}		
	loop, parse, Short_Race_List, |
	{	
		i := 0
		If (A_LoopField = "Terr")
			Race := "Terran"
		Else if (A_LoopField = "Prot")
			Race := "Protoss"
		Else If (A_LoopField = "Zerg")
			Race := "Zerg"	


		if (Tmp_GuiControl = "save" OR Tmp_GuiControl = "Apply")
			A_UnitGroupSettings["AutoGroup", Race, "Enabled"] := AG_Enable_%A_LoopField%
		IniWrite, % A_UnitGroupSettings["AutoGroup", Race, "Enabled"], %config_file%, %section%, AG_Enable_%A_LoopField%		
		loop, 10
		{	if (Tmp_GuiControl = "save" OR Tmp_GuiControl = "Apply")			
				A_UnitGroupSettings[Race, i] := AG_%Race%%i%
			IniWrite, % A_UnitGroupSettings[Race, i], %config_file%, %section%, AG_%A_LoopField%%i%
			i++
		}
	}
	IniWrite, %AG_Delay%, %config_file%, %section%, AG_Delay

	;[Advanced Auto Inject Settings]
	IniWrite, %auto_inject_sleep%, %config_file%, Advanced Auto Inject Settings, auto_inject_sleep
	IniWrite, %Inject_SleepVariance%, %config_file%, Advanced Auto Inject Settings, Inject_SleepVariance
	; 30 (%) from the gui back into 1.3
	Inject_SleepVariance := 1 + (Inject_SleepVariance/100)
	IniWrite, %CanQueenMultiInject%, %config_file%, Advanced Auto Inject Settings, CanQueenMultiInject
	IniWrite, %Inject_RestoreSelection%, %config_file%, Advanced Auto Inject Settings, Inject_RestoreSelection
	IniWrite, %Inject_RestoreScreenLocation%, %config_file%, Advanced Auto Inject Settings, Inject_RestoreScreenLocation
	IniWrite, %drag_origin%, %config_file%, Advanced Auto Inject Settings, drag_origin

	;[Read Opponents Spawn-Races]
	IniWrite, %race_reading%, %config_file%, Read Opponents Spawn-Races, enable
	IniWrite, %Auto_Read_Races%, %config_file%, Read Opponents Spawn-Races, Auto_Read_Races
	IniWrite, %read_races_key%, %config_file%, Read Opponents Spawn-Races, read_key
	IniWrite, %race_speech%, %config_file%, Read Opponents Spawn-Races, speech
	IniWrite, %race_clipboard%, %config_file%, Read Opponents Spawn-Races, copy_to_clipboard

	;[Worker Production Helper]	
	IniWrite, %workeron%, %config_file%, Worker Production Helper, warning_enable
	IniWrite, %workerproduction_time%, %config_file%, Worker Production Helper, production_time_lapse
	IniWrite, %workerProductionTPIdle%, %config_file%, Worker Production Helper, workerProductionTPIdle

	;[Minerals]
	IniWrite, %mineralon%, %config_file%, Minerals, warning_enable
	IniWrite, %mineraltrigger%, %config_file%, Minerals, mineral_trigger

	;[Gas]
	IniWrite, %gas_on%, %config_file%, Gas, warning_enable
	IniWrite, %gas_trigger%, %config_file%, Gas, gas_trigger


	;[Idle Workers]
	IniWrite, %idleon%, %config_file%, Idle Workers, warning_enable
	IniWrite, %idletrigger%, %config_file%, Idle Workers, idle_trigger

	;[Supply]
	IniWrite, %supplyon%, %config_file%, Supply, warning_enable
	IniWrite, %minimum_supply%, %config_file%, Supply, minimum_supply
	IniWrite, %supplylower%, %config_file%, Supply, supplylower
	IniWrite, %supplymid%, %config_file%, Supply, supplymid
	IniWrite, %supplyupper%, %config_file%, Supply, supplyupper
	IniWrite, %sub_lowerdelta%, %config_file%, Supply, sub_lowerdelta
	IniWrite, %sub_middelta%, %config_file%, Supply, sub_middelta
	IniWrite, %sub_upperdelta%, %config_file%, Supply, sub_upperdelta
	IniWrite, %above_upperdelta%, %config_file%, Supply, above_upperdelta

	;[Additional Warning Count]-----set number of warnings to make
	IniWrite, %sec_supply%, %config_file%, Additional Warning Count, supply
	IniWrite, %sec_mineral%, %config_file%, Additional Warning Count, minerals
	IniWrite, %sec_gas%, %config_file%, Additional Warning Count, gas
	IniWrite, %sec_workerprod%, %config_file%, Additional Warning Count, worker_production
	IniWrite, %sec_idle%, %config_file%, Additional Warning Count, idle_workers

	;[ Volume]
	section := "Volume"
	IniWrite, %speech_volume%, %config_file%, %section%, speech
	IniWrite, %programVolume%, %config_file%, %section%, program
	SetProgramWaveVolume(programVolume)
	; theres an iniwrite volume in the exit routine

	;[Warnings]-----sets the audio warning
	IniWrite, %w_supply%, %config_file%, Warnings, supply
	IniWrite, %w_mineral%, %config_file%, Warnings, minerals
	IniWrite, %w_gas%, %config_file%, Warnings, gas
	IniWrite, %w_workerprod_T%, %config_file%, Warnings, worker_production_T
	IniWrite, %w_workerprod_P%, %config_file%, Warnings, worker_production_P
	IniWrite, %w_workerprod_Z%, %config_file%, Warnings, worker_production_Z
	IniWrite, %w_idle%, %config_file%, Warnings, idle_workers

	;[Additional Warning Delay]
	IniWrite, %additional_delay_supply%, %config_file%, Additional Warning Delay, supply
	IniWrite, %additional_delay_minerals%, %config_file%, Additional Warning Delay, minerals
	IniWrite, %additional_delay_gas%, %config_file%, Additional Warning Delay, gas
	IniWrite, %additional_delay_worker_production%, %config_file%, Additional Warning Delay, worker_production ;sc2time
	IniWrite, %additional_idle_workers%, %config_file%, Additional Warning Delay, idle_workers

	
		;[Auto Mine]
	section := "Auto Mine"
	IniWrite, %auto_mine%, %config_file%, %section%, enable
	IniWrite, %Auto_Mine_Set_CtrlGroup%, %config_file%, %section%, Auto_Mine_Set_CtrlGroup
	IniWrite, %Auto_mineMakeWorker%, %config_file%, %section%, Auto_mineMakeWorker
	IniWrite, %AutoMineMethod%, %config_file%, %section%, AutoMineMethod
	IniWrite, %WorkerSplitType%, %config_file%, %section%, WorkerSplitType
	IniWrite, %Auto_Mine_Sleep2%, %config_file%, %section%, Auto_Mine_Sleep2
	if (Tmp_GuiControl = "save" OR Tmp_GuiControl = "Apply") ;lets calculate the (possibly) new colour
		AM_PixelColour := Gdip_ToARGB(AM_MiniMap_PixelColourAlpha, AM_MiniMap_PixelColourRed, AM_MiniMap_PixelColourGreen, AM_MinsiMap_PixelColourBlue)
	IniWrite, %AM_PixelColour%, %config_file%, %section%, AM_PixelColour
	IniWrite, %AM_MiniMap_PixelVariance%, %config_file%, %section%, AM_MiniMap_PixelVariance
	IniWrite, %Start_Mine_Time%, %config_file%, %section%, Start_Mine_Time
	IniWrite, %Idle_Worker_Key%, %config_file%, %section%, Idle_Worker_Key
	IniWrite, %AM_KeyDelay%, %config_file%, %section%, AM_KeyDelay
	IniWrite, %Gather_Minerals_key%, %config_file%, %section%, Gather_Minerals_key
	IniWrite, %Base_Control_Group_Key%, %config_file%, %section%, Base_Control_Group_Key
	IniWrite, %Make_Worker_T_Key%, %config_file%, %section%, Make_Worker_T_Key
	IniWrite, %Make_Worker_P_Key%, %config_file%, %section%, Make_Worker_P_Key
	IniWrite, %Make_Worker_Z1_Key%, %config_file%, %section%, Make_Worker_Z1_Key
	IniWrite, %Make_Worker_Z2_Key%, %config_file%, %section%, Make_Worker_Z2_Key


	;[Misc Automation]
	section := "AutoWorkerProduction"	
	IniWrite, %EnableAutoWorkerTerranStart%, %config_file%, %section%, EnableAutoWorkerTerranStart
	IniWrite, %EnableAutoWorkerProtossStart%, %config_file%, %section%, EnableAutoWorkerProtossStart
	IniWrite, %ToggleAutoWorkerState_Key%, %config_file%, %section%, ToggleAutoWorkerState_Key
	IniWrite, %AutoWorkerQueueSupplyBlock%, %config_file%, %section%, AutoWorkerQueueSupplyBlock
	IniWrite, %AutoWorkerAPMProtection%, %config_file%, %section%, AutoWorkerAPMProtection
	IniWrite, %AutoWorkerStorage_T_Key%, %config_file%, %section%, AutoWorkerStorage_T_Key
	IniWrite, %AutoWorkerStorage_P_Key%, %config_file%, %section%, AutoWorkerStorage_P_Key
	IniWrite, %Base_Control_Group_T_Key%, %config_file%, %section%, Base_Control_Group_T_Key
	IniWrite, %Base_Control_Group_P_Key%, %config_file%, %section%, Base_Control_Group_P_Key
	IniWrite, %AutoWorkerMakeWorker_T_Key%, %config_file%, %section%, AutoWorkerMakeWorker_T_Key
	IniWrite, %AutoWorkerMakeWorker_P_Key%, %config_file%, %section%, AutoWorkerMakeWorker_P_Key
	IniWrite, %AutoWorkerMaxWorkerTerran%, %config_file%, %section%, AutoWorkerMaxWorkerTerran
	IniWrite, %AutoWorkerMaxWorkerPerBaseTerran%, %config_file%, %section%, AutoWorkerMaxWorkerPerBaseTerran
	IniWrite, %AutoWorkerMaxWorkerProtoss%, %config_file%, %section%, AutoWorkerMaxWorkerProtoss
	IniWrite, %AutoWorkerMaxWorkerPerBaseProtoss%, %config_file%, %section%, AutoWorkerMaxWorkerPerBaseProtoss
	
	;[Misc Automation]
	section := "Misc Automation"
	IniWrite, %SelectArmyEnable%, %config_file%, %section%, SelectArmyEnable
	IniWrite, %Sc2SelectArmy_Key%, %config_file%, %section%, Sc2SelectArmy_Key
	IniWrite, %castSelectArmy_key%, %config_file%, %section%, castSelectArmy_key
	IniWrite, %SleepSelectArmy%, %config_file%, %section%, SleepSelectArmy
	IniWrite, %ModifierBeepSelectArmy%, %config_file%, %section%, ModifierBeepSelectArmy
	IniWrite, %SelectArmyDeselectXelnaga%, %config_file%, %section%, SelectArmyDeselectXelnaga
	IniWrite, %SelectArmyDeselectPatrolling%, %config_file%, %section%, SelectArmyDeselectPatrolling
	IniWrite, %SelectArmyDeselectHoldPosition%, %config_file%, %section%, SelectArmyDeselectHoldPosition
	IniWrite, %SelectArmyDeselectFollowing%, %config_file%, %section%, SelectArmyDeselectFollowing

	IniWrite, %SelectArmyControlGroupEnable%, %config_file%, %section%, SelectArmyControlGroupEnable
	IniWrite, %Sc2SelectArmyCtrlGroup%, %config_file%, %section%, Sc2SelectArmyCtrlGroup
	IniWrite, %SplitUnitsEnable%, %config_file%, %section%, SplitUnitsEnable
	IniWrite, %castSplitUnit_key%, %config_file%, %section%, castSplitUnit_key
	IniWrite, %SplitctrlgroupStorage_key%, %config_file%, %section%, SplitctrlgroupStorage_key
	IniWrite, %SleepSplitUnits%, %config_file%, %section%, SleepSplitUnits
	IniWrite, %l_DeselectArmy%, %config_file%, %section%, l_DeselectArmy
	IniWrite, %DeselectSleepTime%, %config_file%, %section%, DeselectSleepTime
	IniWrite, %RemoveUnitEnable%, %config_file%, %section%, RemoveUnitEnable
	IniWrite, %castRemoveUnit_key%, %config_file%, %section%, castRemoveUnit_key
		
	;[Misc Hotkey]
	IniWrite, %worker_count_local_key%, %config_file%, Misc Hotkey, worker_count_key
	IniWrite, %worker_count_enemy_key%, %config_file%, Misc Hotkey, enemy_worker_count
	IniWrite, %warning_toggle_key%, %config_file%, Misc Hotkey, pause_resume_warnings_key
	IniWrite, %ping_key%, %config_file%, Misc Hotkey, ping_map

	;[Misc Settings]
	section := "Misc Settings"
	IniWrite, %input_method%, %config_file%, %section%, input_method
	IniWrite, %EventKeyDelay%, %config_file%, %section%, EventKeyDelay
	IniWrite, %pKeyDelay%, %config_file%, %section%, pKeyDelay
	IniWrite, %auto_update%, %config_file%, %section%, auto_check_updates
	Iniwrite, %launch_settings%, %config_file%, %section%, launch_settings
	Iniwrite, %MaxWindowOnStart%, %config_file%, %section%, MaxWindowOnStart
	Iniwrite, %HumanMouse%, %config_file%, %section%, HumanMouse
	Iniwrite, %HumanMouseTimeLo%, %config_file%, %section%, HumanMouseTimeLo
	Iniwrite, %HumanMouseTimeHi%, %config_file%, %section%, HumanMouseTimeHi
	Iniwrite, %UnitDetectionTimer_ms%, %config_file%, %section%, UnitDetectionTimer_ms
	Iniwrite, %MTCustomIcon%, %config_file%, %section%, MTCustomIcon

	if (MTCustomProgramName && A_IsCompiled)
	{
		if (substr(MTCustomProgramName, -3) != ".exe") ; extract last four chars (0 gets the last char) - case insensitive
			MTCustomProgramName .= ".exe"
		Iniwrite, %MTCustomProgramName%, %config_file%, %section%, MTCustomProgramName	
	}
	else Iniwrite, %MTCustomProgramName%, %config_file%, %section%, MTCustomProgramName		


; 	Iniwrite was causing a space character to get appended to the key each time
; 	rather than overwriting the spaces with a single space
; 	so would end up with a string of spaces... weird
;	so use a blank variable rather than A_Space
;	Iniwrite, %A_Space%, %config_file%, %section%, MTCustomProgramName	

	

	;[Key Blocking]
	section := "Key Blocking"
	IniWrite, %BlockingStandard%, %config_file%, %section%, BlockingStandard
	IniWrite, %BlockingFunctional%, %config_file%, %section%, BlockingFunctional
	IniWrite, %BlockingNumpad%, %config_file%, %section%, BlockingNumpad
	IniWrite, %BlockingMouseKeys%, %config_file%, %section%, BlockingMouseKeys
	IniWrite, %BlockingMultimedia%, %config_file%, %section%, BlockingMultimedia
	IniWrite, %LwinDisable%, %config_file%, %section%, LwinDisable
	IniWrite, %Key_EmergencyRestart%, %config_file%, %section%, Key_EmergencyRestart

	;[Alert Location]
	IniWrite, %Playback_Alert_Key%, %config_file%, Alert Location, Playback_Alert_Key

	;[Overlays]
	section := "Overlays"
	list := "IncomeOverlay,ResourcesOverlay,ArmySizeOverlay,WorkerOverlay,IdleWorkersOverlay,UnitOverlay,LocalPlayerColourOverlay"
	loop, parse, list, `,
	{
		drawname := "Draw" A_LoopField,	drawvar := %drawname%
		scalename := A_LoopField "Scale", scalevar := %scalename%
		Togglename := "Toggle" A_LoopField "Key", Togglevar := %Togglename%
		IniWrite, %drawvar%, %config_file%, %section%, %drawname%
		Iniwrite, %scalevar%, %config_file%, %section%, %scalename%	
		Iniwrite, %Togglevar%, %config_file%, %section%, %Togglename% 	
	}
	Iniwrite, %ToggleMinimapOverlayKey%, %config_file%, %section%, ToggleMinimapOverlayKey	
	Iniwrite, %AdjustOverlayKey%, %config_file%, %section%, AdjustOverlayKey	
	Iniwrite, %ToggleIdentifierKey%, %config_file%, %section%, ToggleIdentifierKey	
	Iniwrite, %CycleOverlayKey%, %config_file%, %section%, CycleOverlayKey	
		If (OverlayIdent = "Hidden")	
			OverlayIdent := 0
		Else If (OverlayIdent = "Name (White)")	
			OverlayIdent := 1				
		Else If (OverlayIdent = "Name (Coloured)")	
			OverlayIdent := 2		
		Else If (OverlayIdent = "Coloured Race Icon")	
			OverlayIdent := 3
		Else if OverlayIdent NOT in 0,1,2,3
			OverlayIdent := 3	
	Iniwrite, %OverlayIdent%, %config_file%, %section%, OverlayIdent	
	Iniwrite, %OverlayBackgrounds%, %config_file%, %section%, OverlayBackgrounds	
	Iniwrite, %MiniMapRefresh%, %config_file%, %section%, MiniMapRefresh	
	Iniwrite, %OverlayRefresh%, %config_file%, %section%, OverlayRefresh	
	Iniwrite, %UnitOverlayRefresh%, %config_file%, %section%, UnitOverlayRefresh

	
	;[MiniMap]
	section := "MiniMap" 
	IniWrite, %UnitHighlightList1%, %config_file%, %section%, UnitHighlightList1	;the list
	IniWrite, %UnitHighlightList2%, %config_file%, %section%, UnitHighlightList2
	IniWrite, %UnitHighlightList3%, %config_file%, %section%, UnitHighlightList3
	IniWrite, %UnitHighlightList4%, %config_file%, %section%, UnitHighlightList4
	IniWrite, %UnitHighlightList5%, %config_file%, %section%, UnitHighlightList5
	IniWrite, %UnitHighlightList6%, %config_file%, %section%, UnitHighlightList6
	IniWrite, %UnitHighlightList7%, %config_file%, %section%, UnitHighlightList7

	IniWrite, %UnitHighlightList1Colour%, %config_file%, %section%, UnitHighlightList1Colour ;the colour
	IniWrite, %UnitHighlightList2Colour%, %config_file%, %section%, UnitHighlightList2Colour
	IniWrite, %UnitHighlightList3Colour%, %config_file%, %section%, UnitHighlightList3Colour
	IniWrite, %UnitHighlightList4Colour%, %config_file%, %section%, UnitHighlightList4Colour
	IniWrite, %UnitHighlightList5Colour%, %config_file%, %section%, UnitHighlightList5Colour
	IniWrite, %UnitHighlightList6Colour%, %config_file%, %section%, UnitHighlightList6Colour
	IniWrite, %UnitHighlightList7Colour%, %config_file%, %section%, UnitHighlightList7Colour

	IniWrite, %HighlightInvisible%, %config_file%, %section%, HighlightInvisible
	IniWrite, %UnitHighlightInvisibleColour%, %config_file%, %section%, UnitHighlightInvisibleColour

	IniWrite, %HighlightHallucinations%, %config_file%, %section%, HighlightHallucinations
	IniWrite, %UnitHighlightHallucinationsColour%, %config_file%, %section%, UnitHighlightHallucinationsColour

	IniWrite, %UnitHighlightExcludeList%, %config_file%, %section%, UnitHighlightExcludeList
	IniWrite, %DrawMiniMap%, %config_file%, %section%, DrawMiniMap
	IniWrite, %TempHideMiniMapKey%, %config_file%, %section%, TempHideMiniMapKey
	IniWrite, %DrawSpawningRaces%, %config_file%, %section%, DrawSpawningRaces
	IniWrite, %DrawAlerts%, %config_file%, %section%, DrawAlerts
	IniWrite, %DrawUnitDestinations%, %config_file%, %section%, DrawUnitDestinations
	IniWrite, %DrawPlayerCameras%, %config_file%, %section%, DrawPlayerCameras
	IniWrite, %HostileColourAssist%, %config_file%, %section%, HostileColourAssist

	;this writes back the unit detection lists and settings

	loop, parse, l_GameType, `,
	{
		alert_array[A_LoopField, "Enabled"] := BAS_on_%A_LoopField%
		alert_array[A_LoopField, "Clipboard"] := BAS_copy2clipboard_%A_LoopField%
		IniWrite, % alert_array[A_LoopField, "Enabled"], %config_file%, Building & Unit Alert %A_LoopField%, enable	;alert system on/off
		IniWrite, % alert_array[A_LoopField, "Clipboard"], %config_file%, Building & Unit Alert %A_LoopField%, copy2clipboard
	}

	if (program.Info.IsUpdating && A_IsCompiled)	;as both of these have there own write routines which activate on clicking 'save' in their on guis
	{
		saveAlertArray(alert_array)
		;;;	Gosub, g_SaveCustomUnitPanelFilter      **** Can't use this, as there has been no created List View gui variables so the list view class wont work!!!!!!
		; solution 
		;[UnitPanelFilter]
		section := "UnitPanelFilter" 
		loop, parse, l_Races, `,
		{
			race := A_LoopField
			list := convertObjectToList(aUnitPanelUnits[race, "FilteredCompleted"], "|")
			IniWrite, %List%, %config_file%, %section%, % race "FilteredCompleted"
			list := convertObjectToList(aUnitPanelUnits[race, "FilteredUnderConstruction"], "|")
			IniWrite, %List%, %config_file%, %section%, % race "FilteredUnderConstruction"
			list := ""
		}
	}
	IF (Tmp_GuiControl = "save" or Tmp_GuiControl = "Apply")
	{
		if (time && alert_array[GameType, "Enabled"])
			 doUnitDetection(unit, type, owner, "Save")
		Tmp_GuiControl := ""
		CreateHotkeys()	; to reactivate the hotkeys
		UserSavedAppliedSettings := 1
		If (game_status = "game") ; so if they change settings during match will update timers
			UpdateTimers := 1

	}
Return


g_CreateUnitListsAndObjects:

l_UnitNames := "Colossus|TechLab|Reactor|InfestorTerran|BanelingCocoon|Baneling|Mothership|PointDefenseDrone|Changeling|ChangelingZealot|ChangelingMarineShield|ChangelingMarine|ChangelingZerglingWings|ChangelingZergling|InfestedTerran|CommandCenter|SupplyDepot|Refinery|Barracks|EngineeringBay|MissileTurret|Bunker|SensorTower|GhostAcademy|Factory|Starport|Armory|FusionCore|AutoTurret|SiegeTankSieged|SiegeTank|VikingAssault|VikingFighter|CommandCenterFlying|BarracksTechLab|BarracksReactor|FactoryTechLab|FactoryReactor|StarportTechLab|StarportReactor|FactoryFlying|StarportFlying|SCV|BarracksFlying|SupplyDepotLowered|Marine|Reaper|Ghost|Marauder|Thor|Hellion|Medivac|Banshee|Raven|Battlecruiser|Nuke|Nexus|Pylon|Assimilator|Gateway|Forge|FleetBeacon|TwilightCouncil|PhotonCannon|Stargate|TemplarArchive|DarkShrine|RoboticsBay|RoboticsFacility|CyberneticsCore|Zealot|Stalker|HighTemplar|DarkTemplar|Sentry|Phoenix|Carrier|VoidRay|WarpPrism|Observer|Immortal|Probe|Interceptor|Hatchery|CreepTumor|Extractor|SpawningPool|EvolutionChamber|HydraliskDen|Spire|UltraliskCavern|InfestationPit|NydusNetwork|BanelingNest|RoachWarren|SpineCrawler|SporeCrawler|Lair|Hive|GreaterSpire|Egg|Drone|Zergling|Overlord|Hydralisk|Mutalisk|Ultralisk|Roach|Infestor|Corruptor|BroodLordCocoon|BroodLord|BanelingBurrowed|DroneBurrowed|HydraliskBurrowed|RoachBurrowed|ZerglingBurrowed|InfestorTerranBurrowed|QueenBurrowed|Queen|InfestorBurrowed|OverlordCocoon|Overseer|PlanetaryFortress|UltraliskBurrowed|OrbitalCommand|WarpGate|OrbitalCommandFlying|ForceField|WarpPrismPhasing|CreepTumorBurrowed|SpineCrawlerUprooted|SporeCrawlerUprooted|Archon|NydusCanal|BroodlingEscort|Mule|Larva|HellBat|MothershipCore|Locust|SwarmHostBurrowed|SwarmHost|Oracle|Tempest|WidowMine|Viper|WidowMineBurrowed"
l_UnitNamesTerran := "TechLab|Reactor|PointDefenseDrone|CommandCenter|SupplyDepot|Refinery|Barracks|EngineeringBay|MissileTurret|Bunker|SensorTower|GhostAcademy|Factory|Starport|Armory|FusionCore|AutoTurret|SiegeTankSieged|SiegeTank|VikingAssault|VikingFighter|CommandCenterFlying|BarracksTechLab|BarracksReactor|FactoryTechLab|FactoryReactor|StarportTechLab|StarportReactor|FactoryFlying|StarportFlying|SCV|BarracksFlying|SupplyDepotLowered|Marine|Reaper|Ghost|Marauder|Thor|Hellion|Medivac|Banshee|Raven|Battlecruiser|Nuke|PlanetaryFortress|OrbitalCommand|OrbitalCommandFlying|MULE|HellBat|WidowMine|WidowMineBurrowed"
l_UnitNamesProtoss := "Colossus|Mothership|Nexus|Pylon|Assimilator|Gateway|Forge|FleetBeacon|TwilightCouncil|PhotonCannon|Stargate|TemplarArchive|DarkShrine|RoboticsBay|RoboticsFacility|CyberneticsCore|Zealot|Stalker|HighTemplar|DarkTemplar|Sentry|Phoenix|Carrier|VoidRay|WarpPrism|Observer|Immortal|Probe|Interceptor|WarpGate|WarpPrismPhasing|Archon|MothershipCore|Oracle|Tempest"
l_UnitNamesZerg := "InfestorTerran|BanelingCocoon|Baneling|Changeling|ChangelingZealot|ChangelingMarineShield|ChangelingMarine|ChangelingZerglingWings|ChangelingZergling|InfestedTerran|Hatchery|CreepTumor|Extractor|SpawningPool|EvolutionChamber|HydraliskDen|Spire|UltraliskCavern|InfestationPit|NydusNetwork|BanelingNest|RoachWarren|SpineCrawler|SporeCrawler|Lair|Hive|GreaterSpire|Egg|Drone|Zergling|Overlord|Hydralisk|Mutalisk|Ultralisk|Roach|Infestor|Corruptor|BroodLordCocoon|BroodLord|BanelingBurrowed|DroneBurrowed|HydraliskBurrowed|RoachBurrowed|ZerglingBurrowed|InfestorTerranBurrowed|QueenBurrowed|Queen|InfestorBurrowed|OverlordCocoon|Overseer|UltraliskBurrowed|CreepTumorBurrowed|SpineCrawlerUprooted|SporeCrawlerUprooted|NydusCanal|BroodlingEscort|Larva|Locust|SwarmHostBurrowed|SwarmHost|Viper"

l_UnitPanelTerran := "TechLab|Reactor|PointDefenseDrone|CommandCenter|SupplyDepot|Refinery|Barracks|EngineeringBay|MissileTurret|Bunker|SensorTower|GhostAcademy|Factory|Starport|Armory|FusionCore|AutoTurret|SiegeTank|VikingFighter|SCV|Marine|Reaper|Ghost|Marauder|Thor|Hellion|Medivac|Banshee|Raven|Battlecruiser|Nuke|PlanetaryFortress|OrbitalCommand|MULE|HellBat|WidowMine"
l_UnitPanelZerg := "BanelingCocoon|Baneling|Changeling|InfestedTerran|Hatchery|CreepTumor|Extractor|SpawningPool|EvolutionChamber|HydraliskDen|Spire|UltraliskCavern|InfestationPit|NydusNetwork|BanelingNest|RoachWarren|SpineCrawler|SporeCrawler|Lair|Hive|GreaterSpire|Egg|Drone|Zergling|Overlord|Hydralisk|Mutalisk|Ultralisk|Roach|Infestor|Corruptor|BroodLordCocoon|BroodLord|Queen|OverlordCocoon|Overseer|NydusCanal|Larva|SwarmHost|Viper"
l_UnitPanelProtoss := "Colossus|Mothership|Nexus|Pylon|Assimilator|Gateway|Forge|FleetBeacon|TwilightCouncil|PhotonCannon|Stargate|TemplarArchive|DarkShrine|RoboticsBay|RoboticsFacility|CyberneticsCore|Zealot|Stalker|HighTemplar|DarkTemplar|Sentry|Phoenix|Carrier|VoidRay|WarpPrism|Observer|Immortal|Probe|WarpGate|WarpPrismPhasing|Archon|MothershipCore|Oracle|Tempest"

aUnitLists := [], aUnitLists["All"] := []

ConvertListToObject(aUnitLists["All"], l_UnitNames)
loop, parse, l_Races, `,
{
	race := A_LoopField, list := "l_UnitNames" race, list := %list%
	aUnitLists[race] := []
	ConvertListToObject(aUnitLists[race], list)
	list := "l_UnitPanel" race, list := %list%
	aUnitLists["UnitPanel", race] := []
	ConvertListToObject(aUnitLists["UnitPanel", race], list)
}
return


options_menu:
IfWinExist, Macro Trainer V%ProgramVersion% Settings
{
	WinActivate
	Return 									; prevent error due to reloading gui 
}
Gui, Options:New
gui, font, norm s9	;here so if windows user has +/- font size this standardises it. But need to do other menus one day
;Gui, +ToolWindow  +E0x40000 ; E0x40000 gives it a icon on taskbar (+ToolWindow doesn't have an icon)
options_menu := "home32.png|radarB32.png|map32.png|Inject32.png|Group32.png|Worker32.png|reticule32.png|Robot32.png|key.png|warning32.ico|miscB32.png|bug32.png|settings.ico"
optionsMenuTitles := "Home|Detection List|MiniMap/Overlays|Injects|Unit Grouping|Auto Worker|Chrono Boost|Misc Automation|SC2 Keys|Warnings|Misc Abilities|Report Bug|Settings"
Gosub, g_CreateUnitListsAndObjects ; used for some menu items, and for the custom unit filter gui

ImageListID := IL_Create(10, 5, 1)  ; Create an ImageList with initial capacity for 10 icons, grows it by 5 if need be, and 1=large icons
 
loop, parse, options_menu, | ; | = delimter
	IL_Add(ImageListID, A_Temp "\" A_LoopField) 

guiMenuHeight := 460

Gui, Add, TreeView, -Lines ReadOnly ImageList%ImageListID% h%guiMenuHeight% w150 gOptionsTree vGUIListViewIdentifyingVariableForRedraw
loop, parse, optionsMenuTitles, |
	TV_Add(A_LoopField, 0, "Icon" A_Index)  

		Gui, Font, s10
		GUIButtonPosition := guiMenuHeight + 13
		Gui, Add, Button, x415 y%GUIButtonPosition% w50 h25 gIni_settings_write, Save
		Gui, Add, Button, x+20 w50 h25 gOptionsGuiClose, Cancel
		Gui, Add, Button, x+20 w50 h25 gIni_settings_write, Apply
		Gui, Font, 

Gui, Add, Tab2, w440 h%guiMenuHeight% ys x165 vInjects_TAB, Info||Basic|Auto|Alert|Manual
;Gui, Add, Tab2, w440 h%guiMenuHeight% ys x+5 vInjects_TAB, Info||Basic|Auto|Alert|Manual
GuiControlGet, MenuTab, Pos, Injects_TAB
Gui, Tab,  Basic
	Gui, Add, GroupBox, w200 h240 section vOriginTab, One Button Inject
			GuiControlGet, OriginTab, Pos
		Gui, Add, Text,xp+10 yp+25, Method:		
				If (auto_inject = 0 OR auto_inject = "Disabled")
					droplist_var := 4
				Else If (auto_inject = "MiniMap")
					droplist_var := 1
				Else if (auto_inject = "Backspace Adv") || (auto_inject = "Backspace CtrlGroup")
					droplist_var := 2  
				Else droplist_var := 3
				Gui, Add, DropDownList,x+10 yp-2 w130 vAuto_inject Choose%droplist_var%, MiniMap||Backspace CtrlGroup|Backspace|Disabled
				tmp_xvar := OriginTabx + 10


		Gui, Add, Text, X%tmp_xvar% yp+45 vSillyGUIControlIdentVariable, Inject Hotkey:
			GuiControlGet, XTab, Pos, SillyGUIControlIdentVariable ;XTabX = x loc

		Gui, Add, Edit, Readonly yp-2 xs+85 center w65 vcast_inject_key gedit_hotkey, %cast_inject_key%
		Gui, Add, Button, yp-2 x+10 gEdit_hotkey v#cast_inject_key,  Edit ;have to use a trick eg '#' as cant write directly to above edit var, or it will activate its own label!

		Gui, Add, Text, X%XTabX% yp+35 w70, Spawn Larva:
		Gui, Add, Edit, Readonly yp-2 xs+85 w65 center vInject_spawn_larva, %Inject_spawn_larva%
			Gui, Add, Button, yp-2 x+10 gEdit_SendHotkey v#Inject_spawn_larva,  Edit

	;	Gui, Add, Text, X%XTabX% yp+35 w70, Burrow Key:
	;		Gui, Add, Edit, Readonly yp-2 xs+85 w65 center vHotkeysZergBurrow, %HotkeysZergBurrow%
	;			Gui, Add, Button, yp-2 x+10 gEdit_SendHotkey v#HotkeysZergBurrow,  Edit			

		Gui, Add, Text, X%XTabX% yp40, Control Group: %A_space%(Unit Selection Storage)
			Gui, Add, Edit, Readonly y+10 xs+60 w90 center vInject_control_group , %Inject_control_group%
				Gui, Add, Button, yp-2 x+10 gEdit_SendHotkey v#Inject_control_group,  Edit	

	;Gui, Add, GroupBox, xs y+40 w200 h160, Advanced Settings
	Gui, Add, GroupBox, xs y+71 w200 h160, Advanced Settings
				Gui, Add, Text, xs+20 yp+20 vSG1, Sleep time (ms):`n(Lower is faster)
					GuiControlGet, XTab2, Pos, SG1 ;XTabX = x loc
				Gui, Add, Edit, Number Right xs+125 yp-2 w45 vEdit_pos_var 
					Gui, Add, UpDown,  Range0-100000 vAuto_inject_sleep, %auto_inject_sleep%
					GuiControlGet, settingsR, Pos, Edit_pos_var ;XTabX = x loc

				Gui, Add, Text, xs+20 yp+35, Sleep variance `%:
				Gui, Add, Edit, Number Right xs+125 yp-2 w45 vEdit_Inject_SleepVariance
					Gui, Add, UpDown,  Range0-100000 vInject_SleepVariance, % (Inject_SleepVariance - 1) * 100  

				Gui, Add, Checkbox, x%XTab2X% y+12 vCanQueenMultiInject checked%CanQueenMultiInject%,
				Gui, Add, Text, x+0 yp-5, Queen Can Inject`nMultiple Hatcheries ; done as checkbox with 2 lines text is too close to checkbox

				Gui, Add, Checkbox, x%XTab2X% y+12 vInject_RestoreSelection checked%Inject_RestoreSelection%,
				Gui, Add, Text, x+0 yp, Restore Unit Selection 				
				Gui, Add, Checkbox, x%XTab2X% y+10 vInject_RestoreScreenLocation checked%Inject_RestoreScreenLocation%,
				Gui, Add, Text, x+0 yp, Restore Screen Location

Gui, Add, GroupBox, w200 h180 ys xs+210 section, Backspace Methods
		Gui, Add, Text, xs+10 yp+25, Drag Origin:
		if (Drag_origin = "Right")
			droplist_var :=2
		Else
			droplist_var := 1
		Gui, Add, DropDownList,x+60 yp-2 w50 vDrag_origin Choose%droplist_var%, Left|Right|

		Gui, Add, Text, xs+10 yp+40, Create Camera: %A_space% %A_space% (Location Storge)
			Gui, Add, Edit, Readonly y+10 xs+60 w90 center vBI_create_camera_pos_x , %BI_create_camera_pos_x%
				Gui, Add, Button, yp-2 x+10 gEdit_SendHotkey v#BI_create_camera_pos_x,  Edit

		Gui, Add, Text, xs+10 yp+40, Camera Position: %A_space% %A_space% (Goto Location)
			Gui, Add, Edit, Readonly y+10 xs+60 w90 center vBI_camera_pos_x , %BI_camera_pos_x%
				Gui, Add, Button, yp-2 x+10 gEdit_SendHotkey v#BI_camera_pos_x,  Edit

Gui, Add, GroupBox, w200 h62 y+10 xs,
		Gui, Add, Checkbox, xs+10 yp+13 vauto_inject_alert checked%auto_inject_alert%, Enable Alert
		Gui, Add, Text,xs+10 y+12, Time Between Alerts (s):
		Gui, Add, Edit, Number Right x+25 yp-2 w45 vTT_auto_inject_time
			Gui, Add, UpDown, Range1-100000 vauto_inject_time, %auto_inject_time% ;these belong to the above edit

Gui, Add, GroupBox, xs y+15 w200 h160, MiniMap && Backspace Ctrl Group
		Gui, Add, Text, xs+10 yp+25, Queen Control Group:
			if (MI_Queen_Group = 0)
				droplist_var := 10
			else 
				droplist_var := MI_Queen_Group  	; i have a dropdown menu now so user has to put a number, cant use another key as I use this to check the control groups
			Gui, Add, DropDownList,  x+30 w45 center vMI_Queen_Group Choose%droplist_var%, 1|2|3|4|5|6|7||8|9|0
		;	Gui, Add, Edit, Readonly y+10 xs+60 w90 center vMI_Queen_Group, %MI_Queen_Group%
		;		Gui, Add, Button, yp-2 x+10 gEdit_SendHotkey v#MI_Queen_Group,  Edit			

		Gui, Add, Text, xs+10 yp+40, Max Queen Distance:`n%A_Space% %A_Space% (From Hatch)
			Gui, Add, Edit, Number Right xp+132 yp w45 vTT2_MI_QueenDistance
					Gui, Add, UpDown,  Range1-100000 vMI_QueenDistance, %MI_QueenDistance%			

Gui, Tab,  Info
		gui, font, norm bold s10
		Gui, Add, Text, X%OriginTabX% y+15 cFF0000, Note:
		gui, font, norm s11
		gui, Add, Text, w410 y+15, If a queen has inadequate energy (or is too far from her hatchery), her hatchery will not be injected.
		gui, Add, Text, w410 y+20, The Minimap && Backspace CtrlGroup methods require queens to be hotkeyd. In other words, hatches without a nearby HOTKEYED queen will not be injected.
		gui, Add, Text, w410 y+20, Both Backspace methods require the camera hotkeys be set.
		gui, Add, Text, w410 y+20, If a control, alt, shift, or windows key is held down at the start of the macro you will hear a warning sound.  Release the key(s) and the injects will begin.
		Gui, Font, underline
		Gui, Add, Text,  x300 y262 cBlue gg_PlayModifierWarningSound, Warning Sound
		gui, font, norm s11

		gui, Add, Text, X%OriginTabX% w410 y+15, The Backspace CtrlGroup method is actually the minimap method, but made to look as if the user is pressing 'backspace'.
		gui, font, norm bold s10
		Gui, Add, Text, X%OriginTabX% y+10 cFF0000, Problems:
		gui, font, norm s11
		gui, Add, Text, w410 y+15, If you are consistently missing hatcheries, try increasing the sleep time. 
		gui, Add, Text, w410 y+15, If something really goes wrong, you can reload the program by pressing "Lwin && space" three times.
		gui, font, norm s10
		gui, font, 		

Gui, Tab,  Manual
		Gui, Add, GroupBox,  w295 h165, Manual Inject Timer	;h185
				Gui, Add, Checkbox,xp+10 yp+30 vmanual_inject_timer checked%manual_inject_timer%, Enable
				Gui, Add, Text,y+15, Alert After (s): 
				Gui, Add, Edit, Number Right x+5 yp-2 w45 
					Gui, Add, UpDown, Range1-100000 vmanual_inject_time, %manual_inject_time%
				GuiControlGet, settings2R, Pos, manual_inject_timer
				Gui, Add, Text, x%settings2RX% yp+35 w90, Start/Stop Hotkey:
				Gui, Add, Edit, Readonly yp x+20 w120  vinject_start_key center gedit_hotkey, %inject_start_key%
				Gui, Add, Button, yp-2 x+10 gEdit_hotkey v#inject_start_key,  Edit
				Gui, Add, Text, x%settings2RX% yp+35 w90, Reset Hotkey:
				Gui, Add, Edit, Readonly yp x+20 w120  vinject_reset_key center gedit_hotkey, %inject_reset_key%
				Gui, Add, Button, yp-2 x+10 gEdit_hotkey v#inject_reset_key,  Edit
				Gui, Add, Text,yp+75 x%settings2RX% w340,  This is a very basic timer. It will simply beep every x seconds


Gui, Tab,  Auto
	Gui, Add, GroupBox, y+20 w225 h215, Fully Automated Injects
		Gui, Add, Checkbox,xp+10 yp+30 vF_Inject_Enable checked%F_Inject_Enable%, Enable
	
		Gui, Add, Text,y+15 x%settings2RX% w140, Max injects per round: 
			Gui, Add, Edit, Number Right x+5 yp-2 w60 vTT_FInjectHatchMaxHatches
				Gui, Add, UpDown, Range1-100000 vFInjectHatchMaxHatches, %FInjectHatchMaxHatches%

		Gui, Add, Text,y+15 x%settings2RX% w140, Check Hatches Every (ms): 
			Gui, Add, Edit, Number Right x+5 yp-2 w60 vTT_FInjectHatchFrequency
				Gui, Add, UpDown, Range0-100000 vFInjectHatchFrequency, %FInjectHatchFrequency%					

		Gui, Add, Text, y+15 x%settings2RX% w140, APM Protection:
			Gui, Add, Edit, Number Right x+5 yp-2 w60 vTT_FInjectAPMProtection
				Gui, Add, UpDown,  Range0-100000 vFInjectAPMProtection, %FInjectAPMProtection%		

		Gui, Add, Text, x%settings2RX% yp+30, Enable/Disable Hotkey:
			Gui, Add, Edit, Readonly y+10 xp+45 w120  vF_InjectOff_Key center gedit_hotkey, %F_InjectOff_Key%
			Gui, Add, Button, yp-2 x+10 gEdit_hotkey v#F_InjectOff_Key,  Edit				

	Gui, Add, Text,yp+57 x%settings2RX% w340,  Note:`n`nAuto injects will begin after you control group your queen to the correct (inject) queen control group.`n`nAuto injects are performed using the 'MiniMap' macro.`n`nPlease ensure you have correctly set the settings under the 'basic' inject tab. This includes the 'minimap' settings as well as the 'spawn larva key' and control group storage settings.


Gui, Tab,  Alert
		Gui, Add, GroupBox,  w210 h140, Basic Inject Alert Type
		Gui, Add, Checkbox,xp+10 yp+30 vW_inject_ding_on checked%W_inject_ding_on%, Windows Ding
		Gui, Add, Checkbox,yp+25 vW_inject_speech_on checked%W_inject_speech_on%, Spoken Warning
		Gui, Add, Text,y+15 w125, Spoken Warning:
		Gui, Add, Edit, w180 vW_inject_spoken center, %w_inject_spoken%
		Gui, Font, s10
		Gui, Add, Text, y+60 w360, Note: Due to an inconsistency with the programming language, some systems may not hear the 'windows ding'.
		Gui, Font	


Gui, Add, Tab2,w440 h%guiMenuHeight% X%MenuTabX%  Y%MenuTabY% vKeys_TAB, SC2 Keys				
	Gui, Add, GroupBox, w280 h160, Starcraft Settings && Keys
		Gui, Add, Text, xp+10 yp+30 w90, Pause Game: 
			Gui, Add, Edit, Readonly yp-2 x+10 w120  center vpause_game , %pause_game%
				Gui, Add, Button, yp-2 x+5 gEdit_SendHotkey v#pause_game,  Edit

		Gui, Add, Text, X%XTabX% yp+35 w90, Escape/Cancel:
			Gui, Add, Edit, Readonly yp-2 x+10 w120  center vescape , %escape%
				Gui, Add, Button, yp-2 x+5 gEdit_SendHotkey v#escape,  Edit

		Gui, Add, Text, X%XTabX% yp+35 w90, Base Camera:
			Gui, Add, Edit, Readonly yp-2 x+10 w120  center vbase_camera , %base_camera%
				Gui, Add, Button, yp-2 x+5 gEdit_SendHotkey v#base_camera,  Edit

		Gui, Add, Text, X%XTabX% yp+35 w90, Next Subgroup:
			Gui, Add, Edit, Readonly yp-2 x+10 w120  center vNextSubgroupKey , %NextSubgroupKey%
				Gui, Add, Button, yp-2 x+5 gEdit_SendHotkey v#NextSubgroupKey,  Edit

		gui, font, s10
		tmpX := XTabX-15
		Gui, Add, Text,  X%tmpX% y+50 +wrap, Ensure the following keys match the associated SC2 Functions.
		Gui, Add, Text,  X%tmpX% y+5 +wrap, (either change these settings here or in the SC2 Hotkey options/menu)
		gui, font, 		


Gui, Add, Tab2,w440 h%guiMenuHeight% X%MenuTabX%  Y%MenuTabY% vWarnings_TAB, Supply||Macro|Macro2|Warpgates
Gui, Tab, Supply	
; Gui, Add, GroupBox, w420 h335, Supply				
	Gui, Add, Checkbox, X%XTabX% y+30 Vsupplyon checked%supplyon%, Enable Alert


			Gui, Add, GroupBox, X%XTabX% yp+35 w175 h260 section, Supply Ranges && Deltas

			Gui, font, italic
			Gui, Add, Text,xs+10 yp+25 w100, Warn When Below:
			Gui, font, 
				Gui, Add, Edit, Number Right x+10 yp-2 w45 vTT_sub_lowerdelta 
					Gui, Add, UpDown, Range1-200 Vsub_lowerdelta, %sub_lowerdelta%

			Gui, Add, Text,xs+10 y+15 w100, Low Range Cutoff:
				Gui, Add, Edit, Number Right x+10 yp-2 w45 vTT_supplylower
					Gui, Add, UpDown, Range1-200 Vsupplylower, %supplylower%

			Gui, font, italic 
			Gui, Add, Text,xs+10 y+15 w100,  Warn When Below: 
			Gui, font, 
				Gui, Add, Edit, Number Right x+10 yp-2 w45 vTT_sub_middelta
					Gui, Add, UpDown, Range1-200 Vsub_middelta, %sub_middelta%


			Gui, Add, Text,xs+10 y+15 w100, Middle Range Cutoff:
				Gui, Add, Edit, Number Right x+10 yp-2 w45 vTT_supplymid
					Gui, Add, UpDown, Range1-200 Vsupplymid, %supplymid%

			Gui, font, italic 
			Gui, Add, Text,xs+10 y+15 w100, Warn When Below: 
			Gui, font, 
				Gui, Add, Edit, Number Right x+10 yp-2 w45 vTT_sub_upperdelta
					Gui, Add, UpDown, Range1-200 Vsub_upperdelta, %sub_upperdelta%


			Gui, Add, Text,xs+10 y+15 w100, Upper Range Cutoff:
				Gui, Add, Edit, Number Right x+10 yp-2 w45 vTT_supplyupper
					Gui, Add, UpDown, Range1-200 Vsupplyupper, %supplyupper%		

			Gui, font, italic 
			Gui, Add, Text,xs+10 y+15 w100,  Warn When Below:
			Gui, font, 
				Gui, Add, Edit, Number Right x+10 yp-2 w45 vTT_above_upperdelta
					Gui, Add, UpDown, Range1-200 Vabove_upperdelta, %above_upperdelta%					

					2XTabX := XTabX -10
		Gui, Add, GroupBox, ys x+30 w200 h260, Warnings

			Gui, Add, Text,xp+10 yp+25 w125 section, Silent If Supply Below:
			Gui, Add, Edit, Number Right x+10 yp-2 w45 vTT_minimum_supply
			Gui, Add, UpDown, Range1-200 Vminimum_supply, %minimum_supply%	

			Gui, Add, Text,xs y+15 w125, Secondary Warnings:
				Gui, Add, Edit, Number Right x+10 yp-2 w45 vTT_sec_supply
					Gui, Add, UpDown, Range0-200 Vsec_supply, %sec_supply%

			Gui, Add, Text,y+15 xs w125, Secondary Delay:
				Gui, Add, Edit, Number Right x+10 yp-2 w45 vTT_additional_delay_supply
					Gui, Add, UpDown, Range0-200 Vadditional_delay_supply, %additional_delay_supply%

			Gui, Add, Text,y+15 xs w125, Spoken Warning:
				Gui, Add, Edit, w180 Vw_supply center, %w_supply%

Gui, Tab, Macro	
	Gui, Add, GroupBox, w185 h175 section, Minerals
		Gui, Add, Checkbox, xp+10 yp+20  Vmineralon checked%mineralon%, Enable Alert
		Gui, Add, Text, y+10 section w105, Trigger Amount:
			Gui, Add, Edit, Number Right x+5 yp-2 w55 vTT_mineraltrigger
				Gui, Add, UpDown, Range1-20000 Vmineraltrigger, %mineraltrigger%

		Gui, Add, Text,xs y+10 w105, Secondary Warnings:
			Gui, Add, Edit, Number Right x+5 yp-2 w55 vTT_sec_mineral
				Gui, Add, UpDown, Range0-20000 Vsec_mineral, %sec_mineral%

		Gui, Add, Text,xs y+10 w105, Secondary Delay:
			Gui, Add, Edit, Number Right x+5 yp-2 w55 vTT_additional_delay_minerals
				Gui, Add, UpDown, Range1-20000 Vadditional_delay_minerals, %additional_delay_minerals%

		Gui, Add, Text, X%XTabX% y+5 w125, Spoken Warning:
			Gui, Add, Edit, w165 Vw_mineral center, %w_mineral%		

	Gui, Add, GroupBox, x%OriginTabX% y+20  w185 h205, Gas
		Gui, Add, Checkbox, xp+10 yp+20  Vgas_on checked%gas_on%, Enable Alert

		Gui, Add, Text, y+10 section w105, Trigger Amount:
			Gui, Add, Edit, Number Right x+5 yp-2 w55 vTT_gas_trigger
				Gui, Add, UpDown, Range1-20000 Vgas_trigger, %gas_trigger%

		Gui, Add, Text,xs y+10 w105, Secondary Warnings:
			Gui, Add, Edit, Number Right x+5 yp-2 w55 vTT_sec_gas
				Gui, Add, UpDown, Range0-20000 Vsec_gas, %sec_gas%

		Gui, Add, Text,xs y+10 w105, Secondary Delay:
			Gui, Add, Edit, Number Right x+5 yp-2 w55 vTT_additional_delay_gas
				Gui, Add, UpDown, Range1-20000 Vadditional_delay_gas, %additional_delay_gas%

		Gui, Add, Text, xs y+5 w125, Spoken Warning:
			Gui, Add, Edit, w165 Vw_gas center, %w_gas%		

	Gui, Add, GroupBox, y%OriginTaby% X+35 w185 h175 section Vmacro_R_TopGroup, Idle Worker	;h185
	GuiControlGet, macro_R_TopGroup, Pos, macro_R_TopGroup

		Gui, Add, Checkbox, xp+10 yp+20  Vidleon checked%idleon%, Enable Alert
		Gui, Add, Text, y+10 section w105, Trigger Amount:
			Gui, Add, Edit, Number Right x+5 yp-2 w55 vTT_idletrigger
				Gui, Add, UpDown, Range1-20000 Vidletrigger, %idletrigger%

		Gui, Add, Text,xs y+10 w105, Secondary Warnings:
			Gui, Add, Edit, Number Right x+5 yp-2 w55 vTT_sec_idle
				Gui, Add, UpDown, Range0-20000 Vsec_idle, %sec_idle%

		Gui, Add, Text,xs y+10 w105, Secondary Delay:
			Gui, Add, Edit, Number Right x+5 yp-2 w55 vTT_additional_idle_workers
				Gui, Add, UpDown, Range1-20000 Vadditional_idle_workers, %additional_idle_workers%

		Gui, Add, Text, xs y+5 w125, Spoken Warning:
			Gui, Add, Edit, w165 Vw_idle center, %w_idle%	

Gui, Tab, Macro2
	;Gui, Add, GroupBox, y+20 x%macro_R_TopGroupX% w185 h205, Worker Production	
	Gui, Add, GroupBox, w185 h270, Worker Production	

		Gui, Add, Checkbox, xp+10 yp+20  Vworkeron checked%workeron%, Enable Alert
		Gui, Add, Text, y+10 section w105, Time without Production - Zerg:
			Gui, Add, Edit, Number Right x+5 yp+2 w55 vTT_workerproduction_time
				Gui, Add, UpDown, Range1-20000 Vworkerproduction_time, %workerproduction_time%

		Gui, Add, Text, xs y+20 w105, Time without Production - T && P:
			Gui, Add, Edit, Number Right x+5 yp+2 w55 vTT_workerProductionTPIdle
				Gui, Add, UpDown, Range1-20000 VworkerProductionTPIdle, %workerProductionTPIdle%

		Gui, Add, Text,xs y+20 w105, Secondary Warnings:
			Gui, Add, Edit, Number Right x+5 yp-2 w55 vTT_sec_workerprod
				Gui, Add, UpDown, Range0-20000 Vsec_workerprod, %sec_workerprod%

		Gui, Add, Text,xs y+10 w105, Secondary Delay:
			Gui, Add, Edit, Number Right x+5 yp-2 w55 vTT_additional_delay_worker_production
				Gui, Add, UpDown, Range1-20000 Vadditional_delay_worker_production, %additional_delay_worker_production%

		Gui, Add, Text, xs y+10 w85, Terran Warning:
			Gui, Add, Edit, yp x+0 W85 Vw_workerprod_T center, %w_workerprod_T%	

		Gui, Add, Text, xs y+5 w85,Protoss Warning:
			Gui, Add, Edit, yp x+0 W85 Vw_workerprod_P center, %w_workerprod_P%	

		Gui, Add, Text, xs y+5 w85,Zerg Warning:
			Gui, Add, Edit, yp x+0 W85 Vw_workerprod_Z center, %w_workerprod_Z%	

Gui, Tab, Warpgates
Gui, Add, GroupBox, y+20 w410 h135, Forgotten Gateway/Warpgate Warning

		Gui, Add, Checkbox,xp+10 yp+25 Vwarpgate_warn_on checked%warpgate_warn_on%, Enable Alert

		Gui, Add, Text, y+10 section w105, Warning Count:
			Gui, Add, Edit,  Number Right x+5 yp-2 w55 vTT_sec_warpgate
				Gui, Add, UpDown, Range1-20000 Vsec_warpgate, %sec_warpgate%		

		Gui, Add, Text,  x%xtabx% y+10  w105, Warning Delay:
			Gui, Add, Edit,  Number Right x+5 yp-2 w55 vTT_delay_warpgate_warn
				Gui, Add, UpDown, Range1-20000 Vdelay_warpgate_warn, %delay_warpgate_warn%			

		Gui, Add, Text, x%xtabx% y+10  w105, Secondary Delay:
			Gui, Add, Edit,  Number Right x+5 yp-2 w55 vTT_delay_warpgate_warn_followup
				Gui, Add, UpDown, Range1-20000 Vdelay_warpgate_warn_followup, %delay_warpgate_warn_followup%						

		Gui, Add, Text, x+30 ys section w75, Warning:
			Gui, Add, Edit, yp-2 x+10 w110 Vw_warpgate center, %w_warpgate%		


Gui, Add, Tab2,w440 h%guiMenuHeight% X%MenuTabX%  Y%MenuTabY% vMisc_TAB, Misc Abilities
	Gui, Add, GroupBox, w240 h150 section, Misc Hotkeys

		Gui, Add, Text, xp+10 yp+30 w80, Worker Count:
			Gui, Add, Edit, Readonly yp-2 x+5 w100  center Vworker_count_local_key , %worker_count_local_key%
				Gui, Add, Button, yp-2 x+5 gEdit_hotkey v#worker_count_local_key,  Edit

		Gui, Add, Text, X%XTabX% yp+35 w80, Enemy Workers:
			Gui, Add, Edit, Readonly yp-2 x+5 w100  center Vworker_count_enemy_key , %worker_count_enemy_key%
				Gui, Add, Button, yp-2 x+5 gEdit_hotkey v#worker_count_enemy_key,  Edit		

		Gui, Add, Text, X%XTabX% yp+35 w80, Trainer On/Off:
			Gui, Add, Edit, Readonly yp-2 x+5 w100  center Vwarning_toggle_key , %warning_toggle_key%
				Gui, Add, Button, yp-2 x+5 gEdit_hotkey v#warning_toggle_key,  Edit

		Gui, Add, Text, X%XTabX% yp+35 w80, Ping Map:
			Gui, Add, Edit, Readonly yp-2 x+5 w100  center Vping_key , %ping_key%
				Gui, Add, Button, yp-2 x+5 gEdit_hotkey v#ping_key,  Edit

	Gui, Add, GroupBox, x+20 ys w160 h150, Detect Spawning Races

		Gui, Add, Checkbox,xp+10 yp+30 Vrace_reading checked%race_reading%, Enable
		Gui, Add, Checkbox, y+10 vAuto_Read_Races checked%Auto_Read_Races%, Run on match start
		Gui, Add, Checkbox, y+10 Vrace_speech checked%race_speech%, Speak Races
		Gui, Add, Checkbox, y+10 Vrace_clipboard checked%race_clipboard%, Copy to Clipboard

		Gui, Add, Text, yp+25 w20, Hotkey:
			Gui, Add, Edit, Readonly yp-2 x+5 w65  center Vread_races_key , %read_races_key%
				Gui, Add, Button, yp-2 x+5 gEdit_hotkey v#read_races_key,  Edit

	Gui, Add, GroupBox, xs ys+160 w410 h110, Auto Game Pause - Idle/AFK@Start

	Gui, Add, Checkbox,xp+10 yp+25 Vidle_enable checked%idle_enable%, Enable
	;	Gui, Add, Checkbox,xp+10 yp+25 Vidle_enable checked0 disabled, Enable

		Gui, Add, Text,xp y+10, User Idle Time:
			Gui, Add, Edit,  Number Right x+10 yp-2 w40 vTTidle_time  
				Gui, Add, UpDown, Range1-20000 Vidle_time , %idle_time%
		tmpX := XTabX+200
			Gui, Add, Text, X%tmpX% yp-25 w105, Don't Pause Before:
				Gui, Add, Edit,  Number Right x+5 yp-2 w40 vTTUserIdle_LoLimit 
					Gui, Add, UpDown, Range1-20000 VUserIdle_LoLimit , %UserIdle_LoLimit%

			Gui, Add, Text, X%tmpX% y+10 w105 vTTTUserIdle_HiLimit , Don't Pause After:
				Gui, Add, Edit,  Number Right x+5 yp-2 w40  vTTUserIdle_HiLimit 
					Gui, Add, UpDown, Range1-20000 VUserIdle_HiLimit , %UserIdle_HiLimit%					

		Gui, Add, Text, x%xtabx% y+10, Chat Message:
			Gui, Add, Edit, yp-2 x+10 w310 Vchat_text center, %chat_text%	

	Gui, Add, GroupBox, xs y+20 w410 h110, Misc		
		Gui, Add, Checkbox, x%xtabx% yp+25 VMaxWindowOnStart Checked%MaxWindowOnStart%, Maximise Starcraft on match start		
		Gui, Add, Checkbox, x%xtabx% yp+30 gHumanMouseWarning VHumanMouse Checked%HumanMouse%, Use human like mouse movements
		Gui, Add, Text,yp+20 xp+40, Time range for each mouse movement (ms):
		Gui, Add, Text,yp-10 x450, Lower limit:
		Gui, Add, Edit, Number Right x+25 yp-2 w45 
			Gui, Add, UpDown,  Range1-300 vHumanMouseTimeLo, %HumanMouseTimeLo%, ;these belong to the above edit		Gui, Add, Text,yp xp+10, Lower limit:
		Gui, Add, Text,yp+25 x450, Upper limit:
		Gui, Add, Edit, Number Right x+25 yp-2 w45 
			Gui, Add, UpDown,  Range1-300 vHumanMouseTimeHi, %HumanMouseTimeHi%, ;these belong to the above edit



Gui, Add, Tab2,w440 h%guiMenuHeight% X%MenuTabX%  Y%MenuTabY% vSettings_TAB, Settings				
	Gui, Add, GroupBox, xs ys+5 w161 h110 section, Misc. Settings

		Gui, Add, Text, xp+10 yp+30 w40, Input:
		; only allow pMessage now But will leave this here anyway 
		Gui, Add, DropDownList, x+25 yp-2 w80 Vinput_method Choose1, pMessage

		Gui, Add, Text, xs+10 yp+30 w40, KeyDelay:
		Gui, Add, Edit, Number Right x+50 yp-2 w45 vTT_pKeyDelay
			Gui, Add, UpDown,  Range-1-300 vpKeyDelay, %pKeyDelay%


		Gui, Add, Checkbox,xs+10 yp+30 Vauto_update checked%auto_update%, Auto Check For Updates

	Gui, Add, GroupBox, xs yp+30 w161 h170, Key Blocking
		Gui, Add, Checkbox,xp+10 yp+25 vBlockingStandard checked%BlockingStandard%, Standard Keys	
		Gui, Add, Checkbox, y+10 vBlockingFunctional checked%BlockingFunctional%, Functional F-Keys 	
		Gui, Add, Checkbox, y+10 vBlockingNumpad checked%BlockingNumpad%, Numpad Keys	
		Gui, Add, Checkbox, y+10 vBlockingMouseKeys checked%BlockingMouseKeys%, Mouse Buttons	
		Gui, Add, Checkbox, y+10 vBlockingMultimedia checked%BlockingMultimedia%, Mutimedia Buttons	
		Gui, Add, Checkbox, y+10 vLwinDisable checked%LwinDisable%, Disable Left Windows Key

	Gui, Add, GroupBox, xs yp+35 w161 h60, Empty
/*
	Gui, Add, GroupBox, xs yp+35 w161 h60, Unit Deselection
		Gui, Add, Text, xp+10 yp+25, Sleep Time:
		Gui, Add, Edit, Number Right x+25 yp-2 w45 vTT_DeselectSleepTime
			Gui, Add, UpDown,  Range0-300 vDeselectSleepTime, %DeselectSleepTime%,
*/

	Gui, Add, GroupBox, Xs+171 ys w245 h110, Volume
		Gui, Add, Text, xp+10 yp+30 w45, Speech:
			Gui, Add, Slider, ToolTip  NoTicks w140 x+2 yp-2  Vspeech_volume, %speech_volume%
				Gui, Add, Button, x+5 yp w30 h23 vTest_VOL_Speech gTest_VOL, Test

		Gui, Add, Text, xs+181 y+15 w45, Overall:
			Gui, Add, Slider, ToolTip  NoTicks w140 x+2 yp-2  VprogramVolume, %programVolume%
				Gui, Add, Button, x+5 yp w30 h23 vTest_VOL_All gTest_VOL, Test

	Gui, Add, GroupBox, Xs+171 ys+116 w245 h170, Debugging
		Gui, Add, Button, xp+10 yp+30  Gg_ListVars w75 h25,  List Variables
		Gui, Add, Button, xp yp+30  Gg_GetDebugData w75 h25,  Debug Data

	Gui, Add, GroupBox, Xs+171 ys+290 w245 h60, Emergency Restart Key
		Gui, Add, Text, xp+10 yp+25 w40,Hotkey:
			Gui, Add, Edit, Readonly yp-2 x+15 w100  center vKey_EmergencyRestart , %Key_EmergencyRestart%
				Gui, Add, Button, yp-2 x+15 gEdit_hotkey v#Key_EmergencyRestart,  Edit	

	Gui, Add, GroupBox, Xs ys+360 w161 h60, Custom Program Name
	Gui, Add, Text, xp+10 yp+25 w40,Name:
		Gui, Add, Edit, yp-2 x+5 w100  center vMTCustomProgramName, %MTCustomProgramName%


	Gui, Add, GroupBox, Xs+171 ys+360 w245 h60, Custom Icon
		;	Gui, Add, Edit, Readonly yp-2 x+15 w100  center vKey_EmergencyRestart , %Key_EmergencyRestart%

			A_Iscompiled ? icon := A_ScriptFullPath : icon := "Starcraft-2-32x32.ico"
			Gui, Add, Picture,  xp+35 yp+18 vMTIconPreview gG_MTChageIcon w35 h-1, %icon%
			Gui, Add, Button, x+30 yp+10 vMTChageIconButton Gg_MTChageIcon, Change 
			Gui, Add, Button, x+10 vMTChageIconDefaultButton Gg_MTChageIconDefault, Default 
			;Gui, Add, Edit, Readonly yp-2 xp-90 w80 Hidden vMTCustomIcon , %MTCustomIcon% ; invis and used to store the name

Gui, Add, Tab2,w440 h%guiMenuHeight% X%MenuTabX%  Y%MenuTabY% vDetection_TAB, Detection List
	loop, parse, l_GameType, `,
	{
		BAS_on_%A_LoopField% := alert_array[A_LoopField, "Enabled"]
		BAS_copy2clipboard_%A_LoopField% := alert_array[A_LoopField, "Clipboard"]
	}
	Gui, Add, GroupBox, w130 h65 section, 1v1
		Gui, Add, Checkbox, X%XTabX% yp+20 vBAS_on_1v1 checked%BAS_on_1v1%, Enable Warnings
		Gui, Add, Checkbox, y+10 vBAS_copy2clipboard_1v1 checked%BAS_copy2clipboard_1v1%, Copy To Clipboard		
	Gui, Add, GroupBox, xs yp+45 w130 h65, 2v2
		Gui, Add, Checkbox, X%XTabX% yp+20 vBAS_on_2v2 checked%BAS_on_2v2%, Enable Warnings
		Gui, Add, Checkbox, y+10 vBAS_copy2clipboard_2v2 checked%BAS_copy2clipboard_2v2%, Copy To Clipboard
	Gui, Add, GroupBox, ys x+25 w130 h65 section, 3v3	
		Gui, Add, Checkbox, xp+10 yp+20 vBAS_on_3v3 checked%BAS_on_3v3%, Enable Warnings	 
		Gui, Add, Checkbox, y+10 vBAS_copy2clipboard_3v3 checked%BAS_copy2clipboard_3v3%, Copy To Clipboard
	Gui, Add, GroupBox, xs yp+45 w130 h65, 4v4
		Gui, Add, Checkbox,xp+10 yp+20 vBAS_on_4v4 checked%BAS_on_4v4%, Enable Warnings	
		Gui, Add, Checkbox, y+10 vBAS_copy2clipboard_4v4 checked%BAS_copy2clipboard_4v4%, Copy To Clipboard
	Gui, Add, GroupBox, ys x+25 w130 h65, FFA	
		Gui, Add, Checkbox, xp+10 yp+20 vBAS_on_FFA checked%BAS_on_FFA%, Enable Warnings	 
		Gui, Add, Checkbox, y+10 vBAS_copy2clipboard_FFA checked%BAS_copy2clipboard_FFA%, Copy To Clipboard
		tmp_xGUIlocation := XTabX - 10
	Gui, Add, GroupBox, X%tmp_xGUIlocation% y+120 w275 h55, Playback Last Alert			
		Gui, Add, Text, xp+10 yp+25 w40,Hotkey:
			Gui, Add, Edit, Readonly yp-2 x+5 w100  center vPlayback_Alert_Key , %Playback_Alert_Key%
				Gui, Add, Button, yp-2 x+5 gEdit_hotkey v#Playback_Alert_Key,  Edit	
	Gui, Font, s10
	Gui, Add, Button, center xs-145 yp+50 w275 h60 gAlert_List_Editor vAlert_List_Editor, Launch Alert List Editor
	Gui, Font,

Gui, Add, Tab2,w440 h%guiMenuHeight% X%MenuTabX%  Y%MenuTabY% vBug_TAB, Report Bug
	Gui, Add, Text, y+20 section, Your Email Address:%A_Space%%A_Space%%A_Space%%A_Space%%A_Space%(optional) 
	Gui, Add, Edit, xp+50 y+10 w350 vReport_Email,
	Gui, Add, Text, xp-50 y+10, Problem Description:


	BugText =  
(

A return email address is REQUIRED if you are looking for a follow up to your query.

Bugs may not occur on all systems, so please be as SPECIFIC as possible when describing the problem.

Screenshots and replays may be attached below.

(please remove this text when filling in this form).

)
	Gui, Add, Edit, xp+50 y+10 w350 h160 vReport_TXT, %BugText%

	GUI, Add, ListView, xp y+15 w350 H100 vEmailAttachmentListViewID, Attachments
	LV_Add("", A_ScriptDir "\" config_file) ;includes the MT_Config.ini file ; this can not be removed by the user	
	LV_ModifyCol()  ; Auto-size all columns to fit their contents
	Gui, Add, Button, xp-40 yp+30 w25 h25 gg_AddEmailAttachment, +
	Gui, Add, Button, xp yp+35 w25 h25 gg_RemoveEmailAttachment, -
	Gui, Add, Button, vB_Report gB_Report xp+180 y+18 w80 h50, Report

Gui, Add, Tab2, w440 h%guiMenuHeight% X%MenuTabX%  Y%MenuTabY% vChronoBoost_TAB, Settings||Structures
Gui, Tab, Settings	
	Gui, Add, GroupBox, w200 h190 y+20 section, SC2 Keys && Control Groups			
		Gui, Add, Text, xp+10 yp+25 , Stored Selection Control Group:
			Gui, Add, Edit, Readonly xp+25 y+10  w100  center vCG_control_group , %CG_control_group%
				Gui, Add, Button, yp-2 x+5 gEdit_SendHotkey v#CG_control_group,  Edit				
		Gui, Add, Text, xs+10 yp+35 ,Nexus Control Group:
			Gui, Add, Edit, Readonly xp+25 y+10  w100  center vCG_nexus_Ctrlgroup_key , %CG_nexus_Ctrlgroup_key%
				Gui, Add, Button, yp-2 x+5 gEdit_SendHotkey v#CG_nexus_Ctrlgroup_key,  Edit		
		Gui, Add, Text, xs+10 yp+35 ,Chrono Boost Key:
			Gui, Add, Edit, Readonly xp+25 y+10  w100  center vchrono_key , %chrono_key%
				Gui, Add, Button, yp-2 x+5 gEdit_SendHotkey v#chrono_key,  Edit	

	Gui, Add, GroupBox, ys x+40  w200 h190 section, Misc. Settings				
		tmpx := MenuTabX + 25
		Gui, Add, Text, xp+10 yp+35, Sleep time (ms):
		Gui, Add, Edit, Number Right xp+120 yp-2 w45 vTT_ChronoBoostSleep 
			Gui, Add, UpDown,  Range0-1000 vChronoBoostSleep, %ChronoBoostSleep%						
		Gui, Add, Text, xs+10 yp+35, Chrono Remainder:`n    (1 = 25 mana)
		Gui, Add, Edit, Number Right xp+120 yp-2 w45 vTT_CG_chrono_remainder 
			Gui, Add, UpDown,  Range0-1000 vCG_chrono_remainder, %CG_chrono_remainder%		


Gui, Tab, Structures	
	Gui, Add, GroupBox, w285 h60 y+20 section, Warpgates && Gateways
		Gui, Add, Checkbox, xp+10 yp+25 vCG_Enable checked%CG_Enable%, Enable
		Gui, Add, Text, x+20 yp w40,Hotkey:
			Gui, Add, Edit, Readonly yp-2 x+5 w100  center vCast_ChronoGate_Key , %Cast_ChronoGate_Key%
				Gui, Add, Button, yp-2 x+5 gEdit_hotkey v#Cast_ChronoGate_Key,  Edit				

	Gui, Add, GroupBox, w285 h60 xs yp+55 section, Forges	
		Gui, Add, Checkbox, xp+10 yp+25 vChronoBoostEnableForge checked%ChronoBoostEnableForge%, Enable
		Gui, Add, Text, x+20 yp w40,Hotkey:
			Gui, Add, Edit, Readonly yp-2 x+5 w100  center vCast_ChronoForge_Key , %Cast_ChronoForge_Key%
				Gui, Add, Button, yp-2 x+5 gEdit_hotkey v#Cast_ChronoForge_Key,  Edit	

	Gui, Add, GroupBox, w285 h60 xs yp+55 section, Stargates	
		Gui, Add, Checkbox, xp+10 yp+25 vChronoBoostEnableStargate checked%ChronoBoostEnableStargate%, Enable
		Gui, Add, Text, x+20 yp w40,Hotkey:
			Gui, Add, Edit, Readonly yp-2 x+5 w100  center vCast_ChronoStargate_Key , %Cast_ChronoStargate_Key%
				Gui, Add, Button, yp-2 x+5 gEdit_hotkey v#Cast_ChronoStargate_Key,  Edit

		Gui, Add, GroupBox, w285 h60 xs yp+55 section, RoboticsFacility	
		Gui, Add, Checkbox, xp+10 yp+25 vChronoBoostEnableRoboticsFacility checked%ChronoBoostEnableRoboticsFacility%, Enable
		Gui, Add, Text, x+20 yp w40,Hotkey:
			Gui, Add, Edit, Readonly yp-2 x+5 w100  center vCast_ChronoRoboticsFacility_Key , %Cast_ChronoRoboticsFacility_Key%
				Gui, Add, Button, yp-2 x+5 gEdit_hotkey v#Cast_ChronoRoboticsFacility_Key,  Edit					


	Gui, Add, GroupBox, w285 h60 xs yp+55 section, Nexi	
		Gui, Add, Checkbox, xp+10 yp+25 vChronoBoostEnableNexus checked%ChronoBoostEnableNexus%, Enable
		Gui, Add, Text, x+20 yp w40,Hotkey:
			Gui, Add, Edit, Readonly yp-2 x+5 w100  center vCast_ChronoNexus_Key , %Cast_ChronoNexus_Key%
				Gui, Add, Button, yp-2 x+5 gEdit_hotkey v#Cast_ChronoNexus_Key,  Edit	

	Gui, Add, Button, x460 y430 gg_ChronoRulesURL w130, Rules/Criteria

	;	Gui, Add, Text, X%tmpx% y+85 cRed, Note:
	;	Gui, Add, Text, x+10 yp+0, If gateways exist, they will be chrono boosted after the warpgates. 

Gui, Add, Tab2,w440 h%guiMenuHeight% X%MenuTabX%  Y%MenuTabY% vAutoGroup_TAB, Terran||Protoss|Zerg|Delay|Info	
Short_Race_List := "Terr|Prot|Zerg"
loop, parse, Short_Race_List, |
{
	if (A_LoopField = "Terr")
	{	Gui, Tab, Terran
		Tmp_LongRace := "Terran"
	}
	Else if (A_LoopField = "Prot")
	{	Gui, Tab, Protoss
		Tmp_LongRace := "Protoss"
	}
	Else 
	{	Gui, Tab, Zerg
		Tmp_LongRace := "Zerg"
	}
	checked := A_UnitGroupSettings["AutoGroup", Tmp_LongRace, "Enabled"]
	AGX := MenuTabX + 20, AGY := MenuTabY +50
	Gui, Add, Checkbox, X%AGX%  Y%AGY%  vAG_Enable_%A_LoopField% checked%checked%, Enable Auto Grouping
	checked := A_UnitGroupSettings["LimitGroup", Tmp_LongRace, "Enabled"]
;	Gui, Add, Checkbox, X%AGX% Y+10 v%Tmp_LongRace%_LimitGroup checked%checked%, Restrict Unit Grouping
	Gui, Add, Text, yp X540 Center, Restrict Unit`nGrouping:
	XLeft := XTabX - 10
	loop, 10
	{		
		if (10 = i := A_Index)	; done like this so 0 comes after 9
			i := 0
		Units := A_UnitGroupSettings[Tmp_LongRace, i]

		Gui, add, text, y+20 X%XLeft%, Group %i%
		Gui, Add, Edit, yp-2 x+10 w280  center r1 vAG_%Tmp_LongRace%%i%, %Units%
	;	Gui, Add, Edit, yp-2 x+10 w280  center r1 vAG_%A_LoopField%%i%, %Units%
	;	Gui, Add, Button, yp-2 x+10 gEdit_AG v#AG_%A_LoopField%%i%,  Edit ;old
		Gui, Add, Button, yp-2 x+10 gEdit_AG v#AG_%Tmp_LongRace%%i%,  Edit
		checked := A_UnitGroupSettings["LimitGroup", Tmp_LongRace, i,"Enabled"]
		Gui, Add, Checkbox, yp+4 x+20 vLG_%Tmp_LongRace%%i% checked%checked%
	}	
}				
Gui, Tab, Info
	Gui, Font, s10
	Gui, add, text, x+25 y+15 w380,Auto Unit Grouping:`n`nThis function will add (shift + control group) selected units to their preselected control groups, providing:`n`n• One of the selected units in not in said control group.`n• All of the selected units 'belong'  in this (preselected) control group.`nUnits are added after the control, shift, alt, && windows keys are released.
	Gui, add, text, y+20 w380,Restrict Unit Grouping:`n`nIf units have been specified for a particular control group, only these preselected units can be added to that control group.`n`nThis prevents users erroneously adding units to control groups.`n`n Any unit can be added to a blank control group.
	Gui, Font, s10 BOLD
	Gui, add, text, X%XTabX% y+25 cRED , Note:
	Gui, Font, s10 norm
	Gui, add, text, xp+45 yp+15 w340, Auto and Restrict Unit grouping functions are not exclusive, i.e. they can be used together or alone!
	Gui, Font, s9 norm
Gui, Tab, Delay
	Gui, Add, Text, x+25 y+35, Delay (ms):
	Gui, Add, Edit, Number Right x+20 yp-2 w45 vTT_AGDelay 
	Gui, Add, UpDown,  Range0-1500 vAG_Delay, %AG_Delay%


Gui, Add, Tab2,w440 h%guiMenuHeight% X%MenuTabX%  Y%MenuTabY% vAutoWorker_TAB, Auto||Info		
Gui, Tab, Auto
	Gui, Add, Text, x+25 y+35 section, Toggle State:

		Gui, Add, Edit, Readonly yp-2 x+10 center w65 vToggleAutoWorkerState_Key gedit_hotkey, %ToggleAutoWorkerState_Key%
	Gui, Add, Button, yp-2 x+10 gEdit_hotkey v#ToggleAutoWorkerState_Key,  Edit ;have to use a trick eg '#' as cant write directly to above edit var, or it will activate its own label!

	Gui, Add, Text, xs+220 ys w85, APM Protection:
		Gui, Add, Edit, Number Right x+15 yp-2 w50 vTT_AutoWorkerAPMProtection
				Gui, Add, UpDown,  Range0-100000 vAutoWorkerAPMProtection, %AutoWorkerAPMProtection%		

;	Gui, Add, Text, xs+220 yp+25 w85, Queue While Supply Blocked:			
	Gui, Add, Checkbox, xs+220 y+10 vAutoWorkerQueueSupplyBlock Checked%AutoWorkerQueueSupplyBlock%, Queue While Supply Blocked

	thisXTabX := XTabX + 12
	Gui, Add, GroupBox, xs Y+10 w370 h150 section, Terran 
		Gui, Add, Checkbox, xp+10 yp+25 vEnableAutoWorkerTerranStart Checked%EnableAutoWorkerTerranStart%, Enable

		Gui, Add, Text, X%thisXTabX% y+15 w100, Base Ctrl Group:
			if (Base_Control_Group_T_Key = 0)
				droplist_var := 10
			else 
				droplist_var := Base_Control_Group_T_Key  	; i have a dropdown menu now so user has to put a number, cant use another key as I use this to check the control groups
			Gui, Add, DropDownList,  xs+130 yp w45 center vBase_Control_Group_T_Key Choose%droplist_var%, 1|2|3|4||5|6|7|8|9|0

		Gui, Add, Text, X%thisXTabX% yp+35 w100, Storage Ctrl Group:
			if (AutoWorkerStorage_T_Key = 0)
				droplist_var := 10
			else 
				droplist_var := AutoWorkerStorage_T_Key  	; i have a dropdown menu now so user has to put a number, cant use another key as I use this to check the control groups
			Gui, Add, DropDownList,  xs+130 yp w45 center vAutoWorkerStorage_T_Key Choose%droplist_var%, 1|2|3|4|5|6|7||8|9|0


		Gui, Add, Text, X%thisXTabX% yp+35 w100, Make SCV Key:
		Gui, Add, Edit, Readonly yp-2 x+1 w65 center vAutoWorkerMakeWorker_T_Key, %AutoWorkerMakeWorker_T_Key%
			Gui, Add, Button, yp-2 x+10 gEdit_SendHotkey v#AutoWorkerMakeWorker_T_Key,  Edit

		Gui, Add, Text, xs+240 ys+55, Max SCVs:
			Gui, Add, Edit, Number Right x+15 yp-2 w45 vTT_AutoWorkerMaxWorkerTerran
					Gui, Add, UpDown,  Range1-100000 vAutoWorkerMaxWorkerTerran, %AutoWorkerMaxWorkerTerran%		

		Gui, Add, Text, xs+240 yp+35, Max SCVs:`n(Per Base)
			Gui, Add, Edit, Number Right x+15 yp w45 vTT_AutoWorkerMaxWorkerPerBaseTerran
					Gui, Add, UpDown,  Range1-100000 vAutoWorkerMaxWorkerPerBaseTerran, %AutoWorkerMaxWorkerPerBaseTerran%	


	Gui, Add, GroupBox, xs ys+170 w370 h150 section, Protoss 
		Gui, Add, Checkbox, xp+10 yp+25 vEnableAutoWorkerProtossStart Checked%EnableAutoWorkerProtossStart%, Enable

		Gui, Add, Text, X%thisXTabX% y+15 w100, Base Ctrl Group:
			if (Base_Control_Group_P_Key = 0)
				droplist_var := 10
			else 
				droplist_var := Base_Control_Group_P_Key  	; i have a dropdown menu now so user has to put a number, cant use another key as I use this to check the control groups
			Gui, Add, DropDownList, xs+130 yp w45 center vBase_Control_Group_P_Key Choose%droplist_var%, 1|2|3|4||5|6|7|8|9|0

		Gui, Add, Text, X%thisXTabX% yp+35 w100, Storage Ctrl Group:
			if (AutoWorkerStorage_P_Key = 0)
				droplist_var := 10
			else 
				droplist_var := AutoWorkerStorage_P_Key  	; i have a dropdown menu now so user has to put a number, cant use another key as I use this to check the control groups
			Gui, Add, DropDownList,  xs+130 yp w45 center vAutoWorkerStorage_P_Key Choose%droplist_var%, 1|2|3|4|5|6|7||8|9|0	

		Gui, Add, Text, X%thisXTabX% yp+35 w100, Make Probe Key:
		Gui, Add, Edit, Readonly yp-2 x+1 w65 center vAutoWorkerMakeWorker_P_Key, %AutoWorkerMakeWorker_P_Key%
			Gui, Add, Button, yp-2 x+10 gEdit_SendHotkey v#AutoWorkerMakeWorker_P_Key,  Edit

		Gui, Add, Text, xs+240 ys+55, Max Probes:
			Gui, Add, Edit, Number Right x+15 yp-2 w45 vTT_AutoWorkerMaxWorkerProtoss
					Gui, Add, UpDown,  Range1-100000 vAutoWorkerMaxWorkerProtoss, %AutoWorkerMaxWorkerProtoss%		

		Gui, Add, Text, xs+240 yp+35, Max Probes:`n(Per Base)
			Gui, Add, Edit, Number Right x+15 yp w45 vTT_AutoWorkerMaxWorkerPerBaseProtoss
					Gui, Add, UpDown,  Range1-100000 vAutoWorkerMaxWorkerPerBaseProtoss, %AutoWorkerMaxWorkerPerBaseProtoss%	

Gui, Tab, Info
		gui, font, norm bold s10
		Gui, Add, Text, X%OriginTabX% y+15 cFF0000, Note:
		gui, font, norm s11

		gui, Add, Text, w400 y+15, When trying to lift a Command Centre or Orbital, or convert a Command Centre into an orbital, an SCV will likely already be queued.
		gui, Add, Text, w400 y+15, There's no need to toggle (turn off) this function, simply  select the building/base (so that only ONE unit is selected e.g. the CC) and press the 'ESCAPE' button to cancel the queued worker.
		gui, Add, Text, w400 y+15, This will temporarily disable the function for four seconds - providing adequate time to convert or lift the Command Centre.
		gui, Add, Text, w400 y+15, This also works if you need to cancel a probe to make a mumma ship core.

		gui, Add, Text, w400 y+20, Although you will most likely not notice this, workers will not be produced while:
		gui, Add, Text, w400 y+5, • The control, alt, shift, or windows keys are held down.
		gui, Add, Text, w400 y+5, • A spell is being cast (includes attack)
		gui, Add, Text, w400 y+5, • The construction card i.e. the basic or advanced building card is displayed.
		gui, Add, Text, w400 y+5, • A non-self unit is selected e.g. a mineral patch or an enemy/allied unit (or no unit is selected).

		gui, font, norm s10
		gui, font, 		

Gui, Add, Tab2, w440 h%guiMenuHeight% X%MenuTabX%  Y%MenuTabY% vMiscAutomation_TAB, Select Army||Spread|Remove Unit|
Gui, Tab, Select Army
	Gui, Add, Checkbox, y+25 x+15 vSelectArmyEnable Checked%SelectArmyEnable% , Enable Select Army Function		
	Gui, Add, Checkbox, yp+25 xp+15 section vModifierBeepSelectArmy Checked%ModifierBeepSelectArmy%, Beep if modifier is held down		
	Gui, Add, Text, yp+35, Hotkey: **
	Gui, Add, Edit, Readonly yp-2 xs+85 center w65 vcastSelectArmy_key gedit_hotkey, %castSelectArmy_key%
	Gui, Add, Button, yp-2 x+10 gEdit_hotkey v#castSelectArmy_key,  Edit ;have to use a trick eg '#' as cant write directly to above edit var, or it will activate its own label!

	Gui, Add, Text, Xs yp+35 w70, Select Army:
	Gui, Add, Edit, Readonly yp-2 xs+85 w65 center vSc2SelectArmy_Key , %Sc2SelectArmy_Key%
		Gui, Add, Button, yp-2 x+10 gEdit_SendHotkey v#Sc2SelectArmy_Key,  Edit

	Gui, Add, Text, Xs yp+35, Sleep time (ms):
	Gui, Add, Edit, Number Right xp+145 yp-2 w45 vTT_SleepSelectArmy
	Gui, Add, UpDown,  Range0-100 vSleepSelectArmy, %SleepSelectArmy%
	Gui, Add, Checkbox, Xs yp+35 vSelectArmyControlGroupEnable Checked%SelectArmyControlGroupEnable%, Control group the units
	Gui, Add, Text, Xs+30 yp+20 w70, Ctrl Group:
	Gui, Add, Edit, Readonly yp-2 xs+85 w65 center vSc2SelectArmyCtrlGroup , %Sc2SelectArmyCtrlGroup%
		Gui, Add, Button, yp-2 x+10 gEdit_SendHotkey v#Sc2SelectArmyCtrlGroup,  Edit
	Gui, Add, Text, Xs yp+40, Deselect These Units:
	Gui, Add, Checkbox, Xs+30 yp+20 vSelectArmyDeselectXelnaga Checked%SelectArmyDeselectXelnaga%, Xelnaga (tower) units
	Gui, Add, Checkbox, Xs+30 yp+20 vSelectArmyDeselectPatrolling Checked%SelectArmyDeselectPatrolling%, Patrolling units
	Gui, Add, Checkbox, Xs+30 yp+20 vSelectArmyDeselectHoldPosition Checked%SelectArmyDeselectHoldPosition%, On hold position
	Gui, Add, Checkbox, Xs+30 yp+20 vSelectArmyDeselectFollowing Checked%SelectArmyDeselectFollowing%, On follow command
	Gui, add, text, Xs y+15, Units:
	Gui, Add, Edit, yp-2 x+10 w300 section  center r1 vl_DeselectArmy, %l_DeselectArmy%
	Gui, Add, Button, yp-2 x+10 gEdit_AG v#l_DeselectArmy,  Edit

	Gui, Add, Text, X420 y115 w160, ** This function will work better && FAR more reliably if this hotkey does not contain a modifier i.e Shift, Ctrl, or Alt.`n`n'F1' or 'F2' should work well.

Gui, Tab, Spread
	Gui, Add, Checkbox, y+25 x+25 vSplitUnitsEnable Checked%SplitUnitsEnable% , Enable Spread Unit Function	
	Gui, Add, Text, section yp+35, Hotkey:
	Gui, Add, Edit, Readonly yp-2 xs+85 center w65 vcastSplitUnit_key gedit_hotkey, %castSplitUnit_key%
	Gui, Add, Button, yp-2 x+10 gEdit_hotkey v#castSplitUnit_key,  Edit
	Gui, Add, Text, Xs yp+35 w70, Ctrl Group Storage:
	Gui, Add, Edit, Readonly yp xs+85 w65 center vSplitctrlgroupStorage_key , %SplitctrlgroupStorage_key%
		Gui, Add, Button, yp x+10 gEdit_SendHotkey v#SplitctrlgroupStorage_key,  Edit
	Gui, Add, Text, Xs yp+35, Sleep time (ms):
	Gui, Add, Edit, Number Right xp+145 yp-2 w45 vTT_SleepSplitUnits
	Gui, Add, UpDown,  Range0-100 vSleepSplitUnits, %SleepSplitUnits%
	Gui, Add, Text, Xs yp+100 w360, This can be used to spread your workers when being attack by hellbats/hellions.`n`nWhen 30`% of the selected units are worksers, the units will be spread over a much larger area
	Gui, Add, Text, Xs yp+80 w360, Note: When spreading army/attacking units this is designed to spread your units BEFORE the engagement - Dont use it while being attacked!`n`n****This is in a very beta stage and will be improved later***

Gui, Tab, Remove Unit
	Gui, Add, Checkbox, y+25 x+25 vRemoveUnitEnable Checked%RemoveUnitEnable% , Enable Remove Unit Function	
	Gui, Add, Text, section yp+35, Hotkey:
	Gui, Add, Edit, Readonly yp-2 xs+85 center w65 vcastRemoveUnit_key gedit_hotkey, %castRemoveUnit_key%
	Gui, Add, Button, yp-2 x+10 gEdit_hotkey v#castRemoveUnit_key,  Edit
	Gui, Add, Text, Xs yp+70 w380, This removes the first unit (top left of selection card) from the selected units.`n`nThis is very usefuly for 'cloning' workers to geisers or sending 1 ling towards a group of banelings etc.

Gui, Add, Tab2, w440 h%guiMenuHeight% X%MenuTabX%  Y%MenuTabY% vAutoMine_TAB, Settings||Hotkeys|
Gui, Tab, Settings	
	Gui, Add, GroupBox, y+20 w195 h300 section, Settings
		Gui, Add, Checkbox, xp+10 yp+30 vAuto_mine checked%auto_mine%, Enable
		Gui, Add, Checkbox, yp+25 vAuto_mineMakeWorker checked%Auto_mineMakeWorker%, Make Worker
		Gui, Add, Checkbox, yp+25 vAuto_Mine_Set_CtrlGroup checked%Auto_Mine_Set_CtrlGroup%, Set Base Ctrl Group

		Gui, Add, Text,y+20 w85, Split Type: 
		if WorkerSplitType
			droplist3_var := substr(WorkerSplitType, 0, 1)
		else droplist3_var := 1
		Gui, Add, DropDownList, x+35 yp-2 w45 vWorkerSplitType Choose%droplist3_var%, 6x1|3x2||2x3	

		Gui, Add, Text, X%XTabX% y+20 w65, Method:
		droplist3_var := AutoMineMethod = "MiniMap" ? 2 : 1		
		Gui, Add, DropDownList, x+35 yp-2 w65 gg_GuiSetupAutoMine vAutoMineMethod Choose%droplist3_var%, Normal||MiniMap	

		Gui, Add, Text, X%XTabX% y+20 w85, Sleep (ms):castSplitUnit_key
		Gui, Add, Edit, Number Right x+35 yp-2 w45 vAuto_Mine_Sleep2
			Gui, Add, UpDown, Range1-100000 vTT_Auto_Mine_Sleep2, %Auto_Mine_Sleep2%		

		Gui, Add, Text, X%XTabX% y+20 w85, Input Delay (ms):
			Gui, Add, Edit, Number Right X+35 yp-2 w45 vTT_AM_KeyDelay
				Gui, Add, UpDown,  Range0-10 vAM_KeyDelay, %AM_KeyDelay%			

		Gui, Add, Text,X%XTabX% y+20 w85, Start Mining at (s): 
		Gui, Add, Edit, Number Right x+35 yp-2 w45 vStart_Mine_Time
			Gui, Add, UpDown, Range0-100000, %Start_Mine_Time%	
		Gui, Font, s10
		Gui, Add, Text,Xs y+40 , Note: The "Normal" method will only function at 1920 x 1080 resolution.
		Gui, Font,
		XMenu := 390
		Gui, Add, GroupBox, ys x%XMenu% w195 h300 vAMGUI1, MiniMap Settings
		Gui, Font, underline
		Gui, Add, Text, xp+10 yp+20 vAMGUI2, Pixel Colour
		Gui, Font
		XMenu += 30
		Gui, Add, Text, x%XMenu% y+15 w55 vAMGUI3, Alpha:
			Gui, Add, Edit, Number Right x+35 yp-2 w45 vAM_MiniMap_PixelColourAlpha, %AM_MiniMap_PixelColourAlpha%
		Gui, Add, Text, x%XMenu% y+15 w55 vAMGUI4, Red:
			Gui, Add, Edit, Number Right x+35 yp-2 w45 vAM_MiniMap_PixelColourRed, %AM_MiniMap_PixelColourRed%
		Gui, Add, Text, x%XMenu% y+15 w55 vAMGUI5, Green:
			Gui, Add, Edit, Number Right x+35 yp-2 w45 vAM_MiniMap_PixelColourGreen, %AM_MiniMap_PixelColourGreen%
		Gui, Add, Text, x%XMenu% y+15 w55 vAMGUI6, Blue:
			Gui, Add, Edit, Number Right x+35 yp-2 w45 vAM_MinsiMap_PixelColourBlue, %AM_MinsiMap_PixelColourBlue%

		Gui, Add, Button, x%XMenu% y+15 w60 h23 gg_GuiSetupResetPixelColour v#ResetPixelColour,  Reset	
		Gui, Add, Button, x+30 yp  w60 h23 gg_FindTestPixelColourMsgbox v#FindPixelColour,  Find	

		XMenu -= 20
		Gui, Add, Text,  x%XMenu% y+20 w85 vAMGUI7, Variance:
			Gui, Add, Edit, Number Right x+35 yp-2 w45 vAM_MiniMap_PixelVariance
			Gui, Add, UpDown, Range0-100 vTT_AM_MiniMap_PixelVariance, %AM_MiniMap_PixelVariance%	
		Gui, Add, Button, xp-60 y+15 w60 h23 gg_PixelColourFinderHelpFile vAMGUI8,  About	
		gosub, g_GuiSetupAutoMine	;hide/show the minimap items



Gui, Tab, Hotkeys	
Gui, Add, GroupBox, xs y+20 w235 h210 section, SC2 HotKeys
		Gui, Add, Text, X%XTabX% yp+25  w80 , Idle Worker:
		Gui, Add, Edit, Readonly yp-2 x+10 w80  center vIdle_Worker_Key , %Idle_Worker_Key%
				Gui, Add, Button, yp-2 x+10 w30 h23 gEdit_SendHotkey v#Idle_Worker_Key,  Edit			
		Gui, Add, Text, X%XTabX% yp+30  w80, Gather Minerals:
		Gui, Add, Edit, Readonly yp-2 x+10 w80  center vGather_Minerals_key , %Gather_Minerals_key%
				Gui, Add, Button, yp-2 x+10 w30 h23 gEdit_SendHotkey v#Gather_Minerals_key,  Edit		
		Gui, Add, Text, X%XTabX% yp+30 w80 , Base Ctrl Group:
		Gui, Add, Edit, Readonly yp-2 x+10 w80  center vBase_Control_Group_Key , %Base_Control_Group_Key%
				Gui, Add, Button, yp-2 x+10 w30 h23 gEdit_SendHotkey v#Base_Control_Group_Key,  Edit	
		Gui, Add, Text, X%XTabX% yp+30  w80, Make SCV:
		Gui, Add, Edit, Readonly yp-2 x+10 w80  center vMake_Worker_T_Key , %Make_Worker_T_Key%
				Gui, Add, Button, yp-2 x+10 w30 h23 gEdit_SendHotkey v#Make_Worker_T_Key,  Edit			
		Gui, Add, Text, X%XTabX% yp+30  w80, Make Probe:
		Gui, Add, Edit, Readonly yp-2 x+10 w80  center vMake_Worker_P_Key , %Make_Worker_P_Key%
				Gui, Add, Button, yp-2 x+10 w30 h23 gEdit_SendHotkey v#Make_Worker_P_Key,  Edit						
		Gui, Add, Text, X%XTabX% yp+30  w80, Select Larva:
		Gui, Add, Edit, Readonly yp-2 x+10 w80  center vMake_Worker_Z1_Key , %Make_Worker_Z1_Key%
				Gui, Add, Button, yp-2 x+10 w30 h23 gEdit_SendHotkey v#Make_Worker_Z1_Key,  Edit							
		Gui, Add, Text, X%XTabX% yp+30  w80, Make Drone:
		Gui, Add, Edit, Readonly yp-2 x+10 w80  center vMake_Worker_Z2_Key , %Make_Worker_Z2_Key%
				Gui, Add, Button, yp-2 x+10 w30 h23 gEdit_SendHotkey v#Make_Worker_Z2_Key,  Edit	
		Gui, Font, s11
		Gui, Add, Text, X%XTabX% yp+60, Note:
		Gui, Add, Text, xp+40  w340, Ensure the correct ('backspace') base camera key is set in the "SC2 Keys Section" (below Auto Mine - on the left).
		Gui, Font, s10
		Gui, Font,
Gui, Add, Tab2, w440 h%guiMenuHeight% X%MenuTabX%  Y%MenuTabY% vHome_TAB, Home||Emergency

Gui, Tab, Home
		Gui, Add, Button, y+30 gTrayUpdate w150, Check For Updates
		Gui, Add, Button, y+20 gB_HelpFile w150 vSillyGUIControlIdentVariable2, Read The Help File
		Gui, Add, Button, y+20 gB_ChangeLog w150, Read The ChangeLog
		Gui, Add, Checkbox,y+30 Vlaunch_settings checked%launch_settings%, Show this menu on startup	

		GuiControlGet, HomeButtonLocation, Pos, SillyGUIControlIdentVariable2 ;

		Gui, Add, Button, X360 y%HomeButtonLocationY% gHomepage w150, Homepage
		Gui, Add, Button, y+20 gG_buyBeer w150, Buy Me a Beer

		Gui, Add, Picture, x170 y320 h90 w90 gP_Protoss_Joke vProtossPic, %A_Temp%\Protoss90.png
		Gui, Add, Picture, x+50 yp-20 h128 w128 gP_Terran_Joke vTerranPic , %A_Temp%\Terran90.png
		Gui, Add, Picture, x+50  yp+20 h90 w90 gP_zerg_Joke vZergPic, %A_Temp%\Zerg90.png

Gui, Tab, Emergency	
	Gui, Font, S16 CDefault bold UNDERLINE, Verdana
	Gui, Add, Text, x+20 y+30 center cRed, IMPORTANT
	Gui, Font, s10 norm 
	Gui, Add, Text, xp y+30 w405, This program blocks user input and simulates keystrokes.`nOn RARE occasions it is possible that you will lose keyboard and mouse input OR a key e.g. ctrl, shift, or alt becomes 'stuck' down.`n`nIn this event, use the EMERGENCY HOTKEY!`nWhen pressed it should release any 'stuck' key and restore user input.`n`nIf this fails, press the hotkey THREE times in quick succession to have the program restart.`nIf you're still having a problem, then the key is likely physically stuck down.
	Gui, Font, S18 CDefault bold, Verdana
	Gui, Add, Text,xp+10 y+25 cRed, Windows Key && Spacebar`n        (Right)
	Gui, Font, norm 
	Gui, Font,
	Gui, Add, Text, xp y+25 w405, The deult key can be changed via the 'settings' Tab on the left.

Gui, Add, Tab2, w440 h%guiMenuHeight% X%MenuTabX%  Y%MenuTabY% vMiniMap_TAB, MiniMap||MiniMap2|Overlays|Hotkeys|Info

Gui, Tab, MiniMap


	currentGuiTabX := XTabX -5
	groupboxGuiX := CurrentGuiTabX - 10
	Gui, add, GroupBox, y+10 x%groupboxGuiX% w410 h195, General

		Gui, Add, Checkbox, X%CurrentGuiTabX% Yp+25 vDrawMiniMap Checked%DrawMiniMap% gG_GuiSetupDrawMiniMapDisable, Enable MiniMap Hack
		Gui, Add, Checkbox, xp Y+9 vDrawSpawningRaces Checked%DrawSpawningRaces%, Display Spawning Races
		Gui, Add, Checkbox, Y+9 vDrawAlerts Checked%DrawAlerts%, Display Alerts
		Gui, Add, Checkbox, Y+9 vHostileColourAssist Checked%HostileColourAssist%, Hostile Colour Assist
		Gui, Add, Checkbox, Y+9 vDrawUnitDestinations Checked%DrawUnitDestinations%, Unit Destinations
		Gui, Add, Checkbox, Y+9 vDrawPlayerCameras Checked%DrawPlayerCameras%, Player Cameras

		GuiControlGet, tmpOutput, Pos, DrawMiniMap

		xTmp := tmpOutputX + tmpOutputW + 95
		Gui, Add, Checkbox, x%xTmp% Y%tmpOutputY% vHighlightInvisible Checked%HighlightInvisible%, Highlight Invisible units
		Gui, add, text, y+12 Xp+20, Colour:
		Gui, Add, Picture, xp+60 yp-4 w50 h22 0xE HWND_UnitHighlightInvisibleColour v#UnitHighlightInvisibleColour gColourSelector ;0xE required for GDI
		paintPictureControl(_UnitHighlightInvisibleColour, UnitHighlightInvisibleColour)	

		Gui, Add, Checkbox, x%xTmp% Y+10 vHighlightHallucinations Checked%HighlightHallucinations%, Highlight hallucinated units
		Gui, add, text, y+12 Xp+20, Colour:
		Gui, Add, Picture, XP+60 yp-4 w50 h22 0xE HWND_UnitHighlightHallucinationsColour v#UnitHighlightHallucinationsColour gColourSelector ;0xE required for GDI
		paintPictureControl(_UnitHighlightHallucinationsColour, UnitHighlightHallucinationsColour)	

		GuiControlGet, tmpOutput, Pos, DrawPlayerCameras
		xguiUnitBox :=CurrentGuiTabX + 50
		tmpY := tmpOutputY + 30

		Gui, add, text, y%tmpY% X%CurrentGuiTabX% w45, Exclude:
		Gui, Add, Edit, yp-2 x%xguiUnitBox% w300  center r1 vUnitHighlightExcludeList, %UnitHighlightExcludeList%
		Gui, Add, Button, yp x+10 gEdit_AG v#UnitHighlightExcludeList,  Edit 

;	Gui, add, text, y+15 X%CurrentGuiTabX%, Custom Unit Highlights:
	
	Gui, add, GroupBox, y+25 x%groupboxGuiX% w410 h200, Custom Unit Highlights

		Gui, add, text, yp+30 X%CurrentGuiTabX%, Unit:
		Gui, Add, Edit, yp-2 x%xguiUnitBox% w300 section  center r1 vUnitHighlightList1, %UnitHighlightList1%
		Gui, Add, Button, yp x+10 gEdit_AG v#UnitHighlightList1,  Edit
		Gui, add, text, y+9 X%CurrentGuiTabX%, Colour:
		Gui, Add, Picture, xs yp-4 w300 h22 0xE HWND_UnitHighlightList1Colour v#UnitHighlightList1Colour gColourSelector ;0xE required for GDI
		paintPictureControl(_UnitHighlightList1Colour, UnitHighlightList1Colour)	

		Gui, add, text, y+12 X%CurrentGuiTabX%, Unit:
		Gui, Add, Edit, yp-2 x%xguiUnitBox% w300  center r1 vUnitHighlightList2, %UnitHighlightList2%
		Gui, Add, Button, yp x+10 gEdit_AG v#UnitHighlightList2,  Edit
		Gui, add, text, y+9 X%CurrentGuiTabX%, Colour:
		Gui, Add, Picture, xs yp-4 w300 h22 0xE HWND_UnitHighlightList2Colour v#UnitHighlightList2Colour gColourSelector ;0xE required for GDI
		paintPictureControl(_UnitHighlightList2Colour, UnitHighlightList2Colour)		
		Gui, add, text, y+12 X%CurrentGuiTabX%, Unit:
		Gui, Add, Edit, yp-2 x%xguiUnitBox% w300  center r1 vUnitHighlightList3, %UnitHighlightList3%
		Gui, Add, Button, yp x+10 gEdit_AG v#UnitHighlightList3,  Edit
		Gui, add, text, y+9 X%CurrentGuiTabX%, Colour:
		Gui, Add, Picture, xs yp-4 w300 h22 0xE HWND_UnitHighlightList3Colour v#UnitHighlightList3Colour gColourSelector ;0xE required for GDI
		paintPictureControl(_UnitHighlightList3Colour, UnitHighlightList3Colour)




		Gui, Font, s8 
		Gui, add, text, x+3 yp+5, <--- Click Me
		Gui, Font, norm 


Gui, Tab, MiniMap2
	
/*
	Gui, Add, Checkbox, X%CurrentGuiTabX% Y+15 vHighlightInvisible Checked%HighlightInvisible%, Highlight Invisible units

		Gui, add, text, y+12 Xp+20, Colour:
		Gui, Add, Picture, xp+60 yp-4 w50 h22 0xE HWND_UnitHighlightInvisibleColour v#UnitHighlightInvisibleColour gColourSelector ;0xE required for GDI
		paintPictureControl(_UnitHighlightInvisibleColour, UnitHighlightInvisibleColour)	

	Gui, Add, Checkbox, X%CurrentGuiTabX% Y+10 vHighlightHallucinations Checked%HighlightHallucinations%, Highlight hallucinated units
		Gui, add, text, y+12 Xp+20, Colour:
		Gui, Add, Picture, XP+60 yp-4 w50 h22 0xE HWND_UnitHighlightHallucinationsColour v#UnitHighlightHallucinationsColour gColourSelector ;0xE required for GDI
		paintPictureControl(_UnitHighlightHallucinationsColour, UnitHighlightHallucinationsColour)	
*/
	;	Gui, add, text, y+40 X%CurrentGuiTabX%, Additional Custom Unit Highlights:
		Gui, add, GroupBox, y+15 x%groupboxGuiX% w410 h270, Additional Custom Unit Highlights

			Gui, add, text, yp+30 X%CurrentGuiTabX%, Unit:
			Gui, Add, Edit, yp-2 x%xguiUnitBox% w300  center r1 vUnitHighlightList4, %UnitHighlightList4%
			Gui, Add, Button, yp x+10 gEdit_AG v#UnitHighlightList4,  Edit
			Gui, add, text, y+9 X%CurrentGuiTabX%, Colour:
			Gui, Add, Picture, xs yp-4 w300 h22 0xE HWND_UnitHighlightList4Colour v#UnitHighlightList4Colour gColourSelector ;0xE required for GDI
			paintPictureControl(_UnitHighlightList4Colour, UnitHighlightList4Colour)	


			Gui, add, text, y+12 X%CurrentGuiTabX%, Unit:
			Gui, Add, Edit, yp x%xguiUnitBox% w300  center r1 vUnitHighlightList5, %UnitHighlightList5%
			Gui, Add, Button, yp-1 x+10 gEdit_AG v#UnitHighlightList5,  Edit
			Gui, add, text, y+9 X%CurrentGuiTabX%, Colour:
			Gui, Add, Picture, xs yp-4 w300 h22 0xE HWND_UnitHighlightList5Colour v#UnitHighlightList5Colour gColourSelector ;0xE required for GDI
			paintPictureControl(_UnitHighlightList5Colour, UnitHighlightList5Colour)	


			Gui, add, text, y+12 X%CurrentGuiTabX%, Unit:
			Gui, Add, Edit, yp x%xguiUnitBox% w300  center r1 vUnitHighlightList6, %UnitHighlightList6%
			Gui, Add, Button, yp-1 x+10 gEdit_AG v#UnitHighlightList6,  Edit
			Gui, add, text, y+9 X%CurrentGuiTabX%, Colour:
			Gui, Add, Picture, xs yp-4 w300 h22 0xE HWND_UnitHighlightList6Colour v#UnitHighlightList6Colour gColourSelector ;0xE required for GDI
			paintPictureControl(_UnitHighlightList6Colour, UnitHighlightList6Colour)	

			Gui, add, text, y+12 X%CurrentGuiTabX%, Unit:
			Gui, Add, Edit, yp x%xguiUnitBox% w300  center r1 vUnitHighlightList7, %UnitHighlightList7%
			Gui, Add, Button, yp-1 x+10 gEdit_AG v#UnitHighlightList7,  Edit
			Gui, add, text, y+9 X%CurrentGuiTabX%, Colour:
			Gui, Add, Picture, xs yp-4 w300 h22 0xE HWND_UnitHighlightList7Colour v#UnitHighlightList7Colour gColourSelector ;0xE required for GDI
			paintPictureControl(_UnitHighlightList7Colour, UnitHighlightList7Colour)	

Gui, Tab, Overlays
		;Gui, add, text, y+20 X%XTabX%, Display Overlays:
		Gui, Add, GroupBox, y+30 x+20  w170 h235 section, Display Overlays:
		Gui, Add, Checkbox, xp+10 yp+25 vDrawIncomeOverlay Checked%DrawIncomeOverlay% , Income Overlay
		Gui, Add, Checkbox, xp y+15 vDrawResourcesOverlay Checked%DrawResourcesOverlay% , Resource Overlay
		Gui, Add, Checkbox, xp y+15 vDrawArmySizeOverlay Checked%DrawArmySizeOverlay% , Army Size Overlay
		Gui, Add, Checkbox, xp y+15 vDrawWorkerOverlay Checked%DrawWorkerOverlay% , Local Harvester Count
		Gui, Add, Checkbox, xp y+15 vDrawIdleWorkersOverlay Checked%DrawIdleWorkersOverlay%, Idle Worker Count
		Gui, Add, Checkbox, xp y+15 vDrawLocalPlayerColourOverlay Checked%DrawLocalPlayerColourOverlay%, Local Player Colour
		Gui, Add, Checkbox, xp y+15 vDrawUnitOverlay Checked%DrawUnitOverlay%, Unit Panel
		
;		Gui, Add, Text, xp-10 y+40, Custom Unit Filter:
		;Gui, Font, s10
		Gui, Add, Button, center xp-10 y+40 w120 h40 Gg_GUICustomUnitPanel, UnitPanel Filter
		;Gui, Font,


		Gui, Add, GroupBox, ys XS+205 w170 h235, Overlays Misc:
		Gui, Add, Checkbox, yp+25 xp+10 vOverlayBackgrounds Checked%OverlayBackgrounds% , Show Icon Background		
		Gui, Add, Text, yp+30 w80, Player Identifier:
		if OverlayIdent in 0,1,2,3
			droplist3_var := OverlayIdent + 1
		Else droplist3_var := 3 

		Gui, Add, DropDownList, xp+20 yp+25 vOverlayIdent Choose%droplist3_var%, Hidden|Name (White)|Name (Coloured)|Coloured Race Icon
		
		Gui, Add, Text, yp+35 xp-20, Refresh Rates (ms):
		Gui, Add, Text, y+15  XS+215, General:
			Gui, Add, Edit, Number Right xp+80 yp-2 w55 vTT_OverlayRefresh
				Gui, Add, UpDown,  Range50-5000 vOverlayRefresh, %OverlayRefresh%
		Gui, Add, Text, yp+35 XS+215, Unit Panel:
			Gui, Add, Edit, Number Right xp+80 yp-2 w55 vTT_UnitOverlayRefresh
				Gui, Add, UpDown,  Range150-15000 vUnitOverlayRefresh, %UnitOverlayRefresh%
		Gui, Add, Text, XS+215 yp+35, MiniMap:
			Gui, Add, Edit, Number Right xp+80 yp-2 w55 vTT_MiniMapRefresh
				Gui, Add, UpDown,  Range150-1500 vMiniMapRefresh, %MiniMapRefresh%					

Gui, Tab, Hotkeys 
	
	Gui, add, GroupBox, y+25 w280 h330, Overlay Hotkeys

		Gui, Add, Text, section xp+15 yp+25, Temp. Hide MiniMap:
		Gui, Add, Edit, Readonly yp-2 xp+120 center w85 vTempHideMiniMapKey gedit_hotkey, %TempHideMiniMapKey%
		Gui, Add, Button, yp-2 x+10 gEdit_hotkey v#TempHideMiniMapKey,  Edit 	

		Gui, Add, Text, xs yp+35, Toggle Minimap:
		Gui, Add, Edit, Readonly yp-2 xp+120 center w85 vToggleMinimapOverlayKey gedit_hotkey, %ToggleMinimapOverlayKey%
		Gui, Add, Button, yp-2 x+10 gEdit_hotkey v#ToggleMinimapOverlayKey,  Edit 	

		Gui, Add, Text, xs yp+35, Toggle Income:
		Gui, Add, Edit, Readonly yp-2 xp+120 center w85 vToggleIncomeOverlayKey gedit_hotkey, %ToggleIncomeOverlayKey%
		Gui, Add, Button, yp-2 x+10 gEdit_hotkey v#ToggleIncomeOverlayKey,  Edit 		

		Gui, Add, Text, xs yp+35, Toggle Resources:
		Gui, Add, Edit, Readonly yp-2 xp+120 center w85 vToggleResourcesOverlayKey gedit_hotkey, %ToggleResourcesOverlayKey%
		Gui, Add, Button, yp-2 x+10 gEdit_hotkey v#ToggleResourcesOverlayKey,  Edit 		

		Gui, Add, Text, xs yp+35, Toggle Army Size:
		Gui, Add, Edit, Readonly yp-2 xp+120 center w85 vToggleArmySizeOverlayKey gedit_hotkey, %ToggleArmySizeOverlayKey%
		Gui, Add, Button, yp-2 x+10 gEdit_hotkey v#ToggleArmySizeOverlayKey,  Edit 		

		Gui, Add, Text, xs yp+35, Toggle Workers:
		Gui, Add, Edit, Readonly yp-2 xp+120 center w85 vToggleWorkerOverlayKey gedit_hotkey, %ToggleWorkerOverlayKey%
		Gui, Add, Button, yp-2 x+10 gEdit_hotkey v#ToggleWorkerOverlayKey,  Edit 		

		Gui, Add, Text, xs yp+35, Toggle Unit Panel:
		Gui, Add, Edit, Readonly yp-2 xp+120 center w85 vToggleUnitOverlayKey gedit_hotkey, %ToggleUnitOverlayKey%
		Gui, Add, Button, yp-2 x+10 gEdit_hotkey v#ToggleUnitOverlayKey,  Edit 		

		Gui, Add, Text, xs yp+35, Cycle Overlays:
		Gui, Add, Edit, Readonly yp-2 xp+120 center w85 vCycleOverlayKey gedit_hotkey, %CycleOverlayKey%
		Gui, Add, Button, yp-2 x+10 gEdit_hotkey v#CycleOverlayKey,  Edit 		

		Gui, Add, Text, xs yp+35, Cycle Identifier:
		Gui, Add, Edit, Readonly yp-2 xp+120 center w85 vToggleIdentifierKey gedit_hotkey, %ToggleIdentifierKey%
		Gui, Add, Button, yp-2 x+10 gEdit_hotkey v#ToggleIdentifierKey,  Edit 		
		gui, font, Underline
		Gui, Add, Text, xs yp+35, *Adjust Overlays:
		gui, font, Norm 
		Gui, Add, Edit, Readonly yp-2 xp+120 center w85 vAdjustOverlayKey gedit_hotkey, %AdjustOverlayKey%
		Gui, Add, Button, yp-2 x+10 gEdit_hotkey v#AdjustOverlayKey,  Edit 
		Gui, Add, Text, xs y+25, * See 'Info' Tab for Instructions		

Gui, Tab, Info
;	Gui, Add, Text, section x+10 y+15,	
	Gui, add, GroupBox, section y+15 w405 h395
	Gui, Font, s10 CDefault bold, Verdana
	Gui, Add, Text, xs+10 yp+25, Adjusting Overlays:	
	Gui, Font, s10 norm 
	
text = 
( 
Hold down (and do not release) the "Adjust Overlays" Hotkey (%AdjustOverlayKey% key).
	
You will hear a beep - all the overlays are now adjustable.When you're done, release the "Adjust Overlays" Hotkey. 
)
	Gui, Add, Text, xs+25 y+10 w370, %text%
	Gui, Font, CDefault bold, Verdana
	Gui, Add, Text, xs+10 y+20, Moving:
	Gui, Font, s10 norm 
	Gui, Add, Text, xs+25 y+10 w370, Simply left click somewhere on the text or graphics of the overlay (not a blank area) and drag the overlay to its new position.
 	Gui, Font, CDefault bold, Verdana
 	Gui, Add, Text, xs+10 y+20, Resizing:
 	Gui, Font, norm 
 	Gui, Add, Text, xs+25 y+10 w370, Simply left click somewhere on the overlay and then rotate the mouse wheel forward/backward.

	Gui, Font, s9 CDefault bold, Verdana
	Gui, Add, Text, center xs+10 y+25 w370 cRed, The MiniMap and Overlays will only work when SC is in 'Windowed (fullscreen)' mode.
	Gui, Font, s10 norm 

unhidden_menu := "Home_TAB"

GuiControl, Hide, Home_TAB 
GuiControl, Hide, Injects_TAB 
GuiControl, Hide, AutoGroup_TAB 
GuiControl, Hide, AutoWorker_TAB 
GuiControl, Hide, ChronoBoost_TAB 
GuiControl, Hide, AutoMine_TAB 
GuiControl, Hide, MiscAutomation_TAB 
GuiControl, Hide, Keys_TAB
GuiControl, Hide, Warnings_TAB
GuiControl, Hide, Misc_TAB 
GuiControl, Hide, Detection_TAB
GuiControl, Hide, Settings_TAB
GuiControl, Hide, Bug_TAB
GuiControl, Hide, MiniMap_TAB

ZergPic_TT := "The OP race"
TerranPic_TT := "The artist formerly known as being OP"
ProtossPic_TT := "The slightly less OP race"
auto_inject_alert_TT := "This alert will sound X seconds after your last auto inject, prompting you to inject again."
auto_inject_time_TT := TT_auto_inject_time_TT :=  "This is in 'SC2' Seconds."
#cast_inject_key_TT := cast_inject_key_TT := "When pressed the program will inject all of your hatcheries.`n`nThis Hotkey is ONLY active while playing as zerg!"
Auto_inject_sleep_TT := "Lower this to make the inject round faster, BUT this will make it more obvious that it is being automated!"
CanQueenMultiInject_TT := "During minimap injects (and auto-Injects) a queen may attempt to inject multiple hatcheries providing:`nShe is the only nearby queen and she has enough energy.`n`nThis may increase the chance of having queens go walkabouts (especially during an auto inject) - but so far I have not observed this during testing. "
Inject_RestoreSelection_TT := "This will store your currently selected units in a control group, which is recalled at the end inject round."
Inject_RestoreScreenLocation_TT := "This will save your screen/camera location and restore it at the end of the inject round.`n`n"
						. "This option only affects the 'backspace' methods."

Inject_SleepVariance_TT := Edit_Inject_SleepVariance_TT := "This will increase each sleep period by a random percentage from 0% up to this set value.`n`n"
						. "This does not affect the auto-injects."						

HotkeysZergBurrow_TT := #HotkeysZergBurrow_TT := "Please ensure this matches the 'Burrow' hotkey in SC2 & that you only have one active hotkey to burrow units i.e. No alternate burrow key!`n`nThis is used during auto injects to help prevent accidentally burrowing queens due to the way windows/SC2 buffers these repeated keypresses."
Simulation_speed_TT := "How fast the mouse moves during inject rounds. 0 = Fastest - try 1,2 or 3 if you're having problems."
Drag_origin_TT := "This sets the origin of the box drag to the top left or right corners. Hence making it compatible with observer panel hacks.`n`nThis is only used by the 'Backspace' method."
BI_create_camera_pos_x_TT := #BI_create_camera_pos_x_TT := "The hotkey used to save a camera location."
							. "`n`nThis should correspond to one of the five SC2 'create camera' hotkeys."
							. "`nPlease set this to a camera hotkey which you don't actually use."
							. "`n`nThis is used by both backspace inject methods."


BI_camera_pos_x_TT := #BI_camera_pos_x_TT :=  "The hotkey used to invoke the above saved camera location."
											. "`n`nThis is used by both backspace inject methods."


manual_inject_time_TT := "The time between alerts."
inject_start_key_TT := "The hotkey used to start or stop the timer."
inject_reset_key_TT := "The hotkey used to reset (or start) the timer."
Alert_List_Editor_TT := "Use this to edit and create alerts for any SC2 unit or building."
#base_camera_TT := base_camera_TT := "The key used to cycle between hatcheries/bases."
#NextSubgroupKey_TT := NextSubgroupKey_TT := "The key used to cycle forward though a selection group."
#control_group_TT := control_group_TT := "Set this to a control group you DON'T use - It stores your unit selection during an inject round."
create_camera_pos_x_TT := #create_camera_pos_x_TT := "The hotkey used to 'save' a camera location. - Ensure this isn't one you use."
#camera_pos_x_TT := camera_pos_x_TT := "The hotkey associated with the 'create/save' camera location above."
spawn_larva_TT := #spawn_larva_TT := Tspawn_larva_TT := "Please set the key or alternate key for ""spawn larvae"" in SC2 to "" e "". - This prevents problems!"
sub_lowerdelta_TT := TT_sub_lowerdelta_TT := "A warning will be heard when the 'free' supply drops below this number. (while your supply is below the 'Low Range Cutoff')."
sub_middelta_TT := TT_sub_middelta_TT := "A warning will be heard when the 'free' supply drops below this number. (While your supply is greater than the 'Low Range Cutoff' but less than the 'Middle Range Cutoff')."
sub_upperdelta_TT := TT_sub_upperdelta_TT := "A warning will be heard when the 'free' supply drops below this number. (While your supply is greater than the 'Middle Range Cutoff' but less than the 'Upper Range Cutoff')."
above_upperdelta_TT := TT_above_upperdelta_TT := "A warning will be heard when the 'free' supply drops below this number. (While your supply is greater than the 'Upper Range Cutoff')."
minimum_supply_TT := TT_minimum_supply_TT := "Alerts are only active while your supply is above this number."

w_supply_TT := w_warpgate_TT := w_workerprod_T_TT := w_workerprod_P_TT := w_workerprod_Z_TT := w_gas_TT := w_idle_TT := w_mineral_TT := "This text is spoken during a warning."
TT_sec_workerprod_TT := sec_workerprod_TT := sec_idle_TT := sec_gas_TT := sec_mineral_TT := sec_supply_TT := TT_sec_supply_TT := TT_sec_mineral_TT := TT_sec_gas_TT := TT_sec_idle_TT := TT_sec_warpgate_TT := sec_warpgate_TT := "Set how many additional warnings are to be given after the first initial warning (assuming the resource does not fall below the inciting value) - the warnings then turn off."
additional_delay_supply_TT := TT_additional_delay_supply_TT := additional_delay_minerals_TT := additional_delay_gas_TT := additional_idle_workers_TT 
:= TT_additional_delay_minerals_TT := TT_additional_delay_gas_TT := TT_additional_idle_workers_TT := TT_delay_warpgate_warn_followup_TT := delay_warpgate_warn_followup_TT := "This sets the delay between the initial warning, and the additional/follow-up warnings. (in real seconds)"
TT_additional_delay_worker_production_TT := additional_delay_worker_production_TT := "This sets the delay between the initial warning, and the additional/follow-up warnings. (in SC2 seconds)"
TT_workerproduction_time_TT := workerproduction_time_TT := "This only applies to Zerg.`nA warning will be heard if a drone has not been produced in this amount of time (SC2 seconds)."
delay_warpgate_warn_TT := "If a gateway has been unconverted for this period of time (real seconds) then a warning will be made."
warpgate_warn_on_TT := "Enables warnings for unconverted gateways. Note: The warnings become active after your first gateway is converted."
idletrigger_TT := gas_trigger_TT := mineraltrigger_TT := TT_mineraltrigger_TT := TT_gas_trigger_TT := TT_idletrigger_TT := "The required amount to invoke a warning."
supplylower_TT := TT_supplylower_TT := TT_supplymid_TT := supplymid_TT := supplyupper_TT := TT_supplyupper_TT := "Dictactes when the next or previous supply delta/threashold is used."
TT_workerProductionTPIdle_TT := workerProductionTPIdle_TT := "This only applies to Terran & protoss.`nIf all nexi/CC/Orbitals/PFs are idle for this amount of time (SC2 seconds), a warning will be made.`n`nNote: A main is considered idle if it has no worker in production and is not currently flying or morphing."

delay_warpgate_warn_TT := TT_delay_warpgate_warn_TT := "A warning will be heard when an unconverted gateway exists for this period of time.`nThis is in SC/in-game seconds.`n`nNote: An additional delay of up to three (real) seconds can be expected"

 TT_delay_warpgate_warn_followup_TT := delay_warpgate_warn_followup_TT := "This sets the delay between the initial warning and the additional/follow-up warnings.`n`nNote: This is in SC2 (in game) seconds."
DrawMiniMap_TT := "Draws enemy units on the minimap i.e. A Minimap Hack"
DrawSpawningRaces_TT := "Displays a race icon over the enemies spawning location at the start of the match."

DrawAlerts_TT := "While using the 'detection list' function an 'x' will be briefly displayed on the minimap during a unit warning.`n`nUnconverted gateways will also be marked (if that macro is enabled)."

UnitHighlightExcludeList_TT := #UnitHighlightExcludeList_TT := "These units will not be displayed on the minimap."

loop, 7
{
	UnitHighlightList%A_index%_TT := #UnitHighlightList%A_index%_TT
	:= "Units of this type will be drawn using the specified colour"
 	#UnitHighlightList%A_Index%Colour_TT := "Click Me!`n`nUnits of this type will appear this colour."
}

DrawWorkerOverlay_TT := "Displays your current harvester count with a worker icon"
DrawIdleWorkersOverlay_TT := "While idle workers exist, a worker icon will be displayed with the current idle count.`n`nThe size and position can be changed easily so that it grabs your attention."
DrawUnitOverlay_TT := "Displays the enemies current units.`nThis is similar to the 'observer' panel.`n`nUse the 'unit panel filter' to selectively remove/display units."

ToggleAutoWorkerState_Key_TT := #ToggleAutoWorkerState_Key_TT := "Toggles (enables/disables) this function for the CURRENT match.`n`nWill only work during a match"
AutoWorkerProtectionDelay_TT := TT_AutoWorkerProtectionDelay_TT := "After a round a of workers has been made the function will sleep for this period of time (ms).`nThis helps prevent queueing too many workers.`n`n"
							. "If more than one worker is commonly being queued-up and/or you have a laggy connection perhaps try increasing this value."

AutoWorkerQueueSupplyBlock_TT := "While you are supply blocked a worker will be queued-up.`n"
		. "This aims to make the automation a little more subtle. If disabled, the instant you have free supply all of your bases will make a worker."
		. "`n`nNote: The program won't queue multiple workers while supply blocked."

TT_AutoWorkerAPMProtection_TT := AutoWorkerAPMProtection_TT
:= TT_FInjectAPMProtection_TT := FInjectAPMProtection_TT := "Automations will be delayed while your INSTANTANEOUS APM is greater than this value.`n"
		. "This helps reduce the likelihood of interfering with your game play.`n`nNote: If you're a chronic key spammer who constantly has high APM you may need to increase this value,`n"
		. "otherwise actions may be delayed for too long.`n`n"
		. "Note: With the various program changes and improvements which have been made, this setting is no longer required for automations to function seamlessly `n"
		. "as automations should not interfere with your game play even if you have very high APM.`n"
		. "This is now included as an simple additional user option."

EnableAutoWorkerTerranStart_TT := EnableAutoWorkerProtossStart_TT := "Enables/Disables this function."
AutoWorkerStorage_T_Key_TT := #AutoWorkerStorage_T_Key_TT := AutoWorkerStorage_P_Key_TT := #AutoWorkerStorage_P_Key_TT := "During an automation cycle your selected units will be temporarily stored in this control group.`n`nSpecify a control group that you do NOT use in game."

#Base_Control_Group_T_Key_TT := Base_Control_Group_T_Key_TT := Base_Control_Group_P_Key_TT := #Base_Control_Group_P_Key_TT := "The control group used to store your command centres/orbitals/planetary-fortresses/nexi.`n`n"
						. "Note: Other buildings can also be stored in this control group e.g. engineering bays/forges,`n"
						. "but the first displayed unit in the selection card must be a main base - 99% of the time this will be the case."

AutoWorkerMakeWorker_T_Key_TT := #AutoWorkerMakeWorker_T_Key_TT := "The keyboard hotkey used to build an SCV.`nUsually 'S'."
AutoWorkerMakeWorker_P_Key_TT := #AutoWorkerMakeWorker_P_Key_TT := "The keyboard hotkey used to build a probe.`nUsually 'E'."

TT_AutoWorkerMaxWorkerTerran_TT := TT_AutoWorkerMaxWorkerProtoss_TT := AutoWorkerMaxWorkerTerran_TT := AutoWorkerMaxWorkerProtoss_TT := "Worker production will stop for the remainder of the game when this number of workers exist.`n"
				. "Workers can then be 'sacked' and the function will remain off!`n`nIf you wish to turn it back on, simply use the 'toggle hotkey' twice."
				. "`nNote: For added randomness your final worker count will be within +/- 2 of this value."
TT_AutoWorkerMaxWorkerPerBaseTerran_TT := TT_AutoWorkerMaxWorkerPerBaseProtoss_TT := AutoWorkerMaxWorkerPerBaseTerran_TT := AutoWorkerMaxWorkerPerBaseProtoss_TT :=  "Worker production will stop when this number is exceeded by`n"
			. "the current worker count per the number of fully constructed (and control grouped) main-bases`n"
			. "WHICH are within 8 map units of a gas geyser.`n`n"
			. "Note: A properly situated base is usually 7-7.5 map units from a geyser."

Inject_spawn_larva_TT := #Inject_spawn_larva_TT := "This needs to correspond to your SC2 'spawn larva' button.`n`nThis key is sent during an inject to invoke Zerg's 'spawn larva' ability."

MI_Queen_Group_TT := #MI_Queen_Group_TT := "The queens in this control are used to inject hatcheries.`n`nHence you must add your injecting queens to this control group!"
F_InjectOff_Key_TT := #F_InjectOff_Key_TT := "During a match this hotkey will toggle (either disable or enable) automatic injects."

OverlayIdent_TT := "Changes or disables the method of identifying players in the overlays."

Playback_Alert_Key_TT := #Playback_Alert_Key_TT := "Repeats the previous alert"

worker_count_local_key_TT := "This will read aloud your current worker count."
worker_count_enemy_key_TT := "This will read aloud your enemy's worker count. (only in 1v1)"
warning_toggle_key_TT := "Pauses and resumes the program."
ping_key_TT := "This hotkey will ping the map at the current mouse cursor location."
race_reading_TT := "Reads aloud the enemys' spawning races."
idle_enable_TT := "If the user has been idle for longer than a set period of time (real seconds) then the game will be paused."
TTidle_time_TT := idle_time_TT := "How long the user must be idle for (in real seconds) before the game is paused.`nNote: This value can be higher than the ""Don't Pause After"" parameter!"
TTUserIdle_LoLimit_TT  := UserIdle_LoLimit_TT := "The game can't be paused before this (in game/SC2) time."
TTUserIdle_HiLimit_TT := UserIdle_HiLimit_TT := "The game will not be paused after this (in game/SC2) time."

speech_volume_TT := "The relative volume of the speech engine."
programVolume_TT := "The overall program volume. This affects both the speech volume and the 'beeps'.`n`nNote: This probably has no effect on WindowsXP and below."
speaker_volume_up_key_TT := speaker_volume_down_key_TT := "Changes the windows master volume."
speech_volume_down_key_TT := speech_volume_up_key_TT := "Changes the programs TTS volume."
program_volume_up_key_TT := program_volume_down_key_TT := "Changes the programs overall volume."
input_method_TT := "Sets the method of artificial input.`n"
	. "Post message is now the only available method."
;	. "Technically ""Event"" is the most 'reliable' across systems, but ""Input"" offers considerably better performance, key buffering and will work with almost all systems.`n"
;	. "Using ""Input"" will also reduce the likelihood of the program interfering with user game play during automations`n`n"
;	. "Hence, use ""Input"" unless it doesn't work."
TT_EventKeyDelay_TT := EventKeyDelay_TT := "Sets the mouse and key delay (in ms) used when in SendEvent mode.`nLower values sends keystrokes faster - but setting this too low MAY cause some strokes to be missed.`nCommon values are (-1 to 10).`nNote: These delays are accumulative, and for functions which require numerous keystrokes e.g. split this delay can become quite substantial`n`nSendInput is faster and generally more reliable, hence SendInput should be used if it works on your system."

TT_pKeyDelay_TT := pKeyDelay_TT := "Sets the sleep time (in ms) between individual keystrokes/mousecliks."
					. "`n`nNote: This is an important setting as SC2 often requires a small delay to ensure ALL the keystrokes are processed."
					. "`nIn my experience if this is too low the control-grouping command may be ignored once every few games." 
					. "`nHence, this may prevent unit selections being restored during automations."
					. "`n2 ms works perfectly for me."
					. "`n`nValid values are:"
					. "`n-1: no sleep"
					. "`n 0: Yields the remaining time slice to any other process (if requested)"
					. "`nAny positive integer."

auto_update_TT := "While enabled the program will automatically check for new versions during startup."
launch_settings_TT := "Display the options menu on startup."

HideTrayIcon_TT := "Hides the tray icon and all popups/menus."
TT2_MI_QueenDistance_TT := MI_QueenDistance_TT := "The edge of the hatchery creep is approximately 14`nThis helps prevent queens injecting on remote hatches - It works better with lower numbers"
TT_F_Max_Injects_TT := F_Max_Injects_TT := "The max. number of 'forced' injects which can occur after a user 'F5'/auto-inject.`nSet this to a high number if you want the program to inject for you."
TT_F_Alert_PreTime_TT := F_Alert_PreTime_TT := "The alert will sound X seconds before the forced inject."
TT_F_Sleep_Time_TT := F_Sleep_Time_TT := "The amount of time spent idle after injecting each hatch.`n"
		. "This should be set as low as reliably possible so that the inject rounds are shorter and there is less chance of it affecting your gameplay.`n`n"
		. "This will vary for users, but 0 ms works reliably for me.`n"
		. "If 0 ms is not reliable, try increasing this value in increments of 1 ms."
TT_FInjectHatchFrequency_TT := FInjectHatchFrequency_TT := "How often the larva state of the hatcheries are checked. (In ms/real-time)`nAny uninjected hatches will then be injected.`n`nIncreasing this value will delay injects, that is, a hatch will remain uninjected for longer."
TT_FInjectHatchMaxHatches_TT := FInjectHatchMaxHatches_TT := "The maximum number of hatches to be injected during an inject round"

TT_AM_KeyDelay_TT := AM_KeyDelay_TT := TT_I_KeyDelay_TT := I_KeyDelay_TT := TT_CG_KeyDelay_TT := CG_KeyDelay_TT := "This sets the delay between key/mouse events`nLower numbers are faster, but they may cause problems.`n0-10`n`nWith regards to speed, changing the 'sleep' time will generally have a larger impact."
TT_ChronoBoostSleep_TT := ChronoBoostSleep_TT := "Sets the amount of time that the program sleeps for during each automation cycle.`nThis has a large effect on the speed, and hence how 'human' the automation appears'.`n`n"
		. "If you want instant chronoboosts, a value of 0 ms works reliably for me.`n"
		. "If 0 ms is not reliable for you, try increasing the sleep time by one or two ms. (it doesn't require much)"
CG_chrono_remainder_TT := TT_CG_chrono_remainder_TT := "This is how many full chronoboosts will remain afterwards between all your nexi.`nA setting of 1 will leave 1 full chronoboost (or 25 energy) on one of your nexi."
CG_control_group_TT := Inject_control_group_TT := #CG_control_group_TT := #Inject_control_group_TT := "This stores the currently selected units into a temporary control group, so that the current unit selection may be restored after the automated cycle.`nNote: Ensure that this is set to a control group you do not use."
WorkerSplitType_TT := "Defines how many workers are rallied to each mineral patch."

Auto_inject_sleep_TT := Edit_pos_var_TT := "Sets the amount of time that the program sleeps for during each automation cycle.`nThis has a large effect on the speed, and hence how 'human' the automation appears'.`n`n"
		. "The lowest reliable values will vary for users, but for myself the minimap method can be used with a sleep time of 0 ms.`n"
		. "The backspace methods require at least 8 ms."


AM_MiniMap_PixelColourAlpha_TT := AM_MiniMap_PixelColourRed_TT := AM_MiniMap_PixelColourGreen_TT := AM_MinsiMap_PixelColourBlue_TT := "The ARGB pixel colour of the mini map mineral field."
#ResetPixelColour_TT := "Resets the pixel colour and variance to their default settings."
#FindPixelColour_TT := "This sets the pixel colour for your exact system."
AM_MiniMap_PixelVariance_TT := TT_AM_MiniMap_PixelVariance_TT := "A match will result if  a pixel's colour lies within the +/- variance range.`n`nThis is a percent value 0-100%"
TT_AGDelay_TT := AG_Delay_TT := "The program will wait this period of time before adding the select units to a control group.`nUse this if you want the function to look more 'human'.`n`nNote: This may increase the likelihood of miss-grouping units (especially on slow computers or during large battles with high APM)."
TempHideMiniMapKey_TT := #TempHideMiniMapKey_TT := "This will disable the minimap overlay for three seconds,`nthereby allowing you to determine if you legitimately have vision of a unit or building."
TT_UserMiniMapXScale_TT := TT_UserMiniMapYScale_TT := UserMiniMapYScale_TT := UserMiniMapXScale_TT := "Adjusts the relative size of units on the minimap."
TT_MiniMapRefresh_TT := MiniMapRefresh_TT := "Dictates how frequently the minimap is redrawn"
BlendUnits_TT := "This will draw the units 'blended together', like SC2 does.`nIn other words, units/buildings grouped together will only have one border around all of them"

TT_OverlayRefresh_TT := OverlayRefresh_TT := "Determines how frequently these overlays are refreshed:`nIncome, Resource, Army, Local Harvesters, and Idle Workers."
TT_UnitOverlayRefresh_TT := UnitOverlayRefresh_TT := "Determines how frequently the unit panel is refreshed.`nThis requires more resources than the other overlays and so it has its own refresh rate."

DrawLocalPlayerColourOverlay_TT := "During team games and while using hostile colours (green, yellow, and red) a small circle is drawn which indiactes your local player colour.`n`n"
									. "This is helpful when your allies refer to you by colour."
HostileColourAssist_TT := "During team games while using hostile colours (green, yellow, and red) enemy bases will still be displayed using player colours.`n`n"
						. "This helps when co-ordinating attacks e.g. Let's attack yellow!"

SleepSplitUnit_TT := TT_SleepSplitUnits_TT := TT_SleepSelectArmy_TT := SleepSelectArmy_TT := "Increase this value if the function doesn't work properly`nThis time is required to update the selection buffer."
Sc2SelectArmy_Key_TT := #Sc2SelectArmy_Key_TT := "The in game (SC2) button used to select your entire army.`nDefault is F2"
ModifierBeepSelectArmy_TT := "Will play a beep if a modifer key is being held down.`nModifiers include the ctrl, alt, shift and windows keys."
castSelectArmy_key_TT := #castSelectArmy_key_TT := "The button used to invoke this function."
SelectArmyDeselectXelnaga_TT := "Units controlling the xelnaga watch towers will be removed from the selection group."
SelectArmyDeselectPatrolling_TT := "Patrolling units will be removed from the selection group.`nThis is very useful if you dont want to select some units e.g. banes/lings at your base or a drop ship waiting outside a base!`nJust set them to patrol and they will not be selected with your army.`n`n**Note:Units set to follow (and are moving) will also me removed."
SelectArmyDeselectHoldPosition_TT := "Units on hold position will be removed from the selection group."
SelectArmyDeselectFollowing_TT := "Units on a follow command will be removed from the selection group."

castRemoveUnit_key_TT := #castRemoveUnit_key_TT := castSplitUnit_key_TT := #castSplitUnit_key_TT := "The hotkey used to invoke this function."
SplitctrlgroupStorage_key_TT := #SplitctrlgroupStorage_key_TT := "This ctrl group is used during the function.`nAssign it to a control group you DON'T use!"
TT_DeselectSleepTime_TT :=  DeselectSleepTime_TT := "Time between deselecting units from the unit panel.`nThis is used by the split and select army, and deselect unit functions"

#Sc2SelectArmyCtrlGroup_TT := Sc2SelectArmyCtrlGroup_TT := "The control Group (key) in which to store the army.`nE.G. 1,2,3-0"
l_DeselectArmy_TT := #l_DeselectArmy_TT := "These unit types will be deselected."

F_Inject_ModifierBeep_TT := "If the modifier keys (Shift, Ctrl, or Alt) or Windows Keys are held down when an Inject is attempted, a beep will heard.`nRegardless of this setting, the inject round will not begin until after these keys have been released."
BlockingStandard_TT := BlockingFunctional_TT := BlockingNumpad_TT := BlockingMouseKeys_TT := BlockingMultimedia_TT := BlockingMultimedia_TT := BlockingModifier_TT := "During certain automations these keys will be buffered or blocked to prevent interruption to the automation and your game play."
LwinDisable_TT := "Disables the Left Windows Key while in a SC2 match.`n`nMacro Trainer Left windows hotkeys (and non-overridden windows keybinds) will still function."
Key_EmergencyRestart_TT := #Key_EmergencyRestart_TT := "If pressed three times, this hotkey will restart the program.`n"
			. "This is useful in the rare event that the program malfunctions or you lose keyboard/mouse input"

HighlightInvisible_TT := #UnitHighlightInvisibleColour_TT := "All invisible, cloaked, and burrowed units will be drawn with this colour.`n"
			. "This will instantly tell you if it's safe to look at the unit i.e. would you legitimately have vision of it."
			. "`n`nNote: If a unit already has a custom colour highlight, then that unit will be drawn using its specific highlight colour."
HighlightHallucinations_TT := #UnitHighlightHallucinationsColour_TT := "Hallucinated units will be drawn using this colour."

MTCustomProgramName_TT := "This will create a new copy of the program with the specified program/process name.`n`nAfter applying the changes you MUST reload the script or launch the newly created .exe file"
						. "`n`nTo change back to the original name and exe, simply clear/blank the name field, save the settings, exit the program and then use the original exe file"

MTChageIconButton_TT := "This will attempt to replace the program's included icon files with a .ico file of your choosing.`n`nThis is not guaranteed to work!"

MTChageIconDefaultButton_TT := "This will attempt to restore the program's default icons.`n`nThis is not guaranteed to work!"

Short_Race_List := "Terr|Prot|Zerg"
loop, parse, l_races, `,
	while (10 > i := A_index-1)
		LG_%A_LoopField%%i%_TT := "Only the specified units below can be bound to their respective control groups.`nAny unit can be grouped to a blank group.`nThis can be used with or without 'Auto Grouping'."

	loop, parse, Short_Race_List, |
	AG_Enable_%A_LoopField%_TT := "Selected units will be automatically added to their set control groups."


OnMessage(0x200, "WM_MOUSEMOVE")
Gosub, G_GuiSetupDrawMiniMapDisable ; Disable controls based on current drawing settings
GuI, Options:Show, w615 h505, Macro Trainer V%ProgramVersion% Settings
Return

HumanMouseWarning:
	GuiControlGet, Checked, ,HumanMouse 
	if Checked
		msgbox, 16, Human Mouse Movement Warning, The only reason to possibly use this setting, is if you are streaming your games and want your viewers to think you're legit.`n`nThis affects injects and chronoboost movements.`nThis setting moves the mouse in a somewhat random arc/line.`n`nThe 'Time' setting dictates the duration of each individual mouse movement. For each movement, a random move time is generated using the upper and lower time bounds.`n`nI repeat DO NOT USE this unless you're a streamer! It offers no advantages!
Return



g_GuiSetupDrawMiniMapDisable:
	
	; the commented out controls here are ones which can still be active 
	; even when the 'Minimap Hack' is not being used
	GuiControlGet, Checked, ,DrawMiniMap 
	if !Checked
	{	
	;	GUIControl, Disable, DrawSpawningRaces
	;	GUIControl, Disable, DrawAlerts
	;	GUIControl, Disable, TT_MiniMapRefresh
	;	GUIControl, Disable, TempHideMiniMapKey
	;	GUIControl, Disable, #TempHideMiniMapKey
		GUIControl, Disable, HostileColourAssist
		GUIControl, Disable, DrawUnitDestinations
		GUIControl, Disable, DrawPlayerCameras
		GUIControl, Disable, HighlightInvisible
		GUIControl, Disable, HighlightHallucinations
		GUIControl, Disable, UnitHighlightExcludeList
		GUIControl, Disable, #UnitHighlightExcludeList

		list := "UnitHighlightList|#UnitHighlightList"
		loop, parse, list, |
			loop, 7 ; as 5 colour indexes
			{
				variable := A_LoopField A_Index
				GUIControl, Disable, %variable%
				GUIControl, Disable, #UnitHighlightList1Colour
			}
		loop, 7 
			GUIControl, Disable, #UnitHighlightList%A_Index%Colour

		GUIControl, Disable, #UnitHighlightInvisibleColour
		GUIControl, Disable, #UnitHighlightHallucinationsColour
	}
	Else
	{	
	;	GUIControl, Enable, DrawSpawningRaces
	;	GUIControl, Enable, DrawAlerts
		GUIControl, Enable, UnitHighlightExcludeList
		GUIControl, Enable, #UnitHighlightExcludeList

	;	GUIControl, Enable, TT_MiniMapRefresh
	;	GUIControl, Enable, TempHideMiniMapKey
	;	GUIControl, Enable, #TempHideMiniMapKey
		GUIControl, Enable, HostileColourAssist
		GUIControl, Enable, DrawUnitDestinations
		GUIControl, Enable, DrawPlayerCameras
		GUIControl, Enable, HighlightInvisible
		GUIControl, Enable, HighlightHallucinations

		list := "UnitHighlightList|#UnitHighlightList"
		loop, parse, list, |
			loop, 7 ; as 5 colour indexes
			{
				variable := A_LoopField A_Index
				GUIControl, Enable, %variable%
			}
		loop, 7 
			GUIControl, Enable, #UnitHighlightList%A_Index%Colour
		GUIControl, Enable, #UnitHighlightInvisibleColour
		GUIControl, Enable, #UnitHighlightHallucinationsColour

	}
Return	
g_GuiSetupResetPixelColour:
	guicontrol, Options:, AM_MiniMap_PixelColourAlpha, 255
	guicontrol, Options:, AM_MiniMap_PixelColourRed, 126
	guicontrol, Options:, AM_MiniMap_PixelColourGreen, 191
	guicontrol, Options:, AM_MinsiMap_PixelColourBlue, 241
	guicontrol, Options:, AM_MiniMap_PixelVariance, 0
return

g_GuiSetupAutoMine:
	GuiControlGet, Item, ,AutoMineMethod 
	if (item = "Normal")
		state := 1
	else state := 0
	l_control = AMGUI1,AMGUI2,AMGUI3,AMGUI4,AMGUI5,AMGUI6,AMGUI7,AMGUI8,AM_MiniMap_PixelColourAlpha,AM_MiniMap_PixelColourRed,AM_MiniMap_PixelColourGreen,AM_MinsiMap_PixelColourBlue,#ResetPixelColour,#FindPixelColour,AM_MiniMap_PixelVariance,TT_AM_MiniMap_PixelVariance
	loop, parse, l_control, `,
		GuiControl, Hide%state%, %A_LoopField%
return


P_Protoss_Joke:	
	tSpeak("Tosser.")
	return
P_Terran_Joke:	
	tSpeak("Terran")
	return
P_zerg_Joke:
	tSpeak("Easy Mode")
	return	

B_HelpFile:
	run % url.HelpFile
	Return

g_ChronoRulesURL:
	run % url.ChronoRules
	Return

B_ChangeLog:
	IfWinExist, ChangeLog Vr: %ProgramVersion%
	{
		WinActivate
		Return 									
	}
	Gui, New 
	Gui Add, ActiveX, xm w980 h640 vWB, Shell.Explorer
	WB.Navigate(url.changelog)
	Gui, Show,,ChangeLog Vr: %ProgramVersion%
Return

B_Report:
	GuiControlGet, Report_Email,
	GuiControlGet, Report_TXT,
	R_check:= trim(Report_TXT, "`n `t") ;remove tabs and new lines (and spaces)
	R_length := StrLen(R_check)

	BugText =  ; this needs to equal the txt i use in txt field of the bug report
(

A return email address is REQUIRED if you are looking for a follow up to your query.

Bugs may not occur on all systems, so please be as SPECIFIC as possible when describing the problem.

Screenshots and replays may be attached below.

(please remove this text when filling in this form).

)	
	if (Report_Email && !isValidEmail(Report_Email))
	{
		msgbox, 49, Invalid Email Address, % "Your email address appears to be invalid.`n`n"
					. "Press 'OK' to send the bug report anyway."
		IfMsgBox Cancel
			return
	}
	if (R_check = "" || R_check = trim(BugText, "`n `t") )
		msgbox, 48, Why Spam?, You didn't write anything.`nPlease don't spam this function.
	Else if ( R_length < 18 )
		msgbox, 32, Don't Spam, Please provide more information.
	Else
	{
		Gui, ListView, EmailAttachmentListViewID ;note all future and current threads now refer to this listview!
		oEmailAttachmentFilePaths := []
		loop % LV_GetCount()
		{
			LV_GetText(AttachmentPath, A_Index) ; start at 1 as 0 retrieves the column header
			oEmailAttachmentFilePaths.insert(AttachmentPath)
		}
		GuiControl, Disable, B_Report
		; Report_Email is the address to return to, if user puts a weird name function will fail with an error!  i.e. and address which violates email address rules
		MT_EmailAddress := "macro.trainer@adam.com.au"
		Try SendEmail(MT_EmailAddress, Report_Email, "Bug Report", "Return Email: " Report_Email "`n" "Problem: `n`n" Report_TXT, oEmailAttachmentFilePaths)
	;	SendEmail(MT_EmailAddress, Report_Email, "Bug Report", "Return Email: " Report_Email "`n" "Problem: `n`n" Report_TXT, oEmailAttachmentFilePaths)
	;	try getProcessBaseAddress(GameIdentifier)
		catch, comError
		{
			MsgBox, % "There was an error submitting this information."
				. "`n`nPress OK to manually send an email to: macro.trainer@adam.com.au"
				. "`n`nPlease attach your MT_Config.ini file!"
			Report_TXT := Report_TXT . "`n`n========================"
						. "`n`nCom Report Error:    "   
						. "`n`rMsg: " comError.Message

			; This converts the text into a mailto/html compatible format
			StringReplace, Report_TXT, Report_TXT, %A_Space% , `%20, All ; %20
			StringReplace, Report_TXT, Report_TXT, `n, `%0D`%0A, All  ;line breaks need to be %0D%0A
			StringReplace, Report_TXT, Report_TXT, `,, `%2C, All  
			StringReplace, Report_TXT, Report_TXT, ?, `%3F, All  
			StringReplace, Report_TXT, Report_TXT, ., `%2E, All  
			StringReplace, Report_TXT, Report_TXT, !, `%21, All  
			StringReplace, Report_TXT, Report_TXT, :, `%3A, All  
			StringReplace, Report_TXT, Report_TXT, `;, `%3B, All  

			run, mailto:%MT_EmailAddress%?subject=Bug Report &body=%Report_TXT% 
			return
		}
		msgbox, 64, , Report Sent, 10
		GuiControl, ,Report_Email,
		GuiControl, ,Report_TXT, `n`n`n`n`n`n%a_tab%%a_tab%Thank You!
	}
	return

;could hide everything each time, then unhide once, but that causes every so slightly more blinking on gui changes
OptionsTree:
	OptionTreeEvent := A_GuiEvent
	OptionTreeEventInfo := A_EventInfo
	TV_GetText(Menu_TXT, TV_GetSelection())

;	if (OptionTreeEvent != "S")
;		return 

;	if (OptionTreeEvent = "F" || OptionTreeEvent = "E" || OptionTreeEvent = "K") ; so the menu doesnt get redrawn too frequenctly e.g. user key presses
;		return  																; require altsubmit-g-label as need to monitor user right clicks
;	if (OptionTreeEvent = "RightClick")  ; so right clicking will change the selection 
;	{
;		if !OptionTreeEventInfo ; there's a bug in AHK with the right click - have GUI on second monitor and right click, Menu_TXT will be blank
;			send {click}  		; so force a left click on the item
;		else TV_Modify(OptionTreeEventInfo, "Select") ; this will relaunch the OptionsTree-g-label and unhide the corrrect window
;		return 
;	}

	if Menu_TXT  ; there's a bug in AHK with the right click - have GUI on second monitor and right click, Menu_TXT will be blank
		GUIcontrol, Hide, %unhidden_menu%
	IF ( Menu_TXT = "Home" )
	{
		GUIcontrol, Show, Home_TAB
		unhidden_menu := "Home_TAB"
	}
	ELSE IF ( Menu_TXT = "Detection List" )
	{
		GUIcontrol, Show, Detection_TAB
		unhidden_menu := "Detection_TAB"
	}	
	ELSE IF ( Menu_TXT = "MiniMap/Overlays" )
	{
		GUIcontrol, Show, MiniMap_TAB
		unhidden_menu := "MiniMap_TAB"
	}
	ELSE IF ( Menu_TXT = "Injects" )
	{
		GUIcontrol, Show, Injects_TAB
		unhidden_menu := "Injects_TAB"
	}	
	ELSE IF ( Menu_TXT = "Unit Grouping" )
	{
		GUIcontrol, Show, AutoGroup_TAB
		unhidden_menu := "AutoGroup_TAB"
	}	
	ELSE IF ( Menu_TXT = "Auto Worker" )
	{
		GUIcontrol, Show, AutoWorker_TAB
		unhidden_menu := "AutoWorker_TAB"
	}
	ELSE IF ( Menu_TXT = "Chrono Boost" )
	{
		GUIcontrol, Show, ChronoBoost_TAB
		unhidden_menu := "ChronoBoost_TAB"
	}
	ELSE IF ( Menu_TXT = "Auto Mine" )
	{
		GUIcontrol, Show, AutoMine_TAB
		unhidden_menu := "AutoMine_TAB"
	}	
	ELSE IF ( Menu_TXT = "Misc Automation" )
	{
		GUIcontrol, Show, MiscAutomation_TAB
		unhidden_menu := "MiscAutomation_TAB"
	}
	ELSE IF ( Menu_TXT = "SC2 Keys" )
	{
		GUIcontrol, Show, Keys_TAB
		unhidden_menu := "Keys_TAB"
	}	
	ELSE IF ( Menu_TXT = "Warnings" )
	{
		GUIcontrol, Show, Warnings_TAB
		unhidden_menu := "Warnings_TAB"
	}
	ELSE IF ( Menu_TXT = "Misc Abilities" )
	{
		GUIcontrol, Show, Misc_TAB 
		unhidden_menu := "Misc_TAB"
	}
	ELSE IF ( Menu_TXT = "Settings" )
	{
		GUIcontrol, Show, Settings_TAB
		unhidden_menu := "Settings_TAB"
	}	
	ELSE IF ( Menu_TXT = "Report Bug" )
	{
		GUIcontrol, Show, Bug_TAB
		unhidden_menu := "Bug_TAB"
	}
	Else return  ;if (OptionTreeEvent != "D")	; due to my OCD making me allow right clicks on treeview item
		; return 							; there seems to be some possible bug/loop which maxs  and freezes AHK until the icon is clicked
										; i Think having a return here will break this


	; There is some weird bug that occurs after the user clicks 'apply'
	; After this when ever the user single clicks the treeview, the selection wont change
	; user has to double click to get it to change, then it works fine.
	; This is a workaround for this bug
;	if (OptionTreeEvent = "D" && !GetKeyState("LButton", "P")) ; the gui event says its a drag when the error occurs (but its not really)
;		send {click 2}
	WinSet, Redraw,, Macro Trainer V%ProgramVersion% Settings 				; redrawing whole thing as i noticed very very rarely (when a twitch stream open?) the save/cancel/apply buttons disappear
; 	 GUIControl, MoveDraw, GUIListViewIdentifyingVariableForRedraw ; this is the same as redraw (but just for a control? - although it still seems to flicker the entire thing)
 	Return															; this prevents the problem where some of the icons would remain selected
 																	; so multiple categories would have the blue background
 	
 	
;can arrive here from the GUI +/add button, or via the GuiDropFiles: label which is activated when a user drags and drops files onto a control
g_AddEmailAttachment:
if (A_GuiControl = "EmailAttachmentListViewID") 
	FilePath := A_GuiEvent 		; contains the names separated by `n each file has its full directory path
else 							; this is different to the multi file select, where the directory folder is only in A_index 1
{
	FileSelectFile, FilePath, M1, , Attach Files 
	if (errorlevel || !FilePath) ; is set to 1 if the user dismissed the dialog without selecting a file (such as by pressing the Cancel button).
		return 
	Else
	{
		Loop, parse, FilePath, `n ;`n is used to separate multiple selected files
			AttachmentCount := A_Index

		; this acts to convert the multi-selected files so that each one has a full directory listing
		; and is separated from the next by `n - so it should now be identical to the syntax used if a user had dragged
		; and dropped the files

		if (AttachmentCount > 1)
		{
			Loop, parse, FilePath, `n
			{	
				if (A_Index = 1) 	; when multiple files are selected (they all must come from the same folder)
				{					; This folder path is only included in Index 1
					tmpFilePaths := ""
					BaseDirectory := A_LoopField
					if (SubStr(BaseDirectory, 0, 1) != "\") ; as root directories will contain '\' but other ending directories wont
						BaseDirectory .= "\" 
					continue
				}
				else tmpFilePaths .= BaseDirectory A_LoopField "`n"
			}		
			FilePath := RTrim(tmpFilePaths, "`n") ; remove the `n from the final path, so dont get an empty list view filed  
		}

	}
}
Gui, ListView, EmailAttachmentListViewID ;note all future and current threads now refer to this listview!
Loop, parse, FilePath, `n
	LV_Add("", A_LoopField)
LV_ModifyCol()  ; Auto-size all columns to fit their contents
return 


return
g_RemoveEmailAttachment:

Gui, ListView, EmailAttachmentListViewID ;note all future and current threads now refer to this listview!
EmailRowNumber := 0
UserTriedToRemoveIniAttachment := False  
Loop
{
    EmailRowNumber := LV_GetNext(EmailRowNumber)  ; Resume the search at the row after that found by the previous iteration.
    if !EmailRowNumber  ; The above returned zero, so there are no more selected rows.
        break
    LV_GetText(RowText, EmailRowNumber)
    if instr(RowText, "MT_Config.ini")
    	UserTriedToRemoveIniAttachment := True
    else 
    {
    	LV_Delete(EmailRowNumber)
    	goto g_RemoveEmailAttachment ; otherwise some items wont get deleted as lv_next gets confused in loop
    }
}
LV_ModifyCol()  ; Auto-size all columns to fit their contents
if UserTriedToRemoveIniAttachment
	msgbox Your config file is always attached to a bugreport.`nIt can not be removed.
return 

; activated when a user drags and drops files onto a control
; so far only used for email attachments

;Note GuiDropFiles: is the general label, but Have changed the options menu label to Options hence 'OptionsGuiDropFiles'
OptionsGuiDropFiles: 
if (A_GuiControl = "EmailAttachmentListViewID")
	Gosub, g_AddEmailAttachment 
return 

g_MTChageIcon:
FileSelectFile, NewIconFile, S3, , Select an Icon or Picture, *.ico ; only *.ico will work with reshacker
if (errorlevel || !NewIconFile || !A_IsCompiled) ; is set to 1 if the user dismissed the dialog without selecting a file (such as by pressing the Cancel button).
	return
;GUIControl,, MTCustomIcon, %NewIconFile% 
;GUIControl,, MTIconPreview, %NewIconFile%  ;update the little pic ; width height omitted, so pic scaled to fit control
Iniwrite, %NewIconFile%, %config_file%, Misc Settings, MTCustomIcon
ResourHackIcons(NewIconFile)  ;this function quits and reloads the script
return 
g_MTChageIconDefault:
;GUIControl,, MTCustomIcon, %A_Space% ;blank it
if !MTCustomIcon ; don't do anything already using the standard Icon
	return 
Iniwrite, %A_Space%, %config_file%, Misc Settings, MTCustomIcon ; use this to check if display my tool tip lol
ResourHackIcons(A_Temp "\Starcraft-2.ico") ;this function quits and reloads the script
return

Test_VOL:
	original_programVolume := programVolume
	GuiControlGet, TmpSpeechVol,, speech_volume
	TmpSpeechVol := Round(TmpSpeechVol, 0)
	GuiControlGet, TmpTotalVolume,, programVolume
	programVolume := Round(TmpTotalVolume, 0)

	If ( A_GuiControl = "Test_VOL_All")
	{
		SetProgramWaveVolume(programVolume)
		loop, 2
		{
			SoundPlay, %A_Temp%\Windows Ding.wav  ;SoundPlay *-1
			sleep 150
		}
	}	
	;Random, Rand_joke, 1, 8
	Rand_joke ++
	If ( Rand_joke = 1 )
		tSpeak("Protoss is OPee", TmpSpeechVol)
	Else If ( Rand_joke = 2 )
		tSpeak("A templar comes back to base with a terrified look on his face. The zealots asks - what happened? You look like you've seen a ghost", TmpSpeechVol)
	Else If ( Rand_joke = 3 )
	{

		tSpeak("A Three Three Protoss army walks into a bar and asks", TmpSpeechVol)
		sleep 50
		tSpeak("Where is the counter?", TmpSpeechVol)
	}
	Else If ( Rand_joke = 4 )
	{
		tSpeak("What computer does IdrA use?", TmpSpeechVol)
		sleep 1000
		tSpeak("An EYE BM", TmpSpeechVol)
	}
	Else If ( Rand_joke = 5 )
	{
		tSpeak("Why did the Cullosus fall over ?", TmpSpeechVol)
		sleep 1000
		tSpeak("because it was imbalanced", TmpSpeechVol)
	}
	Else If ( Rand_joke = 6 )
	{
		tSpeak("How many Zealots does it take to change a lightbulb?", TmpSpeechVol)
		sleep 1000
		tSpeak("None, as they cannot hold", TmpSpeechVol)	
	}
	Else If ( Rand_joke = 7 )
	{
		tSpeak("How many Infestors does it take to change a lightbulb?", TmpSpeechVol)
		sleep 1000
		tSpeak("One, you just have to make sure he doesn't over-power it", TmpSpeechVol)	
	}
	Else
	{
		tSpeak("How many members of the Starcraft 2 balance team does it take to change a lightbulb?", TmpSpeechVol)
		sleep 1000
		tSpeak("All three of them, and Ten patches", TmpSpeechVol)	
		rand_joke := 0
	}
	SetProgramWaveVolume(programVolume := original_programVolume)
return

Edit_SendHotkey:
	if (SubStr(A_GuiControl, 1, 1) = "#") ;this is a method to prevent launching 
	{
		hotkey_name := SubStr(A_GuiControl, 2)	;this label (and sendgui) for a 2nd time 
		hotkey_var := SendGUI("Options",%hotkey_name%,,,"Select Key:   " hotkey_name) ;the hotkey
		if (hotkey_var <> "")
			GUIControl,, %hotkey_name%, %hotkey_var%
	}
Return

edit_hotkey:
	if (SubStr(A_GuiControl, 1, 1) = "#") ;this is a method to prevent launching 
	{
		hotkey_name := SubStr(A_GuiControl, 2)	;this label (and hotkeygui) for a 2nd time 
		if (hotkey_name = "AdjustOverlayKey")		
			hotkey_var := HotkeyGUI("Options",%hotkey_name%,2046, "Select Hotkey:   " hotkey_name)  ;as due to toggle keywait cant use modifiers
		else if (hotkey_name = "castSelectArmy_key") ;disable the modifiers
			hotkey_var := HotkeyGUI("Options",%hotkey_name%, 2+4+8+16+32+64+128+256+512+1024, "Select Hotkey:   " hotkey_name) ;the hotkey		
		else if (hotkey_name = "Key_EmergencyRestart")  
			; Force Right side modifiers and force the wildcard option (disable and check)
			; this is done as if have stuck modifier then this could prevent the hotkey firing.
			hotkey_var := HotkeyGUI("Options",%hotkey_name%, 0, "Select Hotkey:   " hotkey_name, 0, 0, 10, 14) ;the hotkey
		Else hotkey_var := HotkeyGUI("Options",%hotkey_name%,, "Select Hotkey:   " hotkey_name) ;the hotkey
		if (hotkey_var <> "")
			GUIControl,, %hotkey_name%, %hotkey_var%
	}
return


Alert_List_Editor:
Gui, New 
alert_list_fields :=  "Name,DWB,DWA,Repeat,IDName"
SetupUnitIDArray(aUnitID, aUnitName)
Editalert_array := [],	Editalert_array := createAlertArray()

Gui -MaximizeBox
Gui, Add, GroupBox,  w220 h370 section, Current Detection List
Gui, Add, TreeView, xp+20 yp+20 gMyTree r20 w180

loop, parse, l_GameType, `,
{
	p%A_Index% := TV_Add(A_LoopField)	;p1 = 1v1, p2 =2v2 etc	
	P# := A_Index 						;set var p# for inner loop	
	loop, % Editalert_array[A_LoopField, "list", "size"]				;loop their names
	{
		p_LvL_2 = p%P#%c%A_Index%							;child number
		%p_LvL_2% := TV_Add(Editalert_array[A_LoopField, A_Index, "Name"], p%P#%)	;building name
	}			
}

Gui, Add, GroupBox, ys x+30 w245 h185 vOriginTabRAL, Parameters
GuiControlGet, OriginTabRAL, Pos
	Gui, Add, Text,xp+10 yp+20 section, Name/Warning:
	Gui, Add, Text,y+10 w80, Don't Warn if Exists Before (s):
	Gui, Add, Text,y+10 w80, Don't Warn if Made After (s):
	Gui, Add, Text,y+12, Repeat on New?
	Gui, Add, Text,y+16, ID Code:

	Gui, Add, Edit, Right ys xs+85 section w135 vEdit_Name	
	Gui, Add, Edit, Number Right y+11 w135 vTT_Edit_DWB
		Gui, Add, UpDown,  Range0-100000 vEdit_DWB, 0
	Gui, Add, Edit, Number Right y+11 w135 vTT_Edit_DWA
		Gui, Add, UpDown,  Range1-100000 vEdit_DWA, 54000

	Gui, Add, DropDownList, xs+90  y+8 w45 right VEdit_RON, Yes||No|	
	DetectionUnitListNames := 	"ID List||" l_UnitNames	;get the ID List Txt first in the shared list
	Gui, Add, DropDownList, xs y+10 w135 Vdrop_ID sort, %DetectionUnitListNames%

Gui, Add, GroupBox, y+30 x%OriginTabRALX% w245 h175, Alert Submission	
	Gui, Add, Button, xp+10 yp+20 w225 section vB_Modify_Alert gB_Modify_Alert, Modify Alert
	Gui, Add, Text,xs ys+27 w225 center, OR
	Gui, Add, Button, xs y+5 w225 section gDelete_Alert vB_Delete_Alert Center, Delete Alert
	gui, Add, Text, Readonly yp+5 x+15 w90 center vCurrent_Selected_Alert2, `n`n
	Gui, Add, Text,xs ys+27 w225 center, OR

Gui, Add, GroupBox, y+5 xs-5 w235 h55 section, New Alert	
	Gui, Add, Button, xs+5 yp+20 w120 vB_Add_New_Alert gB_Add_New_Alert, Add This Alert to List
	Gui, Add, Checkbox, checked x+10 yp-5 section vC_Add_1v1, 1v1
	Gui, Add, Checkbox, checked x+10 vC_Add_3v3, 3v3
	Gui, Add, Checkbox, checked yp+20 vC_Add_4v4, 4v4
	Gui, Add, Checkbox, checked xs yp vC_Add_2v2, 2v2

Gui, Add, Button, xp-100 y+30 vB_ALert_Cancel gGuiClose w100 h50, Cancel
Gui, Add, Button, xp-200 yp vB_ALert_Save gB_ALert_Save w100 h50, Save Changes

Gui, Show, w490 h455, Alert List Editor  ; Show the window and its TreeView.

OnMessage(0x200, "WM_MOUSEMOVE")

	Edit_Name_TT := "This text is read aload during the warning"
	Edit_DWB_TT := TT_Edit_DWB_TT := "If the unit/building exists before this time, no warning will be made - this is helpful for creating multiple warnings for the same unit"
	Edit_DWA_TT := TT_Edit_DWA_TT := "If the unit is made after this time, no warning will be made -  this is helpful for creating multiple warnings for the same unit"
	Edit_RON_TT := "If ''Yes'' this SPECIFIC warning will be heard for each new unit/building (of this type)."
	Edit_ID_TT := "This value is used to identify buildings and units within SC2 (the list below can be used)"
	drop_ID_TT := "Use this list to find a units ID"
	B_Modify_Alert_TT := "This updates the currently selected alert with the above parameters."
	Delete_Alert_TT := "Removes the currently selected alert."
	B_Add_New_Alert_TT := "Creates an alert using the above parameters for the selected game modes."
	B_ALert_Cancel_TT := "Disregard changes"
;	B_ALert_Save_TT := "This will save any changes made"
return

Drop_ID:
	GuiControlGet, Edit_Unit_name,, drop_ID ;get txt of selection
	Edit_ID := aUnitID[Edit_Unit_name]	;look up the associated ID by unit Title
	GUIControl,, Edit_ID, %Edit_ID%	;set the edit box
return

Delete_Alert:
	Gui, Submit, NoHide
	TV_item := TV_CountP()
	TV_GetText(GameTypeTV,TV_GetParent(TV_GetSelection()))
	del_correction := Editalert_array[GameTypeTV, "list", "size"] - TV_item
	alert_list_fields :=  "Name,DWB,DWA,Repeat,IDName"
	loop, parse, alert_list_fields, `, ;comma is the separator
	{
		loop, % del_correction
		{
			TV_item_next := TV_item + A_Index
			TV_item_previous := TV_item_next - 1	
			Editalert_array[GameTypeTV, TV_item_previous, A_LoopField] :=  Editalert_array[GameTypeTV, TV_item_next, A_LoopField]	;copy data back 1 space
		}
	}
	Editalert_array[GameTypeTV].remove(Editalert_array[GameTypeTV, "list", "size"])

	Editalert_array[GameTypeTV, "list", "size"] -= 1	;decrease list size by 1
	TV_Delete(TV_GetSelection())
	GUIControl,, B_Delete_Alert, Delete Alert - %GameTypeTV% %ItemTxt% ;update tne name on button
	GUIControl,, B_Modify_Alert, Modify Alert - %GameTypeTV% %ItemTxt%

Return

B_Modify_Alert:

	Gui, Submit, NoHide
	if ( Edit_Name = "" OR Edit_DWB = "" OR Edit_DWA = "" OR  drop_ID = "ID List" ) ; Edit_RON cant be blank
		MsgBox Blank parameters are not acceptable.
	Else
	{
		TV_item := TV_CountP()
		TV_GetText(GameTypeTV,TV_GetParent(TV_GetSelection()))
		TV_Modify(TV_GetSelection(), %Space%, Edit_Name) ; update name in tree view - %Space% workaround for blank option bug
		Editalert_array[GameTypeTV, TV_item, "Name"] := Edit_Name
		Editalert_array[GameTypeTV, TV_item, "DWB"] := Edit_DWB
		Editalert_array[GameTypeTV, TV_item, "DWA"] := Edit_DWA
		if (Edit_RON = "Yes")
			Editalert_array[GameTypeTV, TV_item, "Repeat"] := 1
		Else Editalert_array[GameTypeTV, TV_item, "Repeat"] := 0
		Editalert_array[GameTypeTV, TV_item, "IDName"] := drop_ID	
	}
	Return
  
B_Add_New_Alert:
	Gui, Submit, NoHide
	if ( Edit_Name = "" OR Edit_DWB = "" OR Edit_DWA = "" OR  drop_ID = "ID List" ) ; Edit_RON cant be blank
		MsgBox Blank parameters are not acceptable.
	Else if ((C_Add_1v1 + C_Add_2v2 + C_Add_3v3 + C_Add_4v4) = 0)
		msgbox You must select at least one game mode. 
	Else
	{
		Add_to_GameType := []
		loop, parse, l_GameType, `,
		{
			if C_Add_%A_LoopField%
				Add_to_GameType[A_Index] := A_LoopField
		}

		For index, game_mode in Add_to_GameType
		{	
			New_Item_Pos := Editalert_array[game_mode, "list", "size"] += 1
			Editalert_array[game_mode, New_Item_Pos, "Name"] := Edit_Name
			Editalert_array[game_mode, New_Item_Pos, "DWB"] := Edit_DWB
			Editalert_array[game_mode, New_Item_Pos, "DWA"] := Edit_DWA
			if (Edit_RON = "Yes")
				Editalert_array[game_mode, New_Item_Pos, "Repeat"] := 1
			Else Editalert_array[game_mode, New_Item_Pos, "Repeat"] := 0
			Editalert_array[game_mode, New_Item_Pos, "IDName"] := drop_ID	

			loop, parse, l_GameType, `, ; 1s,2s,3s,4s
			{		
				if ( game_mode = A_LoopField )
					TV_Add(Edit_Name, p%a_index%) ; TV p1 = 1v1, p2 =2v2 etc
			}	
		}
	}
	WinSet, Redraw,, Alert List Editor, Current Detection List ;forces a redraw as the '+' expander doesnt show (until a mouseover) if the parent had no items when the gui was initially drawn
	Return

MyTree:
	TV_GetText(GameTypeTV,TV_GetParent(TV_GetSelection()))
	If (GameTypeTV = "1v1" or GameTypeTV = "2v2" or GameTypeTV = "3v3" or GameTypeTV = "4v4" or GameTypeTV = "FFA") ;your in the unit name/list
	{
		GUIControl, Enable, B_Delete_Alert
		GUIControl, Enable, B_Modify_Alert
		ItemID := TV_GetChild(TV_GetParent(TV_GetSelection()))
		TV_GetText(ItemTxt, (TV_GetSelection()))
		Count_TVItem := 0, OutputTxt := "" ;blank OutputTxt to prevent error when clicking on unit with same name in different gamemode list
		Loop
		{
			If (ItemID = 0 OR ItemTxt = OutputTxt) ; No more items in tree. (FUNCTIONS RETURNS 0 LAST ONE)
				break
			TV_GetText(OutputTxt, ItemID)
			ItemID := TV_GetNext(ItemID)
			Count_TVItem ++
		}
		GUIControl,, Edit_Name,% Editalert_array[GameTypeTV, Count_TVItem, "Name"]

		GUIControl,, Edit_DWB,% Editalert_array[GameTypeTV, Count_TVItem, "DWB"]
		GUIControl,, Edit_DWA,% Editalert_array[GameTypeTV, Count_TVItem, "DWA"]
		if (Editalert_array[GameTypeTV, Count_TVItem, "Repeat"])
			GUIControl, ChooseString, Edit_RON, Yes
		Else GUIControl, ChooseString, Edit_RON, No
		GUIControl,, Edit_ID,% Editalert_array[GameTypeTV, Count_TVItem, "IDName"]
		GUIControl,ChooseString, drop_ID, % Editalert_array[GameTypeTV, Count_TVItem, "IDName"]
		GUIControl,, B_Delete_Alert, Delete Alert - %GameTypeTV% %ItemTxt%
		GUIControl,, B_Modify_Alert, Modify Alert - %GameTypeTV% %ItemTxt%

	}
	Else ; youre in the gamemode part of the list
	{
		GUIControl,, B_Delete_Alert, Delete Alert
		GUIControl,, B_Modify_Alert, Modify Alert
		GUIControl, Disable, B_Delete_Alert
		GUIControl, Disable, B_Modify_Alert

	}
	return

B_ALert_Save:
	alert_array := Editalert_array
	saveAlertArray(Editalert_array)
	If (A_ThisLabel <> "Alert_Array_General_Write")
		Gui, Destroy
Return



saveAlertArray(alert_array)
{	GLOBAL
	loop, parse, l_GameType, `, 
	{
		IniDelete, %config_file%, Building & Unit Alert %A_LoopField% ;clear the list - prevent problems if now have less keys than b4
		IniWrite, % alert_array[A_LoopField, "Enabled"], %config_file%, Building & Unit Alert %A_LoopField%, enable	;alert system on/off
		IniWrite, % alert_array[A_LoopField, "Clipboard"], %config_file%, Building & Unit Alert %A_LoopField%, copy2clipboard
		loop, % alert_array[A_LoopField, "list", "size"]  ;loop 1v1 etc units
		{
			IniWrite, % alert_array[A_LoopField, A_Index, "Name"], %config_file%, Building & Unit Alert %A_LoopField%, %A_Index%_name_warning
			Iniwrite, % alert_array[A_LoopField, A_Index, "DWB"], %config_file%, Building & Unit Alert %A_LoopField%, %A_Index%_Dont_Warn_Before_Time
			IniWrite, % alert_array[A_LoopField, A_Index, "DWA"], %config_file%, Building & Unit Alert %A_LoopField%, %A_Index%_Dont_Warn_After_Time
			IniWrite, % alert_array[A_LoopField, A_Index, "Repeat"], %config_file%, Building & Unit Alert %A_LoopField%, %A_Index%_repeat_on_new
			IniWrite, % alert_array[A_LoopField, A_Index, "IDName"], %config_file%, Building & Unit Alert %A_LoopField%, %A_Index%_IDName
		}
	}
	return
}

TV_CountP()
{
	ItemID := TV_GetChild(TV_GetParent(TV_GetSelection()))
	TV_GetText(ItemTxt, (TV_GetSelection()))
	Loop
	{
		If (ItemID = 0 OR ItemTxt = OutputTxt) ; No more items in tree. (FUNCTIONS RETURNS 0 LAST ONE)
			break
		TV_GetText(OutputTxt, ItemID)
		ItemID := TV_GetNext(ItemID)
		Count_Item ++
	}
	Return Count_Item
}

WM_MOUSEMOVE()
{
	static CurrControl, PrevControl, _TT  ; _TT is kept blank for use by the ToolTip command below.

    CurrControl := A_GuiControl
    If (CurrControl <> PrevControl and not InStr(CurrControl, " "))
    {
        ToolTip  ; Turn off any previous tooltip.
        SetTimer, DisplayToolTip, 400
        PrevControl := CurrControl
    }
    return

    DisplayToolTip:

    SetTimer, DisplayToolTip, Off
	Try	ToolTip % %CurrControl%_TT  ; try guards against illegal character error
    SetTimer, RemoveToolTip, 10000
    return

    RemoveToolTip:
    SetTimer, RemoveToolTip, Off
    ToolTip
    return
}

g_UnitFilterInfo:
IfWinExist, MT Unit Filter Info
{
	WinActivate
	Return 									; prevent error due to reloading gui 
}
Gui, UnitFilterInfo:New
Text := "
	( LTrim
		These filters will remove the selected units from the unit panel.

		The unit panel displays two types of units, those which exist on the map (or are completed) and those which are being built (mainly buildings).

		For each race there are two filters which are always active.
		Filter 1: 'Completed' - This will remove completed (or fully built) units of the selected types.

		Filter 2: 'Under Construction' - This will remove units which are under construction/being built.

		Please Note: 

		Not all of the listed units will appear in the unit panel. For example, having a 'marine' in the under construction panel will do nothing.
		Hence it is best to actually use the unit panel first and then decide on which units you wish to filter.
	)"

Gui, Add, Edit, x12 y+10 w350 h450 readonly -E0x200, % Text
Gui, UnitFilterInfo:Show,, MT Unit Filter Info
return


g_GUICustomUnitPanel:
IfWinExist, MT Custom Unit Filter - Unit Panel
{
	WinActivate
	Return 									; prevent error due to reloading gui 
}
if LV_UnitPanelFilter 
	LV_UnitPanelFilter := ""  ; destroy the object so isobject() will force a reload of units (prevents problem when closing and the items remaining in the object when it gets reopened next)
Gui, CustomUnitPanel:New
Gui, Add, Text, x50 y+20 w60, Race: 
Gui, Add, DropDownList, x+15 vGUI_UnitPanelRace gg_UnitPanelGUI, Terran||Protoss|Zerg
Gui, Add, Text, x50 y+15 w60, Unit Filter: 
Gui, Add, DropDownList, x+15 vGUI_UnitPanelListType gg_UnitPanelGUI, Completed||Under construction
Gui, Add, Button, x+15 y20 w50   gg_SaveCustomUnitPanelFilter,  Save 
Gui, Add, Button, xp y+13 w50  gGuiClose,  Cancel 
Gui, Add, Button, x+10 yp w50  gg_UnitFilterInfo,  Info 

Gui, Add, ListView, x30 y90 r15 w160 Sort vUnitPanelFilteredUnitsCurrentRace gg_UnitPanelRemoveUnit, Currently Filtered ; This stores the currently displayed race which is  being displayed in the filtered LV as gui submit doesnt affect listview variable

Gui, Add, ListView, x+20  r15 w160 Sort vUnitPanelAvailableUnits gg_UnitPanelAddUnit, Units
GUI_UnitPanelMenu := []	;stores information used to manipualte the menus
GUI_UnitPanelMenu.race  := UnitPanelAvailableUnits := "Terran"
Gosub, g_UnitPanelGUI ; This sets the display race to terran

Gui, Add, Button, x30 y+5 w160 h40  gg_UnitPanelRemoveUnit,  Remove 
Gui, Add, Button, x+20 w160 h40  gg_UnitPanelAddUnit,  Add 

GuI, CustomUnitPanel:Show, w400 h430, MT Custom Unit Filter - Unit Panel
return


g_UnitPanelRemoveUnit:
if (A_GuiEvent = "DoubleClick" || A_GuiEvent = "Normal") 
	LV_UnitPanelFilter[GUI_UnitPanelMenu.ListType, GUI_UnitPanelMenu.race ].MoveSelectedCurrentToAvailable()
return

g_UnitPanelAddUnit:
if (A_GuiEvent = "DoubleClick" || A_GuiEvent = "Normal") ;this only allows the add button and double LEFT clicks to add units
	LV_UnitPanelFilter[GUI_UnitPanelMenu.ListType, GUI_UnitPanelMenu.race ].MoveSelectedAvailableToCurrent()
return



g_SaveCustomUnitPanelFilter:
gosub, g_CheckLV_UnitPanelObject	;this ensure that LV_UnitPanelFilter exists and is filled with the current lists
section := "UnitPanelFilter"
if !RaceObject
	RaceObject := new cSC2Functions()
for index, ListType in ["FilteredCompleted", "FilteredUnderConstruction"]
	for index, LoopRace in ["Terran", "Protoss", "Zerg"] 
	{
		List := convertObjectToList(LV_UnitPanelFilter[ListType, LoopRace, "CurrentItems"], "|")
		IniWrite, %List%, %config_file%, %section%, % LoopRace ListType
		if !IsObject(aUnitPanelUnits[LoopRace, ListType])
			aUnitPanelUnits[LoopRace, ListType] := []
		aUnitPanelUnits[LoopRace, ListType]	:= 	LV_UnitPanelFilter[ListType, LoopRace, "CurrentItems"] ;note the race and list type have been reversed here
	}
Gui, CustomUnitPanel:Destroy  ;as there is a gosub here during an update/ini-transfer - dont want to detroy the wrong gui.
return


;	This menu can be arrived at by three methods
;		1. From a gosub which is used when the GUI is first created - "A_GuiControl" Will be blank 
;		2. From clicking the T, P, Or Z buttons - A_GuiControl will contain the name of the race button e.g "Terran"
;		3. From using the dropdown list (filer list type) A_GuiControl - will contain "GUI_UnitPanelListType"
;
;	This label helps create an object of the TwoPanelSelection_LV class; these are used to keep track of the 
;	filtered units for the Unit panel (both the 'completed filtered' and 'under construction filtered' lists)

g_UnitPanelGUI:
;GUIcontrol := A_GuiControl

GuiControlGet, GUIcontrol,, GUI_UnitPanelRace 
IfInString, GUIcontrol, Protoss
	GUI_UnitPanelMenu.race := "Protoss"
else IfInString, GUIcontrol, Zerg
	GUI_UnitPanelMenu.race  := "Zerg"
else IfInString, GUIcontrol, Terran
	GUI_UnitPanelMenu.race  := "Terran"

GuiControlGet, CurrentList,, GUI_UnitPanelListType 
if (CurrentList = "Completed")
	GUI_UnitPanelMenu.ListType := CurrentList := "FilteredCompleted"
else if (CurrentList = "Under Construction")
	GUI_UnitPanelMenu.ListType := CurrentList := "FilteredUnderConstruction"

if (GUIcontrol = "") ; blank for the first gosub
	GUI_UnitPanelMenu.PreviousListType := GUI_UnitPanelMenu.ListType := CurrentList		


if (!GUI_UnitPanelMenu.PreviousRace)	;these vars store the previous race - save as gui submit doesnt affect them
	GUI_UnitPanelMenu.PreviousRace := GUI_UnitPanelMenu.race 
Else
{
	LV_UnitPanelFilter[GUI_UnitPanelMenu.PreviousListType, GUI_UnitPanelMenu.PreviousRace].storeItems()
	GUI_UnitPanelMenu.PreviousRace := GUI_UnitPanelMenu.race
	GUI_UnitPanelMenu.PreviousListType := GUI_UnitPanelMenu.ListType
}
gosub, g_CheckLV_UnitPanelObject

LV_UnitPanelFilter[GUI_UnitPanelMenu.ListType, GUI_UnitPanelMenu.race ].restoreItems()
return

;this is used by the above routine, It cannot be used during an update!!!!, as there was no listview gui & variables and its class wont work
g_CheckLV_UnitPanelObject:
if !aUnitLists
	Gosub, g_CreateUnitListsAndObjects ; used for some menu items, and for the custom unit filter gui remnant from unsuccessfull method of transferring ini settings during update - but no harm leaving it in.
if !IsObject(LV_UnitPanelFilter)
{
	LV_UnitPanelFilter := []
	for index, ListType in ["FilteredCompleted", "FilteredUnderConstruction"]
		for index, LoopRace in ["Terran", "Protoss", "Zerg"] 	;so this object will be full of the info ready for saving - no checks needed!
		{
			LV_UnitPanelFilter[ListType, LoopRace] := new TwoPanelSelection_LV("UnitPanelAvailableUnits", "UnitPanelFilteredUnitsCurrentRace")
			LV_UnitPanelFilter[ListType, LoopRace].removeAllitems() ; so ready for new units
			if aUnitPanelUnits[LoopRace,  ListType].maxindex()	;this prevents adding 1 'blank' spot/unit to the list when its empty
				LV_UnitPanelFilter[ListType, LoopRace].AddItemsToCurrentPanel(aUnitPanelUnits[LoopRace,  ListType], 1)
			if aUnitLists["UnitPanel", LoopRace].maxindex() ;this isnt really needed, as these lists always have units
				LV_UnitPanelFilter[ListType, LoopRace].AddItemsToAvailablePanel(aUnitLists["UnitPanel", LoopRace], 1)
			LV_UnitPanelFilter[ListType, LoopRace].storeItems()
		}
}
return

class TwoPanelSelection_LV
{
	__New(AvailablePanel, CurrentListPanel) 
	{
		this.Available 	:= AvailablePanel	; eg associated var
		this.Current 	:= CurrentListPanel	; eg associated var
		this.CurrentItems := []
		this.AvailableItems := []
	}

	ModifyCol(panel = "")
	{
		if panel
			ModifyColListView(panel, "AutoHdr") 
		else 
		{
			ModifyColListView(this.Available, "AutoHdr")		;auto resizes columns
			ModifyColListView(this.Current, "AutoHdr")
		}		
	}
	removeAllitems(panel = "")
	{
		if panel
			removeAllItemsFromListView(panel)
		else ;remove all
		{
			removeAllItemsFromListView(this.Available)		;clears the fields
			removeAllItemsFromListView(this.Current)
		}
		this.ModifyCol()
	}
	restoreItems()
	{
			this.removeAllitems()
			this.AddItemsToCurrentPanel(this.CurrentItems, 1)
			this.AddItemsToAvailablePanel(this.AvailableItems, 1)
			this.ModifyCol()
	}
	storeItems()
	{
		this.storeCurrentItems()
		this.storeAvailabletItems()
	}
	storeAvailabletItems()
	{
		this.AvailableItems := retrieveItemsFromListView(this.Available)
	}	
	storeCurrentItems()
	{
		this.CurrentItems := retrieveItemsFromListView(this.Current)
	}
	otherPanel(Panel)
	{
		if (panel = this.Available)
			return this.Current 
		else if (panel = this.Current)
			return this.Available 
		else return 0
	}
	AddItemsToAvailablePanel(Items, CheckOtherPanel = "")
	{
		this.AddItemsToPanel(Items, this.Available, CheckOtherPanel)
		this.ModifyCol()
		return
	}
	AddItemsToCurrentPanel(Items, CheckOtherPanel = "")
	{
		this.AddItemsToPanel(Items, this.current, CheckOtherPanel)
		this.ModifyCol()
		return
	}

	AddItemsToPanel(Items, Panel, checkPanel = "")
	{
		if checkPanel 	;this is used to prevent an item from showing up in both panels when first adding them
			checkPanel := this.otherPanel(Panel)
		if isobject(Items)
		{
			for index, item in items
				if (!isItemInListView(Item, Panel) && ( (checkPanel && !isItemInListView(Item, checkPanel)) || !checkPanel) )
					addItemsToListview(item, Panel)
		}
		Else
			if (!isItemInListView(Items, Panel) && ( (checkPanel && !isItemInListView(Item, checkPanel)) || !checkPanel) )
				addItemsToListview(Items, Panel)
		this.ModifyCol()
		return
	}

	MoveSelectedAvailableToCurrent()
	{
		aSelected := retrieveSelectedItemsFromListView(this.Available)
		for index, item in aSelected
			this.TransferItemsBetweenPanels(this.Available, this.current, item)
		this.ModifyCol()
		this.storeItems()
		return

	}
	MoveSelectedCurrentToAvailable()
	{
		aSelected := retrieveSelectedItemsFromListView(this.current)
		for index, item in aSelected
			this.TransferItemsBetweenPanels(this.current, this.Available, item)
		this.ModifyCol()
		this.storeItems()
		return

	}

	TransferItemsBetweenPanels(Origin, Deistination, Items, RemoveOriginals = True)
	{
		if isobject(Items)
		{
			for index, item in items
			{
				if !isItemInListView(Item, Deistination)
					addItemsToListview(item, Deistination)
				if RemoveOriginals
					removeItemFromListView(Item, Origin)
			}
		}
		Else
		{
			if !isItemInListView(Items, Deistination)
					addItemsToListview(Items, Deistination)	
			if RemoveOriginals
					removeItemFromListView(Items, Origin)
		}
		this.ModifyCol()
		this.storeItems()
		return
	}
}

	ModifyColListView(ListView = "", options = "")
	{
		if ListView
			Gui, ListView, %ListView% ;note all future and current threads now refer to this listview!
		if options
		{
			Columns := LV_GetCount("Column") 	;needed, as you must do each column individually if specifying options
			while (A_Index <= Columns)
				LV_ModifyCol(A_Index, options)	
		}
		else LV_ModifyCol()	
		return
	}
	isItemInListView(Item, ListView="")
	{
		if ListView
			Gui, ListView, %ListView% ;note all future and current threads now refer to this listview!
		a := []
		while (a_index <= LV_GetCount())
		{
			LV_GetText(OutputVar, a_index)
			if (OutputVar = Item)
				return 1
		}
		return 0
	}
	retrieveSelectedItemsFromListView(ListView="", byref count = "")
	{ 

		if ListView
			Gui, ListView, %ListView% ;note all future and current threads now refer to this listview!
		a := []
		while (nextItem := LV_GetNext(nextItem)) ;return next item number for selected items - then returns 0 when done
		{
			LV_GetText(OutputVar, nextItem)
			a.insert(OutputVar)
			count++
		}

		return a
	}



	addItemsToListview(item, ListView="")
	{
		if ListView
			Gui, ListView, %ListView% ;note all future and current threads now refer to this listview!
		LV_Add("", item, "")
		return
	}

	removeItemFromListView(Item, ListView="")
	{
		if ListView
			Gui, ListView, %ListView% ;note all future and current threads now refer to this listview!
		a := []
		while (a_index <= LV_GetCount())
		{
			LV_GetText(OutputVar, a_index)
			if (OutputVar = Item)
				LV_Delete(a_index) 
		}
		return
	}
	retrieveItemsFromListView(ListView="")
	{

		if ListView
			Gui, ListView, %ListView% ;note all future and current threads now refer to this listview!
		a := []
		while (a_index <= LV_GetCount())
		{
			LV_GetText(OutputVar, a_index)
			a.insert(OutputVar)
		}
		return a
	}
	removeAllItemsFromListView(ListView="")
	{	
		if ListView
			gui, ListView, %ListView% ;note all future and current threads now refer to this listview!
		return LV_Delete() ; 1 on success 
	}
	GetItemCountFromListView(ListView="")
	{	
		if ListView
			gui, ListView, %ListView% ;note all future and current threads now refer to this listview!
		return LV_GetCount() ;
	}

local_minerals(ByRef Return_Base_index, SortBy="Index") ;Returns a list of [Uints] index position for minerals And optionaly the [unit] index for the local base
{	;	Nexus = 90 CommandCenter = 48 Hatchery = 117
	;sc2_unit_count := getUnitCount()		;can put the count outside the loop for this
	while ( A_Index <= getUnitCount()) 
	{
		unit := A_Index - 1
		type := getUnitType(unit)
		IF isUnitLocallyOwned(unit)
		AND ( type = 90 OR type = 48 OR type = 117 )
			Base_loc_index := unit	;
		Else IF type = 253 ; 253 = Normal Mineral patch
			MineraList .= unit "|"  ; x|x|
	}
	MineraList := SubStr(MineraList, 1, -1)	;remove the trailing |
	loop, parse, MineraList, | 
	{
		IF areUnitsNearEachOther( A_LoopField, Base_loc_index, 8, 8) ; 1 if near
			Result .= A_LoopField "|"
	}
	MineraList := RTrim(Result, "| ")
	If (SortBy = "Distance")
		MineraList := sortUnitsByDistance(Base_loc_index, MineraList) 
	IF IsByRef(Return_Base_index)
		Return_Base_index := Base_loc_index
	Return MineraList
}

sortUnitsByDistance(Base, unitlist="", units*)
{ 	; accepts a "|" delimeter list, OR a variadic list
	List := []		;used to sort mineral patches by closest
	if unitlist		;but still doesnt find the 3 relative closest patches
	{				;probably due to where 'nexus' is - look at this later.
		units := []	;actually unit x,y seems to be from the centre of the unit.
		loop, parse, unitlist, |
			units[A_index] := A_LoopField
	}	
	for index, unit in units
	{
		Base_x := getUnitPositionX(Base), Base_y := getUnitPositionY(Base)
		unit_x := getUnitPositionX(unit), unit_y := getUnitPositionY(unit)
		List[A_Index] := {Unit:unit,Distance:Abs(Base_x - unit_x) + Abs(Base_y - unit_y)}	
	}
	bubbleSort2DArray(List, "Distance")
	For index, obj in List
		SortedList .= List[index].Unit "|"
	return RTrim(SortedList, "|")
} 

SortUnitsByMapOrder(unitlist="", units*)
{ 	; accepts a "|" delimeter list, OR a variadic list
	List := []		;used to sort mineral patches by from left to right, or top to bottom
	if unitlist		
	{			
		units := []
		loop, parse, unitlist, |
			units[A_index] := A_LoopField
	}	
	for index, unit in units
		List[A_Index] := {Unit:unit, X: getUnitPositionX(unit), Y: getUnitPositionY(unit)}	

	bubbleSort2DArray(List, "X") ;3rd param def 1 OR ascending
	For index, obj in List
	{
		If (index = List.minindex())
			X_Min := List[index].X
		If (index = List.MaxIndex())
			X_Max := List[index].X
	}
	bubbleSort2DArray(List, "Y")
	For index, obj in List
	{
		If (index = List.minindex())
			Y_Min := List[index].Y
		If (index = List.MaxIndex())
			Y_Max := List[index].Y
	}		 
	If (X_Delta := Abs(X_Max-X_Min)) > (Y_Delta := Abs(Y_Max-Y_Min))
	{
		bubbleSort2DArray(List, "X")
		For index, obj in List
			SortedList .= List[index].Unit "|"
	}
	else 
	{
		bubbleSort2DArray(List, "Y")
		For index, obj in List
			SortedList .= List[index].Unit "|"	
	}
	return RTrim(SortedList, "|")
} 


areUnitsNearEachOther(unit1, unit2, x_max_dist = "", y_max_dist = "", compareZ = 1)
{
	if !(x_max_dist || y_max_dist)
		Return "One max distance is required!"
	Else If  !y_max_dist
		y_max_dist := x_max_dist
	Else x_max_dist := y_max_dist

	x_dist := Abs(getUnitPositionX(unit1) - getUnitPositionX(unit2))
	y_dist := Abs(getUnitPositionY(unit1) - getUnitPositionY(unit2))																									
																								; there is a substantial difference in height even on 'flat ground' - using a max value of 1 should give decent results
	Return Result := (x_dist > x_max_dist) || (y_dist > y_max_dist) || (compareZ && Abs(getUnitPositionZ(unit1) - getUnitPositionZ(unit2)) > 1) ? 0 : 1 ; 0 Not near
}





Get_Bmap_pixel(u_array_index_number, ByRef Xvar, ByRef Yvar)
{
local u_x, u_y, tx, ty

	P_Xcam := getPlayerCameraPositionX()
	P_Ycam := getPlayerCameraPositionY() + (7142/4096)

	u_x := getUnitPositionX(u_array_index_number)
	u_y := getUnitPositionY(u_array_index_number)


	X_Bmap_conv := 950/(61954/4096)  ; pixel/map_X
	if (u_x >= P_Xcam)
	{
		u_x := u_x - P_Xcam 	; Hence relative to camera
		tx := u_x * X_Bmap_conv
		tx := 960 + tx
	}
	Else
	{
		u_x := P_Xcam  - u_x
		tx := u_x * X_Bmap_conv
		tx := 960 - tx
	}

	if (u_y >= P_Ycam)
	{
	;	SoundPlay *-1
		u_y := u_y - P_Ycam
	;	Y_Bmap_conv_T := 375/(41661/4096)		 ; (for top)
	;	Y_Bmap_conv := (375/7.89) *.7
	;	Y_Bmap_conv := (u_y/(41661/4096)) *	375/(41661/4096) *1.3
		Y_Bmap_conv :=  375/ (10.17114 - (5.6 + (u_y/(41661/4096)))*.1)

		ty := u_y * Y_Bmap_conv	
		ty := 375 - ty
	}
	Else
	{
		u_y := P_Ycam - u_y
		Y_Bmap_conv := 375/ (7.89 - (5.6 - (u_y/(22976/4096)) *	3.5 ))
		ty := u_y * Y_Bmap_conv	
		ty := 375 + ty
	}
	If IsByRef(Xvar)
		Xvar := Round(tx)
	IF IsByRef(Yvar)
		Yvar := Round(ty)
	if (Xvar < 15 || Xvar > A_ScreenWidth-15) || (Yvar < 15) ; the mouse will push on/move the screen 
		Return 1
}
getBuildingList(F_building_var*)	
{ 
	Unitcount := DumpUnitMemory(MemDump)
	while (A_Index <= Unitcount)
	{
		unit := A_Index - 1
	    if isTargetDead(TargetFilter := numgetUnitTargetFilter(MemDump, unit)) || !isOwnerLocal(owner := numgetUnitOwner(MemDump, Unit))
	       Continue
	    pUnitModel := numgetUnitModelPointer(MemDump, Unit)
	    Type := numgetUnitModelType(pUnitModel)
	    For index, building_type in F_building_var
		{	
			IF (type = building_type && !isTargetUnderConstruction(TargetFilter))
				List .= unit "|"  ; x|x|	
		}

	}	
	List := SubStr(List, 1, -1)	
	sort list, D| Random
	Return List
}

isTargetDead(TargetFilter)
{	global aUnitTargetFilter
	return TargetFilter & aUnitTargetFilter.Dead
}

isTargetUnderConstruction(TargetFilter)
{	global aUnitTargetFilter
	return TargetFilter & aUnitTargetFilter.UnderConstruction
}

; Note Currently used!
isUserCastingOrBuilding()	;note auto casting e.g. swarm host will always activate this. There are separate bool values indicating buildings at certain spells
{	global
	return pointer(GameIdentifier, P_IsUserCasting, O1_IsUserCasting, O2_IsUserCasting, O3_IsUserCasting, O4_IsUserCasting)
}


filterSlectionTypeByEnergy(EnergyFilter="", F_utype*) ;Returns the [Unit] index number
{	
	selection_i := getSelectionCount()
	while (A_Index <= selection_i)		;loop thru the units in the selection buffer	
	{	
		unit := getSelectedUnitIndex(A_Index -1)
		type := getUnitType(Unit)
		If (EnergyFilter = "")
			For index, F_Found in F_utype
			{
				If (F_Found = type)
					Result .= unit "|"		;  selctio buffer refers to 0 whereas my [unit] did begin at 1
			}		
		Else
			For index, F_Found in F_utype
			{
				If (F_Found = type) AND (EnergyFilter <= getUnitEnergy(unit))
					Result .= unit "|"	
			}	
	}	
	Return Result := SubStr(Result, 1, -1)		
}

Edit_AG:	;AutoGroup and Unit include/exclude come here
	TMP_AG_ControlName := SubStr(A_GuiControl, 2)
	GuiControlGet, TMP_EditAG_Units,, %TMP_AG_ControlName%

	IfInString, A_GuiControl, Terran
		Race := "Terran"
	else IfInString, A_GuiControl, Protoss
		Race := "Protoss"
	else IfInString, A_GuiControl, Zerg
		Race := "Zerg"
	Else
		Race := "All"
	IfInString, A_GuiControl, UnitHighlight
		TMP_EditAG_Units .= AG_GUI_ADD("", TMP_EditAG_Units ? 1 : 0, Race)
	Else
		TMP_EditAG_Units .= AG_GUI_ADD(SubStr(A_GuiControl, 0, 1), TMP_EditAG_Units ? 1 : 0, Race) ;retrieve the last character of name ie control number 0/1/2 etc		
	GUIControl,, %TMP_AG_ControlName%, %TMP_EditAG_Units%
Return
AG_GUI_ADD(Control_Group = "", comma=1, Race=1)
{
	static F_drop_Name 	; as a controls variable must by global or static
	global l_UnitNames, l_UnitNamesTerran, l_UnitNamesProtoss, l_UnitNamesZerg

	If (Control_Group = "")
		Title := "Select Unit"
	else Title := "Auto Group " Control_Group
	if (race = "Terran")
		list := l_UnitNamesTerran
	else if (race = "Protoss")
		list := l_UnitNamesProtoss
	else if (race = "Zerg")
		list := l_UnitNamesZerg
	else list := l_UnitNames



	Gui, Add2AG:Add, Text, x5 y+10, Select Unit Type:
	Gui, Add2AG:Add, ListBox, x5 y+10 w150 h280 VF_drop_Name  sort, %list%
	Gui, Add2AG:Add, Button, y+20 x5 w60 h35 gB_ADD, Add
	Gui, Add2AG:Add, Button, yp+0 x95 w60 h35  gB_close, Close
	GUI, Add2AG:+AlwaysOnTop +ToolWindow
	GUI, Add2AG:Show, w160 h380, %Title%
	Gui, Add2AG:+OwnerOptions
	Gui, Options:+Disabled
 	;return ;cant use return here, otherwise script will continue running immeditely after the functionc call
	pause	
						; ****also note, the function will jump to bclose but aftwards will continue from here linearly down
	B_ADD:				;hence have to check whether to return any value
	Gui, Options:-Disabled
	Gui, Options:Show		;required to keep from minimising
	Gui, Add2AG:Submit
	Gui Add2AG:Destroy
	;GuiControlGet, Edit_Unit_name,, F_drop_Name
	pause off

	if (close <> 1)
		Return comma = 1 ? ", " F_drop_Name : F_drop_Name
	Return 

	B_Close:
	Add2AGGUIEscape:
    Add2AGGUIClose:
	Close := 1
	Gui, Options:-Disabled
	Gui Add2AG:Destroy
	pause off
	Return ;this is needed to for the above if (if the cancel/escape gui)

}


; there is an 'if' section in the bufferinput send that checks if the user pressed the Esc key
; if they did, it gosubs here
g_temporarilyDisableAutoWorkerProductionOriginUserInputBufferSend:	
If !(WinActive(GameIdentifier) && time && !isMenuOpen() && EnableAutoWorker%LocalPlayerRace%)
		return
; So will turn off autoworker for 5 seconds only if user presses esc and only that main is selected
g_temporarilyDisableAutoWorkerProduction:
if EnableAutoWorker%LocalPlayerRace% ; dont check TmpDisableAutoWorker so if cancels another builder a few seconds later it will still update it 
	temporarilyDisableAutoWorkerProduction()
return 

g_UserToggleAutoWorkerState: 		; this launched via the user hotkey combination
	if (EnableAutoWorker%LocalPlayerRace% := !EnableAutoWorker%LocalPlayerRace%)
	{
		AW_MaxWorkersReached := TmpDisableAutoWorker := 0 		; just incase the timers bug out and this gets stuck in enabled state
		SetTimer, g_autoWorkerProductionCheck, -1   ; so it starts immediately - cant use gosub as that negates
		tSpeak("On")											; the sleep/timer linearity and causes double workers to be made when first turned on
		SetTimer, g_autoWorkerProductionCheck, 200
	}
	else 
	{
		SetTimer, g_autoWorkerProductionCheck, off
		tSpeak("Off")
	}

return 

g_RenableAutoWorkerState:	; this is via the auto cancel in the below function (when user cancels last building worker)
	TmpDisableAutoWorker := 0
return 

; note use can accidentally delay production by pressing esc to cancel chat

temporarilyDisableAutoWorkerProduction()
{ 	LOCAL unitIndex, selectedUnit, QueueSize
	if (getSelectionCount() = 1)
	{
		unitIndex := getSelectedUnitIndex()
		selectedUnit := getUnitType(unitIndex)
		if (selectedUnit = aUnitID["PlanetaryFortress"] || selectedUnit = aUnitID["CommandCenter"] 
		|| selectedUnit = aUnitID["OrbitalCommand"] || selectedUnit = aUnitID["Nexus"])
		&& !isUnderConstruction(unitIndex) ; so wont toggle when cancelling a main which is being built
		{
			getBuildStats(unitIndex, QueueSize)
			if (QueueSize <= 2) ; so wont toggle timer if cancelling extra queued workers
			{
				TmpDisableAutoWorker := 1
				SetTimer, g_RenableAutoWorkerState, -4500 ; give time for user to morph/lift base ; use timer so dont have this function queueing up
			}
		}
	}
	return 
}

g_autoWorkerProductionCheck:
if (WinActive(GameIdentifier) && time && EnableAutoWorker%LocalPlayerRace% && !TmpDisableAutoWorker && !AW_MaxWorkersReached  )
	autoWorkerProductionCheck()
return

autoWorkerProductionCheck()
{	GLOBAl aUnitID, aLocalPlayer, Base_Control_Group_T_Key, AutoWorkerStorage_P_Key, AutoWorkerStorage_T_Key, Base_Control_Group_P_Key, NextSubgroupKey
	, AutoWorkerMakeWorker_T_Key, AutoWorkerMakeWorker_P_Key, AutoWorkerMaxWorkerTerran, AutoWorkerMaxWorkerPerBaseTerran
	, AutoWorkerMaxWorkerProtoss, AutoWorkerMaxWorkerPerBaseProtoss, AW_MaxWorkersReached
	, aResourceLocations, aButtons, EventKeyDelay
	, AutoWorkerAPMProtection, AutoWorkerQueueSupplyBlock, MT_CurrentGame, aUnitTargetFilter
	
	static TickCountRandomSet := 0, randPercent,  UninterruptedWorkersMade, waitForOribtal := 0


	if (aLocalPlayer["Race"] = "Terran") 
	{
		mainControlGroup := Base_Control_Group_T_Key
		controlstorageGroup := AutoWorkerStorage_T_Key
		makeWorkerKey := AutoWorkerMakeWorker_T_Key
		maxWorkers := AutoWorkerMaxWorkerTerran
		maxWorkersPerBase := AutoWorkerMaxWorkerPerBaseTerran
	}
	else if (aLocalPlayer["Race"] = "Protoss") 
	{
		mainControlGroup := Base_Control_Group_P_Key
		controlstorageGroup := AutoWorkerStorage_P_Key
		makeWorkerKey := AutoWorkerMakeWorker_P_Key
		maxWorkers := AutoWorkerMaxWorkerProtoss
		maxWorkersPerBase := AutoWorkerMaxWorkerPerBaseProtoss
	}
	else return

	; This simply adds a bit more randomness.
	; So if checking match history, you dont stop at exactly 70 workers
	; ever game

	if !MT_CurrentGame.MaxWorkers 
		MT_CurrentGame.MaxWorkers := maxWorkers + rand(-3, 2)
	maxWorkers :=  MT_CurrentGame.MaxWorkers

	workers := getPlayerWorkerCount()

	if (workers >= maxWorkers)
	{ 
		AW_MaxWorkersReached := True
		UninterruptedWorkersMade := 0 
		return 
	}
	if isGamePaused() || isMenuOpen() ;chat is 0 when  menu is in focus
		return ;as let the timer continue to check

	numGetControlGroupObject(oMainbaseControlGroup, mainControlGroup)
	workersInProduction := Basecount := almostComplete := idleBases := halfcomplete := nearHalfComplete := 0 ; in case there are no idle bases


	; This will change the random percent every 12 seconds - otherwise
	; 200ms timer kind of negates the +/- variance on the progress meter
	if (A_TickCount - TickCountRandomSet > 12 * 1000) 
	{
		TickCountRandomSet := A_TickCount
		randPercent := rand(-0.10, .20) ; rand(-0.04, .15) 
	}

	for index, object in oMainbaseControlGroup.units
	{
		if ( object.type = aUnitID["CommandCenter"] || object.type = aUnitID["OrbitalCommand"]
		|| object.type = aUnitID["PlanetaryFortress"] || object.type = aUnitID["Nexus"] )
		&& !isUnderConstruction(object.unitIndex) 
		{
			; this is for terran, so if build cc inside base, wont build up to 60 workers even though 2 bases, but just 1 mining
			for index, geyser in aResourceLocations.geysers
				if isUnitNearUnit(geyser, object, 7.9) ; also compares z but for 1 map unit ; so if the base is within 8 map units it counts. It seems geyers are generally no more than 7 or 7.5 away
				{
					Basecount++ ; for calculating max workers per base
					break
				}
			oBasesToldToBuildWorkers.insert({unitIndex: object.unitIndex, type: object.type})
			if !isWorkerInProduction(object.unitIndex) ; also accounts for if morphing 
				idleBases++
			else 
			{
				if (object.type = aUnitID["PlanetaryFortress"])
					progress :=  getBuildStatsPF(object.unitIndex, QueueSize)
				else
					 progress := getBuildStats(object.unitIndex, QueueSize) ; returns build percentage
				 if (QueueSize = 1)
				 {
				 	if (progress >= .97)
				 		almostComplete++
				 	else if (progress - randPercent >= .65)
				 		halfcomplete++
				 	else if (progress >= .35)
				 		nearHalfComplete++
				 }
				 workersInProduction += QueueSize
			}
			TotalCompletedBasesInCtrlGroup++
			L_ActualBasesIndexesInBaseCtrlGroup .= "," object.unitIndex
		}
		else if ( object.type = aUnitID["CommandCenterFlying"] || object.type = aUnitID["OrbitalCommandFlying"] )
		&& !isUnderConstruction(object.unitIndex) 
			Basecount++ 	; so it will (account for flying base) and keep making workers at other bases if already at max worker/base	
		L_BaseCtrlGroupIndexes .= "," object.unitIndex ; this is just used as a means to check the selection
	}

	if (workers / Basecount >= maxWorkersPerBase)
		return

	
	if (AutoWorkerQueueSupplyBlock && getPlayerSupply() < 200)
		MaxWokersTobeMade := howManyUnitsCanBeProduced(50)
	else MaxWokersTobeMade := howManyUnitsCanBeProduced(50, 0, 1)

	if (MaxWokersTobeMade > TotalCompletedBasesInCtrlGroup) 	
		MaxWokersTobeMade := TotalCompletedBasesInCtrlGroup

	if (MaxWokersTobeMade > idleBases + almostComplete + halfcomplete)
		MaxWokersTobeMade := idleBases + almostComplete + halfcomplete

	if (MaxWokersTobeMade + workersInProduction + workers >= maxWorkers)
		MaxWokersTobeMade := maxWorkers - workers - workersInProduction

	; this will give the player a few seconds or so to convert the orbital before it makes another worker

	; Rax takes 65s to build - has 1000 hp  so 15.3866 hp/s
	; worker takes 17s to build

	; lowest 55% completed of a svc before another is made- so 7.65 s remaining on scv build time
	; 7.65 * 15.3866 = 876.9072 - so rax should have more than 876 hp
	; obviously this wont work correctly if the rax is being attacked 

	if (MaxWokersTobeMade && TotalCompletedBasesInCtrlGroup <= 2 && aLocalPlayer["Race"] = "Terran" && !MT_CurrentGame.HasSleptForObital)
	{
		; So the user is a noob and isn't making an orbital 
		; lets not iterate all of the units unnecessarily
		if (getPlayerWorkersBuilt() > 20)
			MT_CurrentGame.HasSleptForObital := True
		for index, base in oMainbaseControlGroup.units
		{	
		;	; user already has at least one upgraded CC so lets not bother
			if (base.type = aUnitID["OrbitalCommand"] 
				|| base.type = aUnitID["OrbitalCommandFlying"] 
				|| base.type = aUnitID["PlanetaryFortress"])
				MT_CurrentGame.HasSleptForObital := True

			; this will prevent a pause if the user has no CCs
			; or 1 is already being upgraded
			if (base.type = aUnitID["CommandCenter"])
			{
				if isCommandCenterMorphing(base.UnitIndex)
					MT_CurrentGame.HasSleptForObital := True
				else 
					CommandCenterInCtrlGrp := True
			}
		}

		; No command centre, so lets not bother
		if !CommandCenterInCtrlGrp
			MT_CurrentGame.HasSleptForObital := True

		if !MT_CurrentGame.HasSleptForObital
		{
			Unitcount := DumpUnitMemory(MemDump)
			while (A_Index <= Unitcount)
			{
				TargetFilter := numgetUnitTargetFilter(MemDump, unit := A_Index - 1)
				if (TargetFilter & aUnitTargetFilter.Dead 
					|| numgetUnitOwner(MemDump, Unit) != aLocalPlayer["Slot"]
					|| numgetUnitModelType(numgetUnitModelPointer(MemDump, Unit)) != aUnitID["Barracks"])
			    	Continue

			    if !(TargetFilter & aUnitTargetFilter.UnderConstruction)
			    {
			    	BarracksHasFinished := True
			    	break
			    }
			    if (highestHPRax < 1000 - getUnitHpDamage(unit))
			    	highestHPRax := 1000 - getUnitHpDamage(unit)
			}
		}																	
		if (!MT_CurrentGame.HasSleptForObital && (highestHPRax > 850 || BarracksHasFinished))  
		{
			MT_CurrentGame.HasSleptForObital := True 
			if !A_IsCompiled ; testing
			{
				loop, 4 
				{
					soundplay *-1
					sleep 200
				}
				sleep 10200 ;11000
			}
			else sleep, 11000
			return
		}
	}

	; This will on occasion queue more than 1 workers, only if the player is floating a lot of extra minerals though
	; Just to make the automation a little bit more random
	if (MaxWokersTobeMade && rand(1, 5) = 1) 
	{
		pMinerals := getPlayerMinerals() 
		if (TotalCompletedBasesInCtrlGroup = 1 && pMinerals >= 540 && getPlayerWorkersBuilt() > 18)
			MaxWokersTobeMade := 2
		else if (TotalCompletedBasesInCtrlGroup >= 2 && pMinerals >= 1500)
			MaxWokersTobeMade := round(MaxWokersTobeMade * 2.2)
		else if (TotalCompletedBasesInCtrlGroup >= 2 && pMinerals >= 800)
			MaxWokersTobeMade := round(MaxWokersTobeMade * 1.75)
	}

	currentWorkersPerBase := (workers + workersInProduction)  / Basecount
	if ( (MaxWokersTobeMade / Basecount) + currentWorkersPerBase >= maxWorkersPerBase )
		MaxWokersTobeMade := round((maxWorkersPerBase - currentWorkersPerBase) * Basecount)

	; this attempts to minimise the number of 'auto productions' per worker production cycle.
	; to reduce the chances of interfering with user input
	; it will make workers if a worker is >= 95% complete (and only 1 in queue) or there are idle bases
	; when it does this it will also make workers for bases where the worker is >= 65% complete  (and only 1 in queue)
	; no workers will be made there are workers between 45% and 65% and no idle bases or almost completed queues

	if (MaxWokersTobeMade >= 1) && (idleBases || almostComplete || (halfcomplete && !nearHalfComplete)  ) ; i have >= 1 in case i stuffed the math and end up with a negative number or a fraction
	{

		While (isUserPerformingActionIgnoringCamera() || getKeyState("LButton") ||   getKeyState("LButton", "P")
		||  getKeyState("RButton") || getKeyState("RButton", "P") ||  getKeyState("MButton") || getKeyState("MButton", "P")
		|| getkeystate("Shift") || getkeystate("Ctrl") || getkeystate("Alt")
	;	|| getkeystate("Alt") || getkeystate("Alt", "P")
		|| getkeystate("Shift", "P") || getkeystate("Ctrl", "P") || getkeystate("Alt", "P")
		|| getkeystate("LWin") || getkeystate("RWin")
		|| getkeystate("Enter") ; required so chat box doesnt get repoened when user presses enter to close the chat box
		||  MT_InputIdleTime() < 50
		|| getPlayerCurrentAPM() > AutoWorkerAPMProtection) ; probably dont need this anymore
		{
			if (A_index > 24)
				return ; timed out after 120 ms
			sleep 1
		}
		
		if (!isSelectionGroupable(oSelection) || isGamePaused() || isMenuOpen())
			return

		; remove when i have updated the other functions
		;**********************
		Global pClickDelay
		input.pClickDelay(-1)


		Thread, NoTimers, true
		input.hookBlock(True, True)
		upsequence := Input.releaseKeys()
		critical, 1000
		input.hookBlock(False, False)
	;	if upsequence
	;		DllCall("Sleep", Uint, 15) ;  sleep, 5
	;	if (upsequence && IsKeyDownSC2Input())
	;		SendInput, {BLIND}%upsequence%
		dSleep(15) ; increase safety ensure selection buffer fully updated

		HighlightedGroup := getSelectionHighlightedGroup()
		If numGetSelectionSorted(oSelection) ; = 0 as nothing is selected so cant restore this/control group it
		{ 

			if !oSelection.IsGroupable
			{
				Input.revertKeyState()
				input.pClickDelay(pClickDelay) ;***********
				return		
			}
			selctionUnitIndices := oSelection.IndicesString
			loop, parse, selctionUnitIndices, `,
			{
				if A_LoopField not in %L_BaseCtrlGroupIndexes%	 ; so if a selected unit isnt in the base control group			
					BaseControlGroupNotSelected := 1
			}
			; This function is mainly for the auto-control group. So when a user clicks on a finished CC
			; it will get auto-grouped, but wont immediately make an SCV (which would prevent converting
			; it into an orbital), the user has 4 real seconds from clicking it to convert it
			; before SCV production recommences
			; Dont need to check if locally owned CC as the function above already 
			; did this
			if (TotalCompletedBasesInCtrlGroup >= 2 && oSelection.count = 1
				&& oSelection.units[1].type = aUnitID["CommandCenter"]
				&& isInControlGroup(mainControlGroup, oSelection.units[1].UnitIndex) )
			{
				if !IsObject(MT_CurrentGame.CommandCenterPauseList) ; because MT_CurrentGame gets cleared each game
					MT_CurrentGame.CommandCenterPauseList := []
				else 
				{
					for index, UnitIndex in MT_CurrentGame.CommandCenterPauseList
					{
						if (UnitIndex = oSelection.units[1].UnitIndex)
							CommandCenterInList := True
					}
				}
				if !CommandCenterInList
				{
					MT_CurrentGame.CommandCenterPauseList.insert(oSelection.units[1].UnitIndex)
					Input.revertKeyState()
					critical, off
					Thread, NoTimers, false 
					input.pClickDelay(pClickDelay) ; ********
					sleep 4500
					return
				}

			}

			; so even if the just the bases out of the base control group are selected (as other structures can be grouped with it)
			; it wont send the base control group button as its not required
			; Another scenario if there are 3 bases in ctrl group, and 1 is flying, if the user has the  two landed bases selected
			; it still wont send the base control group, as its not required
			; cant do a if L_ActualBasesIndexesInBaseCtrlGroup < makeWorkerCount - as you could end up with
			; an already queued base getting sent workers while the non-selected idle base remains idle 
			if !BaseControlGroupNotSelected
			{
				loop, parse, selctionUnitIndices, `,
					if A_LoopField in %L_ActualBasesIndexesInBaseCtrlGroup%
						SelectedBasesCount++
				if (SelectedBasesCount < TotalCompletedBasesInCtrlGroup)
					BaseControlGroupNotSelected := True
			}

			; one thing to remember about these (L_SelectionIndexes != L_BaseCtrlGroupIndexes) 
			; if a unit in the base group gets killed
			; then these can never be Equal until the user re-issues the base control group
			; so this may control group the units even when these bases are selected
			; better to be safe than sorry!
			; thats why im doing it slightly different now

			if BaseControlGroupNotSelected ; hence if the 'main base' control group is already selected, it wont bother control grouping them (and later restoring them)
			{
				numGetControlGroupObject(oControlstorage, controlstorageGroup) 	; this checks if the currently selected units match those
				for index, object in oControlstorage.units 							; already stored in the ctrl group
				{	
					L_ControlstorageIndexes .= "," object.unitIndex 				; if they do, it wont bother sending the store control group command
					if !isUnitLocallyOwned(object.unitIndex) 			; as unit may have died and its unitIndex is reused
					{
						setControlGroup := True
						break
					}
				}
				if (setControlGroup || oSelection.IndicesString != subStr(L_ControlstorageIndexes, 2))  
					MTsend("^" controlstorageGroup )
				MTsend(mainControlGroup)
				dSleep(10) ; wont have that many units grouped with the buildings so 10ms should be plenty
				numGetSelectionSorted(oSelection)
			}

			; These terran mains are in order as they
			; would appear in the  selection group
			if (aLocalPlayer.Race = "Protoss")
				tabPosition := 	oSelection.TabPositions[aUnitId.Nexus]
			else if oSelection.TabPositions.HasKey(aUnitId.OrbitalCommand)
				tabPosition := oSelection.TabPositions[aUnitId.OrbitalCommand]
			else if oSelection.TabPositions.HasKey(aUnitId.CommandCenter)
				tabPosition := oSelection.TabPositions[aUnitId.CommandCenter]
			else if oSelection.TabPositions.HasKey(aUnitId.PlanetaryFortress)
				tabPosition := oSelection.TabPositions[aUnitId.PlanetaryFortress]			
			clipboard := tabPosition
			if BaseControlGroupNotSelected
				sendSequence .= sRepeat(NextSubgroupKey, tabPosition)
			else 
			{
				if (oSelection.HighlightedId != aUnitId.Nexus
					&& oSelection.HighlightedId != aUnitId.OrbitalCommand
					&& oSelection.HighlightedId != aUnitId.CommandCenter
					&& oSelection.HighlightedId != aUnitId.PlanetaryFortress)
					sendSequence .= sRepeat(NextSubgroupKey, tabPositionChanged := oSelection["Types"]  - HighlightedGroup + tabPosition)
			}
			; other function gets spammed when user incorrectly adds a unit to the main control group 
			; (as it will take subgroup 0) and for terran tell that unit to 'stop' when sends s
			sendSequence .= sRepeat(makeWorkerKey, MaxWokersTobeMade)

			; i tried checking the selection buffer for non.structure units and this worked well for 4 days, then all of a sudden it started giving false errors
			; This is probably due to insufficient sleep time to update the selection buffer (3ms)
			; i cant be bothered looking into it
			; so now im just checking if macro has ran too many times (as if worker is will/attempted  it will sleep for  800ms)
			; this isnt perfect or fool proof, but it should work well enough, and quickly enough to prevent interrupting the user
			; for longer than 4 or 5 seconds if they stuff up their base control group

			; this slow checking allows the user to have as many bases as they want e.g. 7,8, 9 or more which could cause this function to run
			; and make a worker 5 times in a row without any risk of falsely activating the the control group error routine
			
			; should need this anymore
			if (UninterruptedWorkersMade > 6) ; after 4 days this started giving an error, so now i have added an additional sleep time 
			{
				dSleep(5)
				numGetUnitSelectionObject(oSelection) 	; can't use numgetControlGroup - as when nexus dies and is replaced with a local owned unit it will cause a warning
				for index, object in oSelection.units
					if !isUnitAStructure(object.unitIndex)	; as units will have higher priority and appear in group 0/top left control card - and this isnt compatible with this macro
						BaseCtrlGroupError := 1					; as the macro will tell that unit e.g. probe to 'make a worker' and cause it to bug out
			}
			MTsend(sendSequence), sendSequence := ""
			if BaseControlGroupNotSelected
			{
				dSleep(5)	
				MTsend(controlstorageGroup)
				dSleep(15)
				if HighlightedGroup
					MTsend(sRepeat(NextSubgroupKey, HighlightedGroup))				
			}
			else if tabPositionChanged ; eg the ebay or floating CC is selected is the selected tab in the already selected base control group
				MTsend(sRepeat(NextSubgroupKey, oSelection["Types"]  - tabPosition + HighlightedGroup ))	

			WorkerMade := True
		}
		
		Input.revertKeyState()
		critical, off
		Thread, NoTimers, false 
		input.pClickDelay(pClickDelay) ; *********

	;	BaseCtrlGroupError := 0
		if BaseCtrlGroupError ; as non-structure units will have higher priority and appear in group 0/top left control card - and this isnt compatible with this macro
		{	; as the macro will tell that unit e.g. probe to 'make a worker' and cause it to bug out	
			tSpeak("Error in Base Control Group. Auto Worker")
			gosub g_UserToggleAutoWorkerState ; this will say 'off' Hence Will speak Auto worker Off	
			UninterruptedWorkersMade := 0 ; reset the count so when user fixes group it will work
			return 
		}

		if WorkerMade
		{
			UninterruptedWorkersMade++ ; keep track of how many workers are made in a row
			sleep, 800 	; this will prevent the timer running again otherwise sc2 slower to update 'isin production' 
		}		 	; so will send another build event and queueing more workers
					; 400 worked find for stable connection, but on Kr sever needed more. 800 seems to work well
	}
	else UninterruptedWorkersMade := 0
	return
}

isSelectionGroupable(ByRef oSelection)
{	GLOBAl aLocalPlayer
	if !numGetUnitSelectionObject(oSelection) 	; No units selected
		return 0
	for index, object in oSelection.units 	; non-self unit selected, other wise will continually
		if (object.owner != aLocalPlayer.slot) ; click middle screen not alloying you to type
			return 0
	return 1
}

selectGroup(group, preSleep := -1, postSleep := 2)
{
	if (preSleep != -1)
		DllCall("Sleep", "Uint", preSleep)
	MTsend(group)
	if (postSleep != -1)
		DllCall("Sleep", "Uint", postSleep)
	return	
}

; r := sRepeat("as", 3)
; r = "asasas"
; 0 returns empty string
sRepeat(string, multiplier)
{
	if multiplier
	{
		loop, % multiplier 
			r .= string
	}
	else r := ""
	return r
}

ClickMinimapPlayerView()
{
	mapToMiniMapPos(getPlayerCameraPositionX(), getPlayerCameraPositionY(), x, y)
	pClick(x, y)
	return
}


varInMatchList(var, Matchlist)
{
	if var in %Matchlist%
		return 1
	else return 0
}


howManyUnitsCanBeProduced(mineralCost := 0, gasCost := 0, supplyUsage := 0)
{
	params := []
	if mineralCost
		params.insert(floor(getPlayerMinerals() / mineralCost))
	if gasCost
		params.insert(floor(getPlayerGas() / gasCost))
	if supplyUsage
		params.insert(floor(getPlayerFreeSupply() / supplyUsage))
	return lowestValue(params*)
}

lowestValue(aValues*)
{
	smallest := aValues[1]
	for index, value in aValues 
		if (value < smallest)
			smallest := value 
	return smallest
}

largestValue(aValues*)
{
	largest := aValues[1]
	for index, value in aValues 
		if (value > largest)
			largest := value 
	return largest
}

getPlayerFreeSupply(player="")
{ 	global aLocalPlayer
	If (player = "")
		player := aLocalPlayer["Slot"]
	freeSupply := getPlayerSupplyCap(player) - getPlayerSupply(player)
	if (freeSupply >= 0)
		return freeSupply 
	else return 0 ; as a negative value counts as true and would prevent using this in 'if freesupply() do' scenario
}


ReleaseAllModifiers() 
{ 	
	Global GameExe
	KeyDelay := A_KeyDelay
	MouseDelay := A_MouseDelay
	SetKeyDelay 10
	SetMouseDelay 10
	process, exist, %GameExe%
	SCExist := Errorlevel ; is exists error level = PID

	list = Control|Shift|Alt|LButton|RButton|MButton|Lwin|Rwin 
	Loop Parse, list, | ;could just not bother with the getkeystate check and send UP button regardless
	{ 
		; Better to have this if, otherwise if the emergency restart key has the windows modifiers the windows task
		; bar will pop up every press

		if (!GetKeyState(A_LoopField, "P") 
			&& ( GetKeyState(A_LoopField) ||  (SCExist && getSCModState(A_LoopField) )) ) 	;fix sticky key problem
			sendEvent {Blind}{%A_LoopField% up}       ; {Blind} is added. Just send every key
	} 
	SetKeyDelay %KeyDelay%
	SetMouseDelay %MouseDelay%     
} 

RestoreModifierPhysicalState()
{
	KeyDelay := A_KeyDelay
	MouseDelay := A_MouseDelay
	SetKeyDelay 10
	SetMouseDelay 10	
	list = LControl|RControl|LShift|RShift|LAlt
	Loop Parse, list, |
	{
		if (GetKeyState(A_LoopField) != GetKeyState(A_LoopField, "P")) ;if logical and physical state do not match
		 {
			if (GetKeyState(A_LoopField, "P")) ;send an event to restore the physical key state
				send {Blind}{%A_LoopField% down}
			else
				send {Blind}{%A_LoopField% up} ;trying blind here to see if it works
		 }
	 }
	SetKeyDelay %KeyDelay%
	SetMouseDelay %MouseDelay%   
}


tSpeak(Message, SAPIVol := "")
{	global speech_volume, aThreads

	if !SAPIVol
		SAPIVol := speech_volume
	aThreads.Speech.ahkFunction("speak", Message, SAPIVol)
	return
}




getSelectionType(units*) 
{
	if !units.MaxIndex() ;no units passed to function
		loop % getSelectionCount()				
			list .= getUnitType(getSelectedUnitIndex(A_Index - 1)) "|"
	Else
		for key, unit in units
			list .= getUnitType(getSelectedUnitIndex(A_Index - 1)) "|"
	Return SubStr(list, 1, -1)
}



setupAutoGroup(Race, ByRef A_AutoGroup, aUnitID, A_UnitGroupSettings)
{
	A_AutoGroup := []
	loop, 10
	{	
		ControlGroup := A_index - 1		;for control group 0			
	;	Race := substr(Race, 1, 4)	;cos used Terr in ini
		List := A_UnitGroupSettings[Race, ControlGroup]				
		StringReplace, List, List, %A_Space%, , All ; Remove Spaces
		StringReplace, List, List, |, `,, All ;replace | with ,
		List := Rtrim(List, "`, |") ;checks the last character
		If (List <> "")
		{
			loop, parse, List, `, 
			A_AutoGroup[ControlGroup] .= aUnitID[A_LoopField] ","	;assign the unit ID based on name from iniFile	
			A_AutoGroup[ControlGroup] := RTrim(A_AutoGroup[ControlGroup], ",") 
		}		 
	}
	Return
}


DrawMiniMap()
{	global
	local UnitRead_i, unit, type, Owner, Radius, Filter, EndCount, colour, ResourceOverlay_i, unitcount
	, DrawX, DrawY, Width, height, i, hbm, hdc, obm, G,  pBitmap, PlayerColours, A_MiniMapUnits
	static Overlay_RunCount
	Overlay_RunCount ++
	if (ReDrawMiniMap and WinActive(GameIdentifier))
	{
		Try Gui, MiniMapOverlay: Destroy
		Overlay_RunCount := 1
		ReDrawMiniMap := 0
	}
	If (Overlay_RunCount = 1)
	{
		; Set the width and height we want as our drawing area, to draw everything in. This will be the dimensions of our bitmap
		; Create a layered window ;E0x20 click thru (+E0x80000 : must be used for UpdateLayeredWindow to work!) that is always on top (+AlwaysOnTop), has no taskbar entry or caption		
		Gui, MiniMapOverlay: -Caption Hwndhwnd1 +E0x20 +E0x80000 +LastFound  +ToolWindow +AlwaysOnTop
		; Show the window
		Gui, MiniMapOverlay: Show, NA
		; Get a handle to this window we have created in order to update it later
	;	hwnd1 := WinExist()
	}
		; Create a gdi bitmap with width and height of what we are going to draw into it. This is the entire drawing area for everything
		hbm := CreateDIBSection(A_ScreenWidth/4, A_ScreenHeight) ;only draw on left side of the screen
		; Get a device context compatible with the screen
		hdc := CreateCompatibleDC()
		; Select the bitmap into the device context
		obm := SelectObject(hdc, hbm)
	; Get a pointer to the graphics of the bitmap, for use with drawing functions
	G := Gdip_GraphicsFromHDC(hdc) ;needs to be here
	DllCall("gdiplus\GdipGraphicsClear", "UInt", G, "UInt", 0)	
	if DrawMiniMap
	{
		setDrawingQuality(G)
		A_MiniMapUnits := []

 		getEnemyUnitsMiniMap(A_MiniMapUnits)

		for index, unit in A_MiniMapUnits
			drawUnitRectangle(G, unit.X, unit.Y, unit.Radius + minimap.AddToRadius, unit.Radius + minimap.AddToRadius)	;draw rectangles first
		for index, unit in A_MiniMapUnits
			FillUnitRectangle(G, unit.X, unit.Y,  unit.Radius, unit.Radius, unit.Colour)

	}
	If (DrawSpawningRaces) && (Time - round(TimeReadRacesSet) <= 14) ;round used to change undefined var to 0 for resume so dont display races
	{	Gdip_SetInterpolationMode(G, 7)				;TimeReadRacesSet gets set to 0 at start of match
		loop, parse, EnemyBaseList, |
		{		
			type := getUnitType(A_LoopField)
			getUnitMiniMapMousePos(A_LoopField, BaseX, BaseY)
			if ( type = aUnitID["Nexus"]) 		
			{	pBitmap := a_pBitmap["Protoss","RacePretty"]
				Width := Gdip_GetImageWidth(pBitmap), Height := Gdip_GetImageHeight(pBitmap)	
				Gdip_DrawImage(G, pBitmap, (BaseX - Width/5), (BaseY - Height/5), Width//2.5, Height//2.5, 0, 0, Width, Height)
			}
			Else if (type = aUnitID["CommandCenter"] || type =  aUnitID["PlanetaryFortress"] || type =  aUnitID["OrbitalCommand"])
			{
				pBitmap := a_pBitmap["Terran","RacePretty"]
				Width := Gdip_GetImageWidth(pBitmap), Height := Gdip_GetImageHeight(pBitmap)
				Gdip_DrawImage(G, pBitmap, (BaseX - Width/10), (BaseY - Height/10), Width//5, Height//5, 0, 0, Width, Height)
			}
			Else if (type = aUnitID["Hatchery"] || type =  aUnitID["Lair"] || type =  aUnitID["Hive"])
			{	pBitmap := a_pBitmap["Zerg","RacePretty"]
				Width := Gdip_GetImageWidth(pBitmap), Height := Gdip_GetImageHeight(pBitmap)
				Gdip_DrawImage(G, pBitmap, (BaseX - Width/6), (BaseY - Height/6), Width//3, Height//3, 0, 0, Width, Height)
			}
		}

	}
	if DrawAlerts
	{
		While (A_index <= MiniMapWarning.MaxIndex())
		{	
			If (Time - MiniMapWarning[A_index,"Time"] >= 20) ;display for 20 seconds
			{	MiniMapWarning.Remove(A_index)
				continue
			}
			owner := getUnitOwner(MiniMapWarning[A_index,"Unit"])	
			If (aPlayer[owner, "Team"] <> aLocalPlayer["Team"])
			{
				If (arePlayerColoursEnabled() AND aPlayer[Owner, "Colour"] = "Green")
					pBitmap := a_pBitmap["PurpleX16"] 
				Else pBitmap := a_pBitmap["GreenX16"]
			}
			Else 
				pBitmap := a_pBitmap["RedX16"]
			getUnitMiniMapMousePos(MiniMapWarning[A_index,"Unit"], X, Y)
			Width := Gdip_GetImageWidth(pBitmap), Height := Gdip_GetImageHeight(pBitmap)	
			Gdip_DrawImage(G, pBitmap, (X - Width/2), (Y - Height/2), Width, Height, 0, 0, Width, Height)	
		} 
	}
	Gdip_DeleteGraphics(G)
	UpdateLayeredWindow(hwnd1, hdc, 0, 0, A_ScreenWidth/4, A_ScreenHeight) ;only draw on left side of the screen
	SelectObject(hdc, obm) ; needed else eats ram ; Select the object back into the hdc
	DeleteObject(hbm)   ; needed else eats ram 	; Now the bitmap may be deleted
	DeleteDC(hdc) ; Also the device context related to the bitmap may be deleted
Return
}

getEnemyUnitsMiniMap(byref A_MiniMapUnits)
{  LOCAL Unitcount, UnitAddress, pUnitModel, Filter, MemDump, Radius, x, y, PlayerColours, MemDump, PlayerColours, Unitcount, owner, unitName
 	, Colour, Type
  A_MiniMapUnits := []
  PlayerColours := arePlayerColoursEnabled()
  Unitcount := DumpUnitMemory(MemDump)
  while (A_Index <= Unitcount)
  {
     UnitAddress := (A_Index - 1) * S_uStructure
     Filter := numget(MemDump, UnitAddress + O_uTargetFilter, "Int64")
     if (Filter & DeadFilterFlag)
        Continue

     pUnitModel := numget(MemDump, UnitAddress + O_uModelPointer, "Int")  
     Type := numgetUnitModelType(pUnitModel)

     owner := numget(MemDump, UnitAddress + O_uOwner, "Char")     
     If type in %ActiveUnitHighlightExcludeList% ; cant use or/expressions with type in
           Continue
     if  (aPlayer[Owner, "Team"] <> aLocalPlayer["Team"] && Owner && type >= aUnitID["Colossus"] && !ifTypeInList(type, l_Changeling)) 
     || (ifTypeInList(type, l_Changeling) && aPlayer[Owner, "Team"] = aLocalPlayer["Team"] ) ; as a changeling owner becomes whoever it is mimicking - its team also becomes theirs
     {
          if (!Radius := aUnitInfo[Type, "Radius"])
              Radius := aUnitInfo[Type, "Radius"] := numgetUnitModelMiniMapRadius(pUnitModel)
          if (Radius < minimap.UnitMinimumRadius) ; probes and such
           	Radius := minimap.UnitMinimumRadius
          
	       x :=  numget(MemDump, UnitAddress + O_uX, "int")/4096
           y :=  numget(MemDump, UnitAddress + O_uY, "int")/4096

        ;  Radius += (minimap.AddToRadius/2)
           convertCoOrdindatesToMiniMapPos(x, y)
           if (HighlightInvisible && Filter & aUnitTargetFilter.Hallucination) ; have here so even if non-halluc unit type has custom colour highlight, it will be drawn using halluc colour
           	  Colour := UnitHighlightHallucinationsColour
           else if type in %allActiveActiveUnitHighlightLists%
           {
           		; Overall, checking if the type is actually in the highlight list, 
           		; and then checking each  individual list 
           		; should be faster than needlessly checking every list

	           if type in %ActiveUnitHighlightList1%
	              Colour := UnitHighlightList1Colour
	           Else If type in %ActiveUnitHighlightList2%
	              Colour := UnitHighlightList2Colour                 
	           Else If type in %ActiveUnitHighlightList3%
	              Colour := UnitHighlightList3Colour                    
	           Else If type in %ActiveUnitHighlightList4%
	              Colour := UnitHighlightList4Colour                    
	           Else If type in %ActiveUnitHighlightList5%
	              Colour := UnitHighlightList5Colour   
	           Else If type in %ActiveUnitHighlightList6%
	              Colour := UnitHighlightList6Colour   
	           Else If type in %ActiveUnitHighlightList7%
	              Colour := UnitHighlightList7Colour
	       }
           Else if (HighlightInvisible && Filter & aUnitTargetFilter.Cloaked) ; this will include burrowed units (so dont need to check their flags)
           	  Colour := UnitHighlightInvisibleColour 				; Have this at bot so if an invis unit has a custom highlight it will be drawn with that colour
           Else if PlayerColours
              Colour := 0xcFF HexColour[aPlayer[Owner, "Colour"]]   ;FF=Transparency
           Else Colour := 0xcFF HexColour["Red"]  

           if (GameType != "1v1" && HostileColourAssist)
           {
	           unitName := aUnitName[type]
	           if unitName in CommandCenter,CommandCenterFlying,OrbitalCommand,PlanetaryFortress,Nexus,Hatchery,Lair,Hive
	          		Colour := 0xcFF HexColour[aPlayer[Owner, "Colour"]]
	       }

           A_MiniMapUnits.insert({"X": x, "Y": y, "Colour": Colour, "Radius": Radius*2})  

     }
  }
  Return
}

HiWord(number)
{
	if (number & 0x80000000)
		return (number >> 16)
	return (number >> 16) & 0xffff	
}	

OverlayResize_WM_MOUSEWHEEL(wParam) 		;(wParam, lParam) 0x20A =mousewheel
{ 
	local WheelMove, ActiveTitle, newScale, Scale
	WheelMove := wParam > 0x7FFFFFFF ? HiWord(-(~wParam)-1)/120 :  HiWord(wParam)/120 ;get the higher order word & /120 = number of rotations
	WinGetActiveTitle, ActiveTitle 			;downard rotations are -negative numbers
	if ActiveTitle in IncomeOverlay,ResourcesOverlay,ArmySizeOverlay,WorkerOverlay,IdleWorkersOverlay,UnitOverlay,LocalPlayerColourOverlay ; here cos it can get non overlay titles
	{	
		newScale := %ActiveTitle%Scale + WheelMove*.05
		if (newScale >= .5)
			%ActiveTitle%Scale := newScale
		else newScale := %ActiveTitle%Scale := .5	
		IniWrite, %newScale%, %config_file%, Overlays, %ActiveTitle%Scale
	}
} 

OverlayMove_LButtonDown()
{
    PostMessage, 0xA1, 2
}

DrawIdleWorkersOverlay(ByRef Redraw, UserScale=1,Drag=0, expand=1)
{	global aLocalPlayer, GameIdentifier, config_file, IdleWorkersOverlayX, IdleWorkersOverlayY, a_pBitmap
	static Font := "Arial", Overlay_RunCount, hwnd1, DragPrevious := 0				

	Overlay_RunCount ++	
	DestX := DestY := 0
	idleCount := getIdleWorkers()
	If (Redraw = -1 || !idleCount)		;only draw overlay when idle workers present
	{
		Try Gui, idleWorkersOverlay: Destroy
		Overlay_RunCount := 0
		Redraw := 0
		Return
	}	
	Else if (ReDraw AND WinActive(GameIdentifier) && idleCount)
	{
		Try Gui, idleWorkersOverlay: Destroy
		Overlay_RunCount := 1
		Redraw := 0
	}	
	If (Overlay_RunCount = 1)
	{
		Gui, idleWorkersOverlay: -Caption Hwndhwnd1 +E0x20 +E0x80000 +LastFound  +ToolWindow +AlwaysOnTop
		Gui, idleWorkersOverlay: Show, NA X%idleWorkersOverlayX% Y%idleWorkersOverlayY% W400 H400, idleWorkersOverlay
		OnMessage(0x201, "OverlayMove_LButtonDown")
		OnMessage(0x20A, "OverlayResize_WM_MOUSEWHEEL")
	}
	If (Drag AND !DragPrevious)
	{	DragPrevious := 1
		Gui, idleWorkersOverlay: -E0x20
	}
	Else if (!Drag AND DragPrevious)
	{	DragPrevious := 0
		Gui, idleWorkersOverlay: +E0x20 +LastFound
		WinGetPos,idleWorkersOverlayX,idleWorkersOverlayY		
		IniWrite, %idleWorkersOverlayX%, %config_file%, Overlays, idleWorkersOverlayX
		Iniwrite, %idleWorkersOverlayY%, %config_file%, Overlays, idleWorkersOverlayY
	}
	hbm := CreateDIBSection(A_ScreenWidth, A_ScreenHeight)
	hdc := CreateCompatibleDC()
	obm := SelectObject(hdc, hbm)
	G := Gdip_GraphicsFromHDC(hdc)
	DllCall("gdiplus\GdipGraphicsClear", "UInt", G, "UInt", 0)	

	pBitmap := a_pBitmap[aLocalPlayer["Race"],"Worker"]
	SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)

	expandOnIdle := 4
	if expand
	{
		increased := floor(idlecount / expandOnIdle)/8
		if (increased > .5)		; insreases size every 4 idle workers until 16 workers ie 4x
			increased := .5
		UserScale += increased
	}
	Options := " cFFFFFFFF r4 s" 18*UserScale
	Width *= UserScale *.5, Height *= UserScale *.5
	Gdip_DrawImage(G, pBitmap, DestX, DestY, Width, Height, 0, 0, SourceWidth, SourceHeight)	
	Gdip_TextToGraphics(G, idleCount, "x"(DestX+Width+2*UserScale) "y"(DestY+(Height//4)) Options, Font, TextWidthHeight, TextWidthHeight)
	Gdip_DeleteGraphics(G)	
	UpdateLayeredWindow(hwnd1, hdc)
	SelectObject(hdc, obm) 
	DeleteObject(hbm)  
	DeleteDC(hdc) 
	Return
}
DrawIncomeOverlay(ByRef Redraw, UserScale=1, PlayerIdentifier=0, Background=0,Drag=0)
{	global aLocalPlayer, HexColour, aPlayer, GameIdentifier, IncomeOverlayX, IncomeOverlayY, config_file, MatrixColour, a_pBitmap
	static Font := "Arial", Overlay_RunCount, hwnd1, DragPrevious := 0
	Overlay_RunCount ++
	DestX := i := 0
	Options := " cFFFFFFFF r4 s" 17*UserScale					;these cant be static	
	If (Redraw = -1)
	{
		Try Gui, IncomeOverlay: Destroy
		Overlay_RunCount := 0
		Redraw := 0
		Return
	}		
	Else if (ReDraw AND WinActive(GameIdentifier))
	{
		Try Gui, IncomeOverlay: Destroy
		Overlay_RunCount := 1
		Redraw := 0
	}	
	If (Overlay_RunCount = 1)
	{
		Gui, IncomeOverlay: -Caption Hwndhwnd1 +E0x20 +E0x80000 +LastFound  +ToolWindow +AlwaysOnTop
		Gui, IncomeOverlay: Show, NA X%IncomeOverlayX% Y%IncomeOverlayY% W400 H400, IncomeOverlay
	;	hwnd1 := WinExist()
		OnMessage(0x201, "OverlayMove_LButtonDown")
		OnMessage(0x20A, "OverlayResize_WM_MOUSEWHEEL")
	}
	If (Drag AND !DragPrevious)
	{	DragPrevious := 1
		Gui, IncomeOverlay: -E0x20
	}
	Else if (!Drag AND DragPrevious)
	{	DragPrevious := 0
		Gui, IncomeOverlay: +E0x20 +LastFound
		WinGetPos,IncomeOverlayX,IncomeOverlayY,w,h		
		IniWrite, %IncomeOverlayX%, %config_file%, Overlays, IncomeOverlayX
		Iniwrite, %IncomeOverlayY%, %config_file%, Overlays, IncomeOverlayY		
	}		
	hbm := CreateDIBSection(A_ScreenWidth, A_ScreenHeight)
	hdc := CreateCompatibleDC()
	obm := SelectObject(hdc, hbm)
	G := Gdip_GraphicsFromHDC(hdc)
	DllCall("gdiplus\GdipGraphicsClear", "UInt", G, "UInt", 0)	
	For slot_number in aPlayer
	{
		If ( aLocalPlayer["Team"] <> aPlayer[slot_number, "Team"] )
		{				
			DestY := i ? i*Height : 0

			If (PlayerIdentifier = 1 Or PlayerIdentifier = 2 )
			{	
				IF (PlayerIdentifier = 2)
					OptionsName := " Bold cFF" HexColour[aPlayer[slot_number, "Colour"]] " r4 s" 17*UserScale
				Else IF (PlayerIdentifier = 1)
					OptionsName := " Bold cFFFFFFFF r4 s" 17*UserScale	
				pBitmap := a_pBitmap[aPlayer[slot_number, "Race"],"Mineral",Background]
				SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
				Width *= UserScale *.5, Height *= UserScale *.5		
				gdip_TextToGraphics(G, getPlayerName(slot_number), "x0" "y"(DestY+(Height//4))  OptionsName, Font)
				if !LongestNameSize
				{
					LongestNameData :=	gdip_TextToGraphics(G, getLongestEnemyPlayerName(aPlayer), "x0" "y"(DestY+(Height//4))  " Bold c00FFFFFF r4 s" 17*UserScale	, Font) ; text is invisible ;get string size	
					StringSplit, LongestNameSize, LongestNameData, | ;retrieve the length of the string
					LongestNameSize := LongestNameSize3
				}
				DestX := LongestNameSize+10*UserScale
			}
			Else If (PlayerIdentifier = 3)
			{		
				pBitmap := a_pBitmap[aPlayer[slot_number, "Race"],"RaceFlat"]
				SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
				Width *= UserScale *.5, Height *= UserScale *.5	
				Gdip_DrawImage(G, pBitmap, 12*UserScale, DestY, Width, Height, 0, 0, SourceWidth, SourceHeight, MatrixColour[aPlayer[slot_number, "Colour"]])
				;Gdip_DisposeImage(pBitmap)
				pBitmap := a_pBitmap[aPlayer[slot_number, "Race"],"Mineral",Background]
				SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
				Width *= UserScale *.5, Height *= UserScale *.5		
				DestX := Width+10*UserScale
			}
			Else 
			{
				pBitmap := a_pBitmap[aPlayer[slot_number, "Race"],"Mineral",Background]
				SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
				Width *= UserScale *.5, Height *= UserScale *.5	
			}

			Gdip_DrawImage(G, pBitmap, DestX, DestY, Width, Height, 0, 0, SourceWidth, SourceHeight)	
			Gdip_TextToGraphics(G, getPlayerMineralIncome(slot_number), "x"(DestX+Width+5*UserScale) "y"(DestY+(Height//4)) Options, Font)				

			pBitmap := a_pBitmap[aPlayer[slot_number, "Race"],"Gas",Background]
			SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
			Width *= UserScale *.5, Height *= UserScale *.5
			Gdip_DrawImage(G, pBitmap, DestX + (85*UserScale), DestY, Width, Height, 0, 0, SourceWidth, SourceHeight)	
			Gdip_TextToGraphics(G, getPlayerGasIncome(slot_number), "x"(DestX+(85*UserScale)+Width+5*UserScale) "y"(DestY+(Height//4)) Options, Font)				

			pBitmap := a_pBitmap[aPlayer[slot_number, "Race"],"Worker"]
			SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
			Width *= UserScale *.5, Height *= UserScale *.5
			Gdip_DrawImage(G, pBitmap, DestX + (2*85*UserScale), DestY, Width, Height, 0, 0, SourceWidth, SourceHeight)
			TextData := Gdip_TextToGraphics(G, getPlayerWorkerCount(slot_number), "x"(DestX+(2*85*UserScale)+Width+5*UserScale) "y"(DestY+(Height//4)) Options, Font)				
			StringSplit, TextSize, TextData, | ;retrieve the length of the string
			if (WindowWidth < CurrentWidth := DestX+(2*85*UserScale)+Width+5*UserScale + TextSize3)
				WindowWidth := CurrentWidth
			i++ 
		}
	}
	WindowHeight := DestY+Height
	Gdip_DeleteGraphics(G)
	UpdateLayeredWindow(hwnd1, hdc,,,WindowWidth,WindowHeight)
	SelectObject(hdc, obm) ; needed else eats ram ; Select the object back into the hdc
	DeleteObject(hbm)   ; needed else eats ram 	; Now the bitmap may be deleted
	DeleteDC(hdc) ; Also the device context related to the bitmap may be deleted
	Return
}	

DrawResourcesOverlay(ByRef Redraw, UserScale=1, PlayerIdentifier=0, Background=0,Drag=0)
{	global aLocalPlayer, HexColour, aPlayer, GameIdentifier, config_file, ResourcesOverlayX, ResourcesOverlayY, MatrixColour, a_pBitmap
	static Font := "Arial", Overlay_RunCount, hwnd1, DragPrevious := 0		
	Overlay_RunCount ++	
	DestX := i := 0
	Options := " cFFFFFFFF r4 s" 17*UserScale					;these cant be static	
	If (Redraw = -1)
	{
		Try Gui, ResourcesOverlay: Destroy
		Overlay_RunCount := 0
		Redraw := 0
		Return
	}	
	Else if (ReDraw AND WinActive(GameIdentifier))
	{
		Try Gui, ResourcesOverlay: Destroy
		Overlay_RunCount := 1
		Redraw := 0
	}
	If (Overlay_RunCount = 1)
	{
		Gui, ResourcesOverlay: -Caption Hwndhwnd1 +E0x20 +E0x80000 +LastFound  +ToolWindow +AlwaysOnTop
		Gui, ResourcesOverlay: Show, NA X%ResourcesOverlayX% Y%ResourcesOverlayY% W400 H400, ResourcesOverlay

	;	hwnd1 := WinExist()
		OnMessage(0x201, "OverlayMove_LButtonDown")
		OnMessage(0x20A, "OverlayResize_WM_MOUSEWHEEL")
	}	
	If (Drag AND !DragPrevious)
	{	DragPrevious := 1
		Gui, ResourcesOverlay: -E0x20
	}
	Else if (!Drag AND DragPrevious)
	{	DragPrevious := 0
		Gui, ResourcesOverlay: +E0x20 +LastFound
		WinGetPos,ResourcesOverlayX,ResourcesOverlayY		
		IniWrite, %ResourcesOverlayX%, %config_file%, Overlays, ResourcesOverlayX
		Iniwrite, %ResourcesOverlayY%, %config_file%, Overlays, ResourcesOverlayY		
	}

	hbm := CreateDIBSection(A_ScreenWidth, A_ScreenHeight)
	hdc := CreateCompatibleDC()
	obm := SelectObject(hdc, hbm)
	G := Gdip_GraphicsFromHDC(hdc)
	DllCall("gdiplus\GdipGraphicsClear", "UInt", G, "UInt", 0)		

	For slot_number in aPlayer
	{
		If ( aLocalPlayer["Team"] <> aPlayer[slot_number, "Team"] )
		{	DestY := i ? i*Height : 0

			If (PlayerIdentifier = 1 Or PlayerIdentifier = 2 )
			{	
				IF (PlayerIdentifier = 2)
					OptionsName := " Bold cFF" HexColour[aPlayer[slot_number, "Colour"]] " r4 s" 17*UserScale
				Else IF (PlayerIdentifier = 1)
					OptionsName := " Bold cFFFFFFFF r4 s" 17*UserScale		
				pBitmap := a_pBitmap[aPlayer[slot_number, "Race"],"Mineral",Background]
				SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)		
				Width *= UserScale *.5, Height *= UserScale *.5
				gdip_TextToGraphics(G, getPlayerName(slot_number), "x0" "y"(DestY+(Height//4))  OptionsName, Font) ;get string size	
				if !LongestNameSize
				{
					LongestNameData :=	gdip_TextToGraphics(G, getLongestEnemyPlayerName(aPlayer), "x0" "y"(DestY+(Height//4))  " Bold c00FFFFFF r4 s" 17*UserScale	, Font) ; text is invisible ;get string size	
					StringSplit, LongestNameSize, LongestNameData, | ;retrieve the length of the string
					LongestNameSize := LongestNameSize3
				}
				DestX := LongestNameSize+10*UserScale
			}
			Else If (PlayerIdentifier = 3)
			{	pBitmap := a_pBitmap[aPlayer[slot_number, "Race"],"RaceFlat"]
				SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
				Width *= UserScale *.5, Height *= UserScale *.5	
				Gdip_DrawImage(G, pBitmap, 12*UserScale, DestY, Width, Height, 0, 0, SourceWidth, SourceHeight, MatrixColour[aPlayer[slot_number, "Colour"]])
				;Gdip_DisposeImage(pBitmap)
				pBitmap := a_pBitmap[aPlayer[slot_number, "Race"],"Mineral",Background]
				SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
				Width *= UserScale *.5, Height *= UserScale *.5		
				DestX := Width+10*UserScale
			}
			Else
			{
				pBitmap := a_pBitmap[aPlayer[slot_number, "Race"],"Mineral",Background]
				SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
				Width *= UserScale *.5, Height *= UserScale *.5	
			}

			Gdip_DrawImage(G, pBitmap, DestX, DestY, Width, Height, 0, 0, SourceWidth, SourceHeight)	
			;Gdip_DisposeImage(pBitmap)
			Gdip_TextToGraphics(G, getPlayerMinerals(slot_number), "x"(DestX+Width+5*UserScale) "y"(DestY+(Height//4)) Options, Font, TextWidthHeight, TextWidthHeight)				
			pBitmap := a_pBitmap[aPlayer[slot_number, "Race"],"Gas",Background]
			SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
			Width *= UserScale *.5, Height *= UserScale *.5
			Gdip_DrawImage(G, pBitmap, DestX + (85*UserScale), DestY, Width, Height, 0, 0, SourceWidth, SourceHeight)	
			;Gdip_DisposeImage(pBitmap)
			Gdip_TextToGraphics(G, getPlayerGas(slot_number), "x"(DestX+(85*UserScale)+Width+5*UserScale) "y"(DestY+(Height//4)) Options, Font, TextWidthHeight,TextWidthHeight)				

			pBitmap := a_pBitmap[aPlayer[slot_number, "Race"],"Supply",Background]
			SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
			Width *= UserScale *.5, Height *= UserScale *.5
			Gdip_DrawImage(G, pBitmap, DestX + (2*85*UserScale), DestY, Width, Height, 0, 0, SourceWidth, SourceHeight)
			;Gdip_DisposeImage(pBitmap)
			TextData := Gdip_TextToGraphics(G, getPlayerSupply(slot_number)"/"getPlayerSupplyCap(slot_number), "x"(DestX+(2*85*UserScale)+Width+3*UserScale) "y"(DestY+(Height//4)) Options, Font, TextWidthHeight, TextWidthHeight)				
			StringSplit, TextSize, TextData, |			
			if (WindowWidth < CurrentWidth := DestX+(2*85*UserScale)+Width+5*UserScale + TextSize3)
				WindowWidth := CurrentWidth	
			Height += 5*userscale	;needed to stop the edge of race pic overlap'n due to Supply pic -prot then zerg
			i++ 
		}
	}
	WindowHeight := DestY+Height
	Gdip_DeleteGraphics(G)
	UpdateLayeredWindow(hwnd1, hdc,,,WindowWidth,WindowHeight)
	SelectObject(hdc, obm)
	DeleteObject(hbm)
	DeleteDC(hdc)
	Return
}

DrawArmySizeOverlay(ByRef Redraw, UserScale=1, PlayerIdentifier=0, Background=0,Drag=0)
{	global aLocalPlayer, HexColour, aPlayer, GameIdentifier, config_file, ArmySizeOverlayX, ArmySizeOverlayY, MatrixColour, a_pBitmap
	static Font := "Arial", Overlay_RunCount, hwnd1, DragPrevious := 0	
	Overlay_RunCount ++	
	DestX := i := 0
	Options := " cFFFFFFFF r4 Bold s" 17*UserScale					;these cant be static
	If (Redraw = -1)
	{
		Try Gui, ArmySizeOverlay: Destroy
		Overlay_RunCount := 0
		Redraw := 0
		Return
	}	
	Else if (ReDraw AND WinActive(GameIdentifier))
	{
		Try Gui, ArmySizeOverlay: Destroy
		Overlay_RunCount := 1
		Redraw := 0
	}	
	If (Overlay_RunCount = 1)
	{	; Create a layered window ;E0x20 click thru (+E0x80000 : must be used for UpdateLayeredWindow to work!) that is always on top (+AlwaysOnTop), has no taskbar entry or caption		
		Gui, ArmySizeOverlay: -Caption Hwndhwnd1 +E0x20 +E0x80000 +LastFound  +ToolWindow +AlwaysOnTop
		Gui, ArmySizeOverlay: Show, NA X%ArmySizeOverlayX% Y%ArmySizeOverlayY% W400 H400, ArmySizeOverlay
		OnMessage(0x201, "OverlayMove_LButtonDown")
		OnMessage(0x20A, "OverlayResize_WM_MOUSEWHEEL")
	}
	If (Drag AND !DragPrevious)
	{	DragPrevious := 1
		Gui, ArmySizeOverlay: -E0x20
	}
	Else if (!Drag AND DragPrevious)
	{	DragPrevious := 0
		Gui, ArmySizeOverlay: +E0x20 +LastFound
		WinGetPos,ArmySizeOverlayX,ArmySizeOverlayY		
		IniWrite, %ArmySizeOverlayX%, %config_file%, Overlays, ArmySizeOverlayX
		Iniwrite, %ArmySizeOverlayY%, %config_file%, Overlays, ArmySizeOverlayY	
	}
	hbm := CreateDIBSection(A_ScreenWidth, A_ScreenHeight)
	hdc := CreateCompatibleDC()
	obm := SelectObject(hdc, hbm)
	G := Gdip_GraphicsFromHDC(hdc)
	DllCall("gdiplus\GdipGraphicsClear", "UInt", G, "UInt", 0)
	For slot_number in aPlayer
	{	
		If ( aLocalPlayer["Team"]  <> aPlayer[slot_number, "Team"] )
		{	
		;	DestY := i ? i*Height + 5*UserScale : 0
			DestY := i ? i*Height : 0

			If (PlayerIdentifier = 1 Or PlayerIdentifier = 2 )
			{	
				IF (PlayerIdentifier = 2)
					OptionsName := " Bold cFF" HexColour[aPlayer[slot_number, "Colour"]] " r4 s" 17*UserScale
				Else IF (PlayerIdentifier = 1)
					OptionsName := " Bold cFFFFFFFF r4 s" 17*UserScale	
				pBitmap := a_pBitmap[aPlayer[slot_number, "Race"],"Mineral",Background]
				SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
				Width *= UserScale *.5, Height *= UserScale *.5		
				gdip_TextToGraphics(G, getPlayerName(slot_number), "x0" "y"(DestY+(Height//4))  OptionsName, Font)		
				if !LongestNameSize
				{
					LongestNameData :=	gdip_TextToGraphics(G, getLongestEnemyPlayerName(aPlayer), "x0" "y"(DestY+(Height//4))  " Bold c00FFFFFF r4 s" 17*UserScale	, Font) ; text is invisible ;get string size	
					StringSplit, LongestNameSize, LongestNameData, | ;retrieve the length of the string
					LongestNameSize := LongestNameSize3
				}
				DestX := LongestNameSize+10*UserScale
			}
			Else If (PlayerIdentifier = 3)
			{		
				pBitmap := a_pBitmap[aPlayer[slot_number, "Race"],"RaceFlat"] 
				SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
				Width *= UserScale *.5, Height *= UserScale *.5	
				Gdip_DrawImage(G, pBitmap, 12*UserScale, DestY, Width, Height, 0, 0, SourceWidth, SourceHeight, MatrixColour[aPlayer[slot_number, "Colour"]])
				;Gdip_DisposeImage(pBitmap)
				pBitmap := a_pBitmap[aPlayer[slot_number, "Race"],"Mineral",Background]
				SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
				Width *= UserScale *.5, Height *= UserScale *.5		
				DestX := Width+10*UserScale
			}
			Else
			{
				pBitmap := a_pBitmap[aPlayer[slot_number, "Race"],"Mineral",Background]
				SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
				Width *= UserScale *.5, Height *= UserScale *.5	
			}
			Gdip_DrawImage(G, pBitmap, DestX, DestY, Width, Height, 0, 0, SourceWidth, SourceHeight)	
			;Gdip_DisposeImage(pBitmap)
			Gdip_TextToGraphics(G, ArmyMinerals := getPlayerArmySizeMinerals(slot_number), "x"(DestX+Width+5*UserScale) "y"(DestY+(Height//4)) Options, Font)				
			pBitmap := a_pBitmap[aPlayer[slot_number, "Race"],"Gas",Background]
			SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
			Width *= UserScale *.5, Height *= UserScale *.5
			Gdip_DrawImage(G, pBitmap, DestX + (85*UserScale), DestY, Width, Height, 0, 0, SourceWidth, SourceHeight)	
			;Gdip_DisposeImage(pBitmap)
			Gdip_TextToGraphics(G, getPlayerArmySizeGas(slot_number), "x"(DestX+(85*UserScale)+Width+5*UserScale) "y"(DestY+(Height//4)) Options, Font)				



			pBitmap := a_pBitmap[aPlayer[slot_number, "Race"],"Army"]
			SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
			Width *= UserScale *.5, Height *= UserScale *.5
			Gdip_DrawImage(G, pBitmap, DestX + (2*85*UserScale), DestY, Width, Height, 0, 0, SourceWidth, SourceHeight)
			;Gdip_DisposeImage(pBitmap)
			TextData := Gdip_TextToGraphics(G, round(getPlayerArmySupply(slot_number)) "/" getPlayerSupply(slot_number), "x"(DestX+(2*85*UserScale)+Width+3*UserScale) "y"(DestY+(Height//4)) Options, Font)				
			StringSplit, TextSize, TextData, |
			if (WindowWidth < CurrentWidth := DestX+(2*85*UserScale)+Width+5*UserScale + TextSize3)
				WindowWidth := CurrentWidth				
			i++ 
		}
	}
	WindowHeight := DestY+Height	
	Gdip_DeleteGraphics(G)
	UpdateLayeredWindow(hwnd1, hdc,,, WindowWidth, WindowHeight)
	SelectObject(hdc, obm) 
	DeleteObject(hbm)  
	DeleteDC(hdc) 
	Return
}
DrawWorkerOverlay(ByRef Redraw, UserScale=1,Drag=0)
{	global aLocalPlayer, GameIdentifier, config_file, WorkerOverlayX, WorkerOverlayY, a_pBitmap
	static Font := "Arial", Overlay_RunCount, hwnd1, DragPrevious := 0				
	Options := " cFFFFFFFF r4 s" 18*UserScale
	Overlay_RunCount ++	
	DestX := DestY := 0
	If (Redraw = -1)
	{
		Try Gui, WorkerOverlay: Destroy
		Overlay_RunCount := 0
		Redraw := 0
		Return
	}	
	Else if (ReDraw AND WinActive(GameIdentifier))
	{
		Try Gui, WorkerOverlay: Destroy
		Overlay_RunCount := 1
		Redraw := 0
	}	
	If (Overlay_RunCount = 1)
	{
		Gui, WorkerOverlay: -Caption Hwndhwnd1 +E0x20 +E0x80000 +LastFound  +ToolWindow +AlwaysOnTop
		Gui, WorkerOverlay: Show, NA X%WorkerOverlayX% Y%WorkerOverlayY% W400 H400, WorkerOverlay
		OnMessage(0x201, "OverlayMove_LButtonDown")
		OnMessage(0x20A, "OverlayResize_WM_MOUSEWHEEL")
	}
	If (Drag AND !DragPrevious)
	{	DragPrevious := 1
		Gui, WorkerOverlay: -E0x20
	}
	Else if (!Drag AND DragPrevious)
	{	DragPrevious := 0
		Gui, WorkerOverlay: +E0x20 +LastFound
		WinGetPos,WorkerOverlayX,WorkerOverlayY		
		IniWrite, %WorkerOverlayX%, %config_file%, Overlays, WorkerOverlayX
		Iniwrite, %WorkerOverlayY%, %config_file%, Overlays, WorkerOverlayY
	}
	hbm := CreateDIBSection(A_ScreenWidth, A_ScreenHeight)
	hdc := CreateCompatibleDC()
	obm := SelectObject(hdc, hbm)
	G := Gdip_GraphicsFromHDC(hdc)
	DllCall("gdiplus\GdipGraphicsClear", "UInt", G, "UInt", 0)	

	pBitmap := a_pBitmap[aLocalPlayer["Race"],"Worker"]
	SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
	Width *= UserScale *.5, Height *= UserScale *.5
	Gdip_DrawImage(G, pBitmap, DestX, DestY, Width, Height, 0, 0, SourceWidth, SourceHeight)	
	;Gdip_DisposeImage(pBitmap)
	Gdip_TextToGraphics(G, getPlayerWorkerCount(aLocalPlayer["Slot"]), "x"(DestX+Width+2*UserScale) "y"(DestY+(Height//4)) Options, Font, TextWidthHeight, TextWidthHeight)
	Gdip_DeleteGraphics(G)	
	UpdateLayeredWindow(hwnd1, hdc)
	SelectObject(hdc, obm) 
	DeleteObject(hbm)  
	DeleteDC(hdc) 
	Return
}


DrawLocalPlayerColour(ByRef Redraw, UserScale=1,Drag=0)
{	global aLocalPlayer, GameIdentifier, config_file, LocalPlayerColourOverlayX, LocalPlayerColourOverlayY, a_pBitmap, HexColour, a_pBrush
	static Overlay_RunCount, hwnd1, DragPrevious := 0,  PreviousPlayerColours := 0 			

	playerColours := arePlayerColoursEnabled()

	if (!playerColours && PreviousPlayerColours) ; this just toggles the colour circle when the player changes the Player COlour state. A bit messy with the stuff below but im lazy
	{
		Redraw := 1
		PreviousPlayerColours := 0
	}
	else if (playerColours && !PreviousPlayerColours)
	{
		Try Gui, LocalPlayerColourOverlay: Destroy
		PreviousPlayerColours := 1
		return
	}
	else if playerColours
		return

	Overlay_RunCount ++	
	If (Redraw = -1)
	{
		Try Gui, LocalPlayerColourOverlay: Destroy
		Overlay_RunCount := 0
		Redraw := 0
		Return
	}	
	Else if (ReDraw AND WinActive(GameIdentifier))
	{
		Try Gui, LocalPlayerColourOverlay: Destroy
		Overlay_RunCount := 1
		Redraw := 0
	}	
	If (Overlay_RunCount = 1)
	{
		Gui, LocalPlayerColourOverlay: -Caption Hwndhwnd1 +E0x20 +E0x80000 +LastFound  +ToolWindow +AlwaysOnTop
		Gui, LocalPlayerColourOverlay: Show, NA X%LocalPlayerColourOverlayX% Y%LocalPlayerColourOverlayY% W400 H400, LocalPlayerColourOverlay
		OnMessage(0x201, "OverlayMove_LButtonDown")
		OnMessage(0x20A, "OverlayResize_WM_MOUSEWHEEL")
	}
	If (Drag AND !DragPrevious)
	{	DragPrevious := 1
		Gui, LocalPlayerColourOverlay: -E0x20
	}
	Else if (!Drag AND DragPrevious)
	{	DragPrevious := 0
		Gui, LocalPlayerColourOverlay: +E0x20 +LastFound
		WinGetPos,LocalPlayerColourOverlayX,LocalPlayerColourOverlayY		
		IniWrite, %LocalPlayerColourOverlayX%, %config_file%, Overlays, LocalPlayerColourOverlayX
		Iniwrite, %LocalPlayerColourOverlayY%, %config_file%, Overlays, LocalPlayerColourOverlayY
	}


	hbm := CreateDIBSection(A_ScreenWidth, A_ScreenHeight) ;/10 not really necessary but should be plenty large enough
	hdc := CreateCompatibleDC()
	obm := SelectObject(hdc, hbm)
	G := Gdip_GraphicsFromHDC(hdc)
	DllCall("gdiplus\GdipGraphicsClear", "UInt", G, "UInt", 0)	
	Gdip_SetSmoothingMode(G, 4) ; for some reason its smoother than calling my setDrawingQuality(G) fucntion.......
	colour := aLocalPlayer["Colour"]
	if !a_pBrush[colour]
		a_pBrush[colour] := Gdip_BrushCreateSolid(0xcFF HexColour[colour])	
	Radius := 12 * UserScale
	Gdip_FillEllipse(G, a_pBrush[colour], 0, 0, Radius, Radius)

	Gdip_DeleteGraphics(G)	
	UpdateLayeredWindow(hwnd1, hdc)
	SelectObject(hdc, obm) 
	DeleteObject(hbm)  
	DeleteDC(hdc) 
	Return
}






;	Some commands which can come in handy for some functions (obviously have to use within the hotkey command)
; 	#MaxThreadsBuffer on 		- this will buffer a hotkeys own key for 1 second, hence this is more in series - subsequent threads will begin when the previous one finishes
;	#MaxThreadsPerHotkey 3 		- this will allow a simultaneous 'thread' of hotkeys i.e. parallel
;	#MaxThreadsPerHotkey 1 		- 
;	#MaxThreadsBuffer off

; these hotkeys will be blocked and wont be activated if the user presses them while blocked - the keys that make themup will then be sent if it was buffered
; send level doesnt seem to fix this

CreateHotkeys()
{	global
	Hotkeys:	 

	; The other sendmode is 'PostMessage'. When this is in effect, SendInput will be used
	; for some keystrokes e.g. to release modifiers

;	Is now always SendInput
;	If (input_method = "Event")
;		SendMode Event
;	Else If (input_method = "play")
;		SendMode Play	; causes problems 
;	Else SendMode Input

 	input.pClickDelay(pKeyDelay)
 	input.pSendDelay(pKeyDelay)
 	EventKeyDelay := -1

	#If, WinActive(GameIdentifier) && !BufferInputFast.isInputBlockedOrBuffered()
	#If, WinActive(GameIdentifier) && LwinDisable && getTime()	
	#If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Zerg") && !isMenuOpen() && time && !BufferInputFast.isInputBlockedOrBuffered()
	#If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Zerg") && (auto_inject <> "Disabled") && time && !BufferInputFast.isInputBlockedOrBuffered()
	#If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Protoss") && CG_Enable && time && !BufferInputFast.isInputBlockedOrBuffered()
	#If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Protoss") && ChronoBoostEnableForge && time && !BufferInputFast.isInputBlockedOrBuffered()
	#If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Protoss") && ChronoBoostEnableStargate && time && !BufferInputFast.isInputBlockedOrBuffered()
	#If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Protoss") && ChronoBoostEnableNexus && time && !BufferInputFast.isInputBlockedOrBuffered()
	#If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Protoss") && ChronoBoostEnableRoboticsFacility && time && !BufferInputFast.isInputBlockedOrBuffered()
	#If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Terran" || aLocalPlayer["Race"] = "Protoss")  && time && !BufferInputFast.isInputBlockedOrBuffered()
	#If, WinActive(GameIdentifier) && time && !isMenuOpen() && EnableAutoWorker%LocalPlayerRace% && !BufferInputFast.isInputBlockedOrBuffered()
	#If, WinActive(GameIdentifier) && time && !isMenuOpen() && SelectArmyEnable && !BufferInputFast.isInputBlockedOrBuffered()
	#If, WinActive(GameIdentifier) && time && !isMenuOpen() && SplitUnitsEnable && !BufferInputFast.isInputBlockedOrBuffered()
	#If, WinActive(GameIdentifier) && time && !isMenuOpen() && RemoveUnitEnable && !BufferInputFast.isInputBlockedOrBuffered()
	#If, WinActive(GameIdentifier) && !isMenuOpen() && time && !BufferInputFast.isInputBlockedOrBuffered()
	#If, WinActive(GameIdentifier) && time && !BufferInputFast.isInputBlockedOrBuffered()
	#If
	Hotkey, If, WinActive(GameIdentifier) && !BufferInputFast.isInputBlockedOrBuffered() 														
		hotkey, %warning_toggle_key%, mt_pause_resume, on		
		hotkey, *~LButton, g_LbuttonDown, on

	Hotkey, If, WinActive(GameIdentifier) && LwinDisable && getTime()
			hotkey, *Lwin, g_DoNothing, on		

	Hotkey, If, WinActive(GameIdentifier) && !isMenuOpen() && time && !BufferInputFast.isInputBlockedOrBuffered()
		hotkey, %ping_key%, ping, on									;on used to re-enable hotkeys as were 
	Hotkey, If, WinActive(GameIdentifier) && time && !BufferInputFast.isInputBlockedOrBuffered()		;turned off during save to allow for swaping of keys
		hotkey, %worker_count_local_key%, worker_count, on
		hotkey, %worker_count_enemy_key%, worker_count, on
		hotkey, %Playback_Alert_Key%, g_PrevWarning, on					
		hotkey, %TempHideMiniMapKey%, g_HideMiniMap, on
		hotkey, %AdjustOverlayKey%, Adjust_overlay, on
		hotkey, %ToggleIdentifierKey%, Toggle_Identifier, on
		hotkey, %ToggleMinimapOverlayKey%, Overlay_Toggle, on
		hotkey, %ToggleIncomeOverlayKey%, Overlay_Toggle, on
		hotkey, %ToggleResourcesOverlayKey%, Overlay_Toggle, on
		hotkey, %ToggleArmySizeOverlayKey%, Overlay_Toggle, on
		hotkey, %ToggleWorkerOverlayKey%, Overlay_Toggle, on
		hotkey, %ToggleUnitOverlayKey%, Overlay_Toggle, on
		hotkey, %CycleOverlayKey%, Overlay_Toggle, on


	if race_reading 
		hotkey, %read_races_key%, find_races, on
	if manual_inject_timer
	{	
		hotkey, %inject_start_key%, inject_start, on
		hotkey, %inject_reset_key%, inject_reset, on
	}	
	Hotkey, If, WinActive(GameIdentifier) && time && !isMenuOpen() && SelectArmyEnable && !BufferInputFast.isInputBlockedOrBuffered()
		hotkey, %castSelectArmy_key%, g_SelectArmy, on  ; buffer to make double tap better remove 50ms delay
	Hotkey, If, WinActive(GameIdentifier) && time && !isMenuOpen() && SplitUnitsEnable && !BufferInputFast.isInputBlockedOrBuffered()
		hotkey, %castSplitUnit_key%, g_SplitUnits, on	
	Hotkey, If, WinActive(GameIdentifier) && time && !isMenuOpen() && RemoveUnitEnable && !BufferInputFast.isInputBlockedOrBuffered()
		hotkey, %castRemoveUnit_key%, g_DeselectUnit, on	
	Hotkey, If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Zerg") && (auto_inject <> "Disabled") && time && !BufferInputFast.isInputBlockedOrBuffered()
		hotkey, %cast_inject_key%, cast_inject, on	
		hotkey, %F_InjectOff_Key%, Cast_DisableInject, on			
	Hotkey, If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Protoss") && CG_Enable && time && !BufferInputFast.isInputBlockedOrBuffered()
		hotkey, %Cast_ChronoGate_Key%, Cast_ChronoStructure, on	
	Hotkey, If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Protoss") && ChronoBoostEnableForge && time && !BufferInputFast.isInputBlockedOrBuffered()
		hotkey, %Cast_ChronoForge_Key%, Cast_ChronoStructure, on	
	Hotkey, If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Protoss") && ChronoBoostEnableStargate && time && !BufferInputFast.isInputBlockedOrBuffered()
		hotkey, %Cast_ChronoStargate_Key%, Cast_ChronoStructure, on
	Hotkey, If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Protoss") && ChronoBoostEnableNexus && time && !BufferInputFast.isInputBlockedOrBuffered()
		hotkey, %Cast_ChronoNexus_Key%, Cast_ChronoStructure, on	
	Hotkey, If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Protoss") && ChronoBoostEnableRoboticsFacility && time && !BufferInputFast.isInputBlockedOrBuffered()
		hotkey, %Cast_ChronoRoboticsFacility_Key%, Cast_ChronoStructure, on	
	Hotkey, If, WinActive(GameIdentifier) && (aLocalPlayer["Race"] = "Terran" || aLocalPlayer["Race"] = "Protoss")  && time && !BufferInputFast.isInputBlockedOrBuffered()	
		hotkey, %ToggleAutoWorkerState_Key%, g_UserToggleAutoWorkerState, on	
	Hotkey, If, WinActive(GameIdentifier) && time && !isMenuOpen() && EnableAutoWorker%LocalPlayerRace% && !BufferInputFast.isInputBlockedOrBuffered() ; cant use !ischatopen() - as esc will close chat before memory reads value so wont see chat was open
		hotkey, *~Esc, g_temporarilyDisableAutoWorkerProduction, on	
	Hotkey, If, WinActive(GameIdentifier) && !isMenuOpen() && time && !BufferInputFast.isInputBlockedOrBuffered()
	while (10 > i := A_index - 1)
	{
		if A_UnitGroupSettings["LimitGroup", aLocalPlayer["Race"], i,"Enabled"] 
			status := "on"
		else status := "off"
		hotkey, ^%i%, g_LimitGrouping, % status
		hotkey, +%i%, g_LimitGrouping, % status
		hotkey, ^+%i%, g_LimitGrouping, % status
	}
	Hotkey, If
	; Note : I have the emergency hotkey here if the user decides to set another hotkey to <#Space, so it cant get changed
	; but i think this could cause issues when the hotkey fails to get rebound somtimes? I dont think this actually happens

; 	Note:	Emergency Restart Hotkey - Something to keep in mind if actually using the REAL BlockInput Command 
;	Certain types of hook hotkeys can still be triggered when BlockInput is on. 
;	Examples include MButton (mouse hook) and LWin & Space
;	 ***(KEYBOARD HOOK WITH EXPLICIT PREFIX RATHER THAN MODIFIERS "$#")***.
;	hence <#Space wont work

	BufferInputFast.setEmergencyRestartKey(key_EmergencyRestart, "g_EmergencyRestart", "B P2147483647" ) ;buffers the hotkey and give it the highest possible priority
	Return
}

getCamCenteredUnit(UnitList) ; |delimited ** ; needs a minimum of 70+ ms to update cam location
{
	CamX := getPlayerCameraPositionX(), CamY := getPlayerCameraPositionY()
	loop, parse, UnitList, |
	{
		delta := Abs(CamX-getUnitPositionX(A_loopfield)) + Abs(CamY-getUnitPositionY(A_loopfield))
		if (delta < delta_closest || A_index = 1)
		{
			delta_closest := delta
			unit_closest := A_loopfield
		}
	}
	StringReplace, UnitList, UnitList,|%unit_closest%
	if !ErrorLevel ;none found
		StringReplace, UnitList, UnitList,%unit_closest%|	
	return unit_closest
}



castInjectLarva(Method="Backspace", ForceInject=0, sleepTime=80)	;SendWhileBlocked("^" CG_control_group)
{	global
	LOCAL 	click_x, click_y, BaseCount, oSelection, SkipUsedQueen, MissedHatcheries, QueenCount, FoundQueen
			, start_x, start_y
			, QueenMultiInjects, MaxInjects, CurrentQueenInjectCount
			, HatchIndex, Dx1, Dy1, Dx2, Dy2, QueenIndex

	LOCAL HighlightedGroup := getSelectionHighlightedGroup()

	if (Method = "MiniMap" OR ForceInject)
	{
		local xNew, yNew, injectedHatches

		; there could be an issue here with the selection buffer not being updated (should sleep for 10ms)

		oHatcheries := [] ; Global used to check if successfuly without having to iterate again
		local BaseCount := zergGetHatcheriesToInject(oHatcheries)
		Local oSelection := []
		Local SkipUsedQueen := []
		local MissedHatcheries := []
																		
		; use check the ctrl group, rather than the selection buffer, then wont have to sleep for selection buffer
		; getSelectedQueensWhichCanInject(oSelection, ForceInject)) 
		If (Local QueenCount := getGroupedQueensWhichCanInject(oSelection, ForceInject)) ; this wont fetch burrowed queens!! so dont have to do a check below - as burrowed queens can make cameramove when clicking their hatch
		{
			if (ForceInject || Inject_RestoreSelection)
				MTsend("^" Inject_control_group)
			MTsend(MI_Queen_Group)
			if ForceInject
				dsleep(5)
			For Index, CurrentHatch in oHatcheries
			{
				Local := FoundQueen := 0
				if isHatchInjected(CurrentHatch.Unit)
					continue
				For Index, Queen in oSelection.Queens
				{
					if SkipUsedQueen[Queen.unit]
						continue
					if (isQueenNearHatch(Queen, CurrentHatch, MI_QueenDistance) && isInControlGroup(MI_Queen_Group, Queen.unit) && Queen.Energy >= 25) ; previously queen type here (unit id/tpye) doesnt seem to work! weird
					{
						FoundQueen := CurrentHatch.NearbyQueen := SkipUsedQueen[Queen.unit] := 1 																		
						MTsend(Inject_spawn_larva)
						click_x := CurrentHatch.MiniMapX, click_y := CurrentHatch.MiniMapY
						If HumanMouse
							MouseMoveHumanSC2("x" click_x "y" click_y "t" rand(HumanMouseTimeLo, HumanMouseTimeHi))
					;	MTclick(click_x, click_y, , , , , False)
						MTclick(click_x, click_y)
						if sleepTime
							sleep % ceil(sleepTime * rand(1, Inject_SleepVariance)) ; eg rand(1, 1.XXXX) as the second parameter will always have a decimal point, dont have to worry about it returning just full integers eg 1 or 2 or 3
						Queen.Energy -= 25	
						injectedHatches++
						if (injectedHatches >= FInjectHatchMaxHatches && ForceInject)
							break, 2
						Break
					}
					else CurrentHatch.NearbyQueen := 0
				}
				if !FoundQueen
					MissedHatcheries.insert(CurrentHatch)
			}
		;	/* ; THIS Is trying to do multi injects
			if (MissedHatcheries.maxindex() && CanQueenMultiInject)
			{
				local QueenMultiInjects := []
				For Index, Queen in oSelection.Queens
				{
					local MaxInjects := Floor(Queen.Energery / 25)
					local CurrentQueenInjectCount := 0
					For Index, CurrentHatch in MissedHatcheries 
					{
						if (isQueenNearHatch(Queen, CurrentHatch, MI_QueenDistance) && isInControlGroup(MI_Queen_Group, Queen.unit) && Queen.Energy >= 25)
						{
							if !isobject(QueenMultiInjects[Queen.unit])
								QueenMultiInjects[Queen.unit] := []
							QueenMultiInjects[Queen.unit].insert(CurrentHatch)
							Queen.Energy -= 25
							CurrentQueenInjectCount ++
							if (CurrentQueenInjectCount = MaxInjects)
								break
						}

					}
				}
				For QueenIndex, QueenObject in QueenMultiInjects
					for index, CurrentHatch in QueenObject
					{
						if (A_index = 1)
							ClickSelectUnitsPortriat(QueenIndex, 10) 
						MTsend(Inject_spawn_larva) ;always need to send this, otherwise might left click minimap for somereason
						click_x := CurrentHatch.MiniMapX, click_y := CurrentHatch.MiniMapY
						If HumanMouse
							MouseMoveHumanSC2("x" click_x "y" click_y "t" rand(HumanMouseTimeLo, HumanMouseTimeHi))
					;	MTclick(click_x, click_y, "Left", "+", , , False)
						MTclick(click_x, click_y, "Left", "+")
						if sleepTime
							sleep % ceil(sleepTime * rand(1, Inject_SleepVariance))
						else dSleep(3)
						if (A_Index = QueenUnit.maxIndex())
							MTsend(MI_Queen_Group)
						injectedHatches++
						if (injectedHatches >= FInjectHatchMaxHatches && ForceInject)
							break, 2					
						}					
			}
		}
		else return ; no queens in control group - no actions were take
	}	
	else if ((Method = "Backspace Adv") || (Method = "Backspace CtrlGroup")) ; I.E. I have disabled this feature until i get around to finding the centred hatch better ((Method="Backspace Adv") || (Method = "Backspace CtrlGroup")) ;cos i changed the name in an update
	{		; this is really just the minimap method made to look like the backspace

		oHatcheries := [] ; Global used to check if successfuly without having to iterate again
		local BaseCount := zergGetHatcheriesToInject(oHatcheries)
		Local oSelection := []
		Local SkipUsedQueen := []
		local MissedHatcheries := []

	    For Index, CurrentHatch in oHatcheries 	; so (for the most part) the inject order should match the basecamera order - though there are more rules than just age
	    	CurrentHatch.Age := getUnitTimer(CurrentHatch.unit)
	    bubbleSort2DArray(oHatcheries, "Age", 0) ; 0 = descending

		If(Local QueenCount := getGroupedQueensWhichCanInject(oSelection))  ; this wont fetch burrowed queens!! so dont have to do a check below - as burrowed queens can make cameramove when clicking their hatch
		{
			if Inject_RestoreSelection
				MTsend("^" Inject_control_group)
			if Inject_RestoreScreenLocation
				MTsend(BI_create_camera_pos_x)
			MTsend(MI_Queen_Group)
			For Index, CurrentHatch in oHatcheries
			{
				Local := FoundQueen := 0
				click_x := CurrentHatch.MiniMapX, click_y := CurrentHatch.MiniMapY
				if sleepTime
					sleep % ceil( (sleepTime/2) * rand(1, Inject_SleepVariance)) 
		;		send {click Left %click_x%, %click_y%}
				MTclick(click_x, click_y)
				if sleepTime
					sleep % ceil( (sleepTime/2) * rand(1, Inject_SleepVariance))
				if isHatchInjected(CurrentHatch.Unit)
					continue
				For Index, Queen in oSelection.Queens
				{
					if SkipUsedQueen[Queen.unit]
						continue
					if (isQueenNearHatch(Queen, CurrentHatch, MI_QueenDistance) && isInControlGroup(MI_Queen_Group, Queen.unit) && Queen.Energy >= 25) ; previously queen type here (unit id/tpye) doesnt seem to work! weird
					{
						FoundQueen := CurrentHatch.NearbyQueen := SkipUsedQueen[Queen.unit] := 1 																		
						MTsend(Inject_spawn_larva)
						click_x := CurrentHatch.MiniMapX, click_y := CurrentHatch.MiniMapY
					
					;	click_x := A_ScreenWidth/2 , click_y := A_ScreenHeight/2
					;	send {click Left %click_x%, %click_y%}
						MTclick(click_x, click_y)
						Queen.Energy -= 25	
						Break
					}
					else CurrentHatch.NearbyQueen := 0
				}
				if !FoundQueen
					MissedHatcheries.insert(CurrentHatch)
			}
			if Inject_RestoreScreenLocation
			{
				sleep % ceil( (sleepTime/1.5) * rand(1, Inject_SleepVariance)) ; so this will actually mean the inject will sleep longer than user specified, but make it look a bit more real
				MTsend(BI_camera_pos_x) 										
			}
		}
		else return ; no queens
	}
	else ; if (Method="Backspace")
	{

		; 	Note: When a queen has inadequate energy for an inject, after pressing the inject larva key nothing will actually happen 
		;	so the subsequent left click on the hatch will actually select the hatch (as the spell wasn't cast)
		;	this was what part of the reason queens were somtimes being cancelled
		if  Inject_RestoreSelection
			MTsend("^" Inject_control_group)

		HatchIndex := getBuildingList(aUnitID["Hatchery"], aUnitID["Lair"], aUnitID["Hive"])
		if Inject_RestoreScreenLocation
			MTsend(BI_create_camera_pos_x)
		If (drag_origin = "Right" OR drag_origin = "R") And !HumanMouse ;so left origin - not case sensitive
			Dx1 := A_ScreenWidth-25, Dy1 := 45, Dx2 := 35, Dy2 := A_ScreenHeight-240	
		Else ;left origin
			Dx1 := 25, Dy1 := 25, Dx2 := A_ScreenWidth-40, Dy2 := A_ScreenHeight-240
		loop, % getBaseCameraCount()	
		{
			MTsend(base_camera)
			sleep % ceil( (sleepTime/2) * rand(1, Inject_SleepVariance))	;need a sleep somerwhere around here to prevent walkabouts...sc2 not registerings box drag?
			if isCastingReticleActive() ; i.e. cast larva
				MTsend(Escape) ; (deselects queen larva) (useful on an already injected hatch) this is actually a variable
			If (drag_origin = "Right" OR drag_origin = "R") And HumanMouse ;so left origin - not case sensitive
				Dx1 := A_ScreenWidth-15-rand(0,(360/1920)*A_ScreenWidth), Dy1 := 45+rand(5,(200/1080)*A_ScreenHeight), Dx2 := 40+rand((-5/1920)*A_ScreenWidth,(300/1920)*A_ScreenWidth), Dy2 := A_ScreenHeight-240-rand((-5/1080)*A_ScreenHeight,(140/1080)*A_ScreenHeight)
			Else If (drag_origin = "Left" OR drag_origin = "L") AND HumanMouse ;left origin
				Dx1 := 25+rand((0/1920)*A_ScreenWidth,(360/1920)*A_ScreenWidth), Dy1 := 25+rand((-5/1080)*A_ScreenHeight,(200/1080)*A_ScreenHeight), Dx2 := A_ScreenWidth-40-rand((-5/1920)*A_ScreenWidth,(300/1920)*A_ScreenWidth), Dy2 := A_ScreenHeight-240-rand((-5/1080)*A_ScreenHeight,(140/1080)*A_ScreenHeight)					
			If HumanMouse
			{
				MouseMoveHumanSC2("x" Dx1 "y" Dy1 "t" rand(HumanMouseTimeLo, HumanMouseTimeHi))
				sendInput {click down}
				MouseMoveHumanSC2("x" Dx2 "y" Dy2 "t" rand(HumanMouseTimeLo, HumanMouseTimeHi))
				sendInput {click up}
			}
			Else 
				MTsend("{click D " Dx1 " " Dy1 "}{Click U " Dx2 " " Dy2 "}")
			;	MTdragClick(Dx1, Dy1, Dx2, Dy2)
			sleep % ceil( (sleepTime/2) * rand(1, Inject_SleepVariance))
			if (QueenIndex := filterSlectionTypeByEnergy(25, aUnitID["Queen"]))
			{																	
				MTsend(Inject_spawn_larva)							;have to think about macro hatch though
				click_x := A_ScreenWidth/2 , click_y := A_ScreenHeight/2		;due to not using Shift - must have 2 queens if on same screen
																				;as will inject only 1 (as it will go to 1 hatch, then get the order to go the other before injecting the 1s)
				If HumanMouse
				{	click_x += rand((-75/1920)*A_ScreenWidth,(75/1080)*A_ScreenHeight), click_y -= 100+rand((-75/1920)*A_ScreenWidth,(75/1080)*A_ScreenHeight)
					MouseMoveHumanSC2("x" click_x  "y" click_y "t" rand(HumanMouseTimeLo, HumanMouseTimeHi))
					sendInput {click Left %click_x%, %click_y%}
				}
				Else MTClick(click_x, click_y)
			}
		}	
		if Inject_RestoreScreenLocation
		{
			sleep % ceil( (sleepTime/2) * rand(1, Inject_SleepVariance))	; so this will actually mean the inject will sleep longer than user specified, but make it look a bit more real
			MTsend(BI_camera_pos_x)										
		}
	}
	if (ForceInject || Inject_RestoreSelection)
	{
		MTsend(Inject_control_group)
		dsleep(5)
		;if HighlightedGroup
		;	sleep(2) ; After restoring a control group, needs at least 1 ms so tabs will register
		MTsend(sRepeat(NextSubgroupKey, HighlightedGroup))
	}
}


OldBackSpaceCtrlGroupInject()
{
 if  (1 = 2) ; I.E. I have disabled this feature until i get around to finding the centred hatch better ((Method="Backspace Adv") || (Method = "Backspace CtrlGroup")) ;cos i changed the name in an update
	{		
		send % BI_create_camera_pos_x
		send % MI_Queen_Group
		HatchIndex := getBuildingList(aUnitID["Hatchery"], aUnitID["Lair"], aUnitID["Hive"]) 
		click_x := A_ScreenWidth/2 , click_y := A_ScreenHeight/2
		If HumanMouse
		{	click_x += rand((-75/1920)*A_ScreenWidth,(75/1080)*A_ScreenHeight), click_y -= 100+rand((-75/1920)*A_ScreenWidth,(75/1080)*A_ScreenHeight)
			MouseMoveHumanSC2("x" click_x  "y" click_y "t" rand(HumanMouseTimeLo, HumanMouseTimeHi))
		}
		else
		{	click_x := A_ScreenWidth/2 , click_y := A_ScreenHeight/2
			MouseMove, click_x, click_y
		}		
		if (QueenIndex := filterSlectionTypeByEnergy(25, aUnitID["Queen"]))
			loop, % getBaseCameraCount()	
			{
				Hatch_i := A_index
				send % base_camera
				if (A_Index = 1)
				{
					HatchList := []
					sleep, 600 ; give time for cam to update slower since WOL 2.04
					CurrentHatch := getCamCenteredUnit(HatchIndex) ;get centered hatch ID
					HatchIndex := SortBasesByBaseCam(HatchIndex, CurrentHatch) ; sort the Hatches by age(to agree with camera list)
					loop, parse, HatchIndex, |
						HatchList[A_Index] := A_loopfield
				}
				else Sleep, %sleepTime%	;sleep needs to be here (to give time to update selection buffer?)				
				loop, parse, QueenIndex, |  	;like this to re-check energy if she injects a macro hatch - checking queen index was previouosly here
				{
					If areUnitsNearEachOther(A_LoopField, HatchList[Hatch_i] , MI_QueenDistance, MI_QueenDistance)
					{
						send % Inject_spawn_larva 	;when # hatches > queens (ie queens going walkabouts)		
						send {click Left %click_x%, %click_y%}				
						Break
					}
				}
			}			
	;	send % BI_camera_pos_x
	}
}



 zergGetHatcheriesToInject(byref Object)
 { 	global aUnitID
 	Object := []
 	aZergMains := [aUnitID["Hatchery"], aUnitID["Lair"], aUnitID["Hive"]]
 	Unitcount := DumpUnitMemory(MemDump)
 	while (A_Index <= Unitcount)
 	{
 		unit := A_Index - 1
 		if isTargetDead(TargetFilter := numgetUnitTargetFilter(MemDump, unit)) || !isOwnerLocal(numgetUnitOwner(MemDump, Unit)) || isTargetUnderConstruction(TargetFilter) 
	       Continue
	    pUnitModel := numgetUnitModelPointer(MemDump, Unit)
	    Type := numgetUnitModelType(pUnitModel)
	    For index, buildingType in aZergMains
		{	
			IF (type = buildingType)
			{
				MiniMapX := x := numGetUnitPositionXFromMemDump(MemDump, Unit)
				MiniMapY := y := numGetUnitPositionYFromMemDump(MemDump, Unit)
				z :=  numGetUnitPositionZFromMemDump(MemDump, Unit)
				convertCoOrdindatesToMiniMapPos(MiniMapX, MiniMapY)
				isInjected := numGetIsHatchInjectedFromMemDump(MemDump, Unit)
				Object.insert( {  "Unit": unit 
								, "x": x
								, "y": y
								, "z": z
								, "MiniMapX": MiniMapX
								, "MiniMapY": MiniMapY 
								, "isInjected": isInjected } )

			}	
		}
 	}
 	return Object.maxindex()
 }


WriteOutWarningArrays() ; this is used to 'save' the current warning arrays to config during a reload
{	global Alert_TimedOut, Alerted_Buildings, Alerted_Buildings_Base, config_file
	l_WarningArrays := "Alert_TimedOut,Alerted_Buildings,Alerted_Buildings_Base"
	loop, parse, l_WarningArrays, `,
	{
		For index, Object in %A_loopfield%
		{
			if (A_index <> 1)
				l_AlertShutdown .= ","
			if (A_loopfield = "Alert_TimedOut")
				For PlayerNumber, object2 in Object	;index = player name
					For Alert, warned_base in Object2
						l_AlertShutdown .= PlayerNumber " " Alert " " warned_base
			else
				For PlayerNumber, warned_base in Object	;index = player number
					l_AlertShutdown .= PlayerNumber " " warned_base	;use the space as the separator - not allowed in sc2 battletags	
		}
		Iniwrite, %l_AlertShutdown%, %config_file%, Resume Warnings, %A_loopfield%		
		l_AlertShutdown := ""
	}
	Iniwrite, 1, %config_file%, Resume Warnings, Resume
}

ParseWarningArrays() ;synchs the warning arrays from the config file after a reload
{	global Alert_TimedOut, Alerted_Buildings, Alerted_Buildings_Base, config_file
	l_WarningArrays := "Alert_TimedOut,Alerted_Buildings,Alerted_Buildings_Base"
	Iniwrite, 0, %config_file%, Resume Warnings, Resume
	loop, parse, l_WarningArrays, `,
	{
		ArrayName := A_loopfield
		%ArrayName% := []
		Iniread, string, %config_file%, Resume Warnings, %ArrayName%, %A_space%
		if string
			loop, parse, string, `,
			{
				StringSplit, VarOut, A_loopfield, %A_Space%
				if (ArrayName = "Alert_TimedOut")
					%ArrayName%[A_index, VarOut1, VarOut2] := VarOut3
				else
					%ArrayName%[A_index, VarOut1] := VarOut2	
			}
	}
	IniDelete, %config_file%, Resume Warnings
}

g_SplitUnits:
	input.hookBlock(True, True)
	sleep := Input.releaseKeys()
	critical, 1000
	input.hookBlock(False, False)
	if sleep
		DllCall("Sleep", Uint, 15) ;
	SplitUnits(SplitctrlgroupStorage_key, SleepSplitUnits)
return


; 	22/9/13 
;	Using a hookblock doesn't increase ropbustness when user is constantly holding down the hotkey
;	But this isn't a real issue anyway (and it works well even if they are)

g_SelectArmy:
;	input.hookBlock(True, True)
;	setLowLevelInputHooks(False)	
	critical, 10000
	input.pSendDelay(-1)
	input.pClickDelay(-1)
	MTsend(Sc2SelectArmy_Key)
	dSleep(20)
	aRemoveUnits := [], aSelected := []

; 	23/09
;	This WILL work with the new sorting method	
;	aRemoveUnits := findUnitsToRemoveFromArmy(aSelected, SelectArmyDeselectXelnaga, SelectArmyDeselectPatrolling
;						, SelectArmyDeselectHoldPosition, SelectArmyDeselectFollowing, l_ActiveDeselectArmy)
;	if aRemoveUnits.MaxIndex()
;		DeselectUnitsFromPanel(aRemoveUnits, aSelected, -1)

;	This is another way to do it with two slightly different functions (this way would be faster too)
	aUnitPortraitLocations := []
	aUnitPortraitLocations := findPortraitsToRemoveFromArmy("", SelectArmyDeselectXelnaga, SelectArmyDeselectPatrolling
									, SelectArmyDeselectHoldPosition, SelectArmyDeselectFollowing, l_ActiveDeselectArmy)
	DeselectUnitPortraits(aUnitPortraitLocations)

	dSleep(15)
	if SelectArmyControlGroupEnable
		MTsend("^" Sc2SelectArmyCtrlGroup)
	dSleep(5)
	input.pSendDelay(pKeyDelay)
	input.pClickDelay(pKeyDelay)
	critical, off
	input.hookBlock(False, False)	
	sleep 5
;	ObjTree(aUnitPortraitLocations)
;	setLowLevelInputHooks(True)	
	 	
	; 	Update:
	;	Adding a sleep at the end of the command increases reliability. It prevents the user slowing down SC
	; 	by allowing a small sleep even if the function is constantly repeating (user holding button)
	;	Also seems to give time for any input to clear so reduces chance of interrupting automation
	;	on next loop through
return


; aSelected can be used to pass an already SORTED selected array
; if no array, or an empty array is passed then it will retrieve one
; The first unit to be removed will have the highest unit panel position

findUnitsToRemoveFromArmy(byref aSelected := "", DeselectXelnaga = 1, DeselectPatrolling = 1, DeselectHoldPosition = 0, DeselectFollowing = 0, lTypes = "")
{ 	global aUnitMoveStates
	if (!isObject(aSelected) || !aSelected.units.maxIndex())
		numGetSelectionSorted(aSelected) ; get a sorted array of the selection buffer
	remove := []
	for i, unit in aSelected.units
	{
		state := getUnitMoveState(unit.unitIndex)
		if (DeselectXelnaga && isUnitHoldingXelnaga(unit.unitIndex))
			|| (DeselectPatrolling && state = aUnitMoveStates.Patrol)
			|| (DeselectHoldPosition && state = aUnitMoveStates.HoldPosition)
			|| (DeselectFollowing && (state = aUnitMoveStates.Follow || state = aUnitMoveStates.FollowNoAttack)) ;no attack follow is used by spell casters e.g. HTs & infests which dont have and attack
				remove.insert(unit.unitIndex)
		else if lTypes  
		{
			type := unit.unitId
			If type in %lTypes%
				remove.insert(unit.unitIndex)
		}			
	}
	; so unit click loctions are in descending order 
	reverseArray(remove)
	return remove
}

; returns a simple array with the exact unit portrait location to be clicked
; as used by ClickUnitPortrait
; The highest portrait locations come first
findPortraitsToRemoveFromArmy(byref aSelected := "", DeselectXelnaga = 1, DeselectPatrolling = 1, DeselectHoldPosition = 0, DeselectFollowing = 0, lTypes = "")
{ 	global aUnitMoveStates
	if (!isObject(aSelected) || !aSelected.units.maxIndex())
		numGetSelectionSorted(aSelected) ; get a sorted array of the selection buffer
	remove := []
	
	for i, unit in aSelected.units
	{	
		state := getUnitMoveState(unit.unitIndex)
		if (DeselectXelnaga && isUnitHoldingXelnaga(unit.unitIndex))
			|| (DeselectPatrolling && state = aUnitMoveStates.Patrol)
			|| (DeselectHoldPosition && state = aUnitMoveStates.HoldPosition)
			|| (DeselectFollowing && (state = aUnitMoveStates.Follow || state = aUnitMoveStates.FollowNoAttack)) ;no attack follow is used by spell casters e.g. HTs & infests which dont have and attack
				remove.insert(unit.unitPortrait) 
		else if lTypes  
		{
			type := unit.unitId
			If type in %lTypes%
				remove.insert(unit.unitPortrait) 
		}			
	}
	reverseArray(remove)
	return remove
}

; can pass an already sorted unit object/array (if you have one), so saves time having resort them
; aRemoveUnits is just a simple array containing each unitIndex to be removed
; aRemoveUnits sorted in descending order (of unit panel location)
; aSelection is the entire sorted selection object as returned by numGetSelectionSorted
; the units in aSelection.units need to be sorted so that they represent the locations in the unit panel
; i.e. the first unit in aSelection.units is at the top left of the unit panel

DeselectUnitsFromPanel(aRemoveUnits, aSelection := "", sleep := -1)	
{
	if aRemoveUnits.MaxIndex()
	{
		if !IsObject(aSelection)
			numGetSelectionSorted(aSelection)
			
		for i, removeUnitIndex in aRemoveUnits
		{
			for unitPanelLocation, Selected in aSelection.units
			{
				;can only deselect up to unitPanelLocation 143 
				; as unitpanel can only show 144 units
				if (unitPanelLocation > 143)
					break
				Else if (removeUnitIndex = Selected.unitIndex) 
				{		
					; -1 as selection index begins at 0 i.e 1st unit at pos 0 (top left)
					if ClickUnitPortrait(unitPanelLocation - 1, X, Y, Xpage, Ypage) 
						MTclick(Xpage, Ypage)
						; if changed pages, a sleep here is required under some conditions
					MTsend("+{click " x " " y "}")
					if (sleep != -1)
						dSleep(sleep)
				}
			}
		}
	}
	if getUnitSelectionPage()	;ie slection page is not 0 (hence its not on 1 (1-1))
	{
		ClickUnitPortrait(0, X, Y, Xpage, Ypage, 1) ; this selects page 1 when done
		MTclick(Xpage, Ypage)
	;	send {click Left %Xpage%, %Ypage%}
	}	

	return
}

; deselects an array of unit portraits
; the portraits should be sorted in descending order
DeselectUnitPortraits(aUnitPortraitLocations)
{
	for i, portrait in aUnitPortraitLocations
	{
		if (portrait <= 143)
		{
			if ClickUnitPortrait(portrait, X, Y, Xpage, Ypage) 
				MTclick(Xpage, Ypage)
			MTsend("+{click " x " " y "}")		
		}
	}
	if getUnitSelectionPage()	;ie slection page is not 0 (hence its not on 1 (1-1))
	{
		ClickUnitPortrait(0, X, Y, Xpage, Ypage, 1) ; this selects page 1 when done
		MTclick(Xpage, Ypage)
	;	send {click Left %Xpage%, %Ypage%}
	}
	return	
}


ClickSelectUnitsPortriat(unitIndex, sleep := 10, ClickModifier="")	;can put ^ to do a control click
{
	numGetSelectionSorted(aSelected, True) ; reversed
	for i, unit in aSelected.units
	{
		if (unitIndex = unit.UnitIndex && unit.unitPortrait < 144 ) ;can only deselect up to unitselectionindex 143 (as thats the maximun on the card)
		{
			if ClickUnitPortrait(unit.unitPortrait, X, Y, Xpage, Ypage) ; -1 as selection index begins at 0 i.e 1st unit at pos 0 top left
				MTclick(Xpage, Ypage)	 ;clicks on the page number
			if ClickModifier
				MTclick(x, y, "Left", ClickModifier) ;shift clicks the unit
			else MTclick(x, y)
			if (sleep != -1)
				dSleep(sleep)
		}
	}
	if getUnitSelectionPage()	;ie slection page is not 0 (hence its not on 1 (1-1))
	{
		ClickUnitPortrait(blank,X,Y, Xpage, Ypage, 1) ; this selects page 1 when done
		MTclick(Xpage, Ypage)
	}	
	return
}


ClickUnitPortrait(SelectionIndex=0, byref X=0, byref Y=0, byref Xpage=0, byref Ypage=0, ClickPageTab = 0) ;SelectionIndex begins at 0 topleft unit
{
	static AspectRatio, Xu0, Yu0, Size, Xpage1, Ypage1, Ypage6
	if (AspectRatio != newAspectRatio := getScreenAspectRatio())
	{
		AspectRatio := newAspectRatio
		If (AspectRatio = "16:10")
		{
			Xu0 := (578/1680)*A_ScreenWidth, Yu0 := (888/1050)*A_ScreenHeight	;X,Yu0 = the middle of unit portrait 0 ( the top left unit)
			Size := (56/1680)*A_ScreenWidth										;the unit portrait is square 56x56
			Xpage1 := (528/1680)*A_ScreenWidth, Ypage1 := (877/1050)*A_ScreenHeight, Ypage6 := (1016/1050)*A_ScreenHeight	;Xpage1 & Ypage6 are locations of the Portrait Page numbers 1-5 
		}	
		Else If (AspectRatio = "5:4")
		{	
			Xu0 := (400/1280)*A_ScreenWidth, Yu0 := (876/1024)*A_ScreenHeight
			Size := (51.57/1280)*A_ScreenWidth
			Xpage1 := (352/1280)*A_ScreenWidth, Ypage1 := (864/1024)*A_ScreenHeight, Ypage6 := (992/1024)*A_ScreenHeight
		}	
		Else If (AspectRatio = "4:3")
		{	
			Xu0 := (400/1280)*A_ScreenWidth, Yu0 := (812/960)*A_ScreenHeight
			Size := (51.14/1280)*A_ScreenWidth
			Xpage1 := (350/1280)*A_ScreenWidth, Ypage1 := (800/960)*A_ScreenHeight, Ypage6 := (928/960)*A_ScreenHeight
		}
		Else if (AspectRatio = "16:9")
		{
			Xu0 := (692/1920)*A_ScreenWidth, Yu0 := (916/1080)*A_ScreenHeight
			Size := (57/1920)*A_ScreenWidth	;its square
			Xpage1 := (638/1920)*A_ScreenWidth, Ypage1 := (901/1080)*A_ScreenHeight, Ypage6 := (1044/1080)*A_ScreenHeight

		}
		YpageDistance := (Ypage6 - Ypage1)/5		;because there are 6 pages - 6-1
	}

	if ClickPageTab	;use this to return the selection back to a specified page
	{
		PageIndex := ClickPageTab - 1
		Xpage := Xpage1, Ypage := Ypage1 + (PageIndex * YpageDistance)
		return 1
	}

	PageIndex := floor(SelectionIndex / 24)
	SelectionIndex -= 24 * PageIndex
	Offset_y := floor(SelectionIndex / 8) 
	Offset_x := SelectionIndex -= 8 * Offset_y		
	x := Xu0 + (Offset_x *Size), Y := Yu0 + (Offset_y *Size)

	; A delay may be required for selection page to update
	; could use an overide value - but not sure if the click would register
	if (PageIndex <> getUnitSelectionPage())
	{
		Xpage := Xpage1, Ypage := Ypage1 + (PageIndex * YpageDistance)
		return 1 ; indicating that you must left click the index page first
	}
	return 0	
}

FindSelectedUnitsOnXelnaga(byref aUnits)
{
	while (A_Index <= getSelectionCount())		;loop thru the units in the selection buffer	
		if isUnitHoldingXelnaga(unit := getSelectedUnitIndex(A_Index -1))
			aUnits.insert(unit)
	return
}

FindSelectedPatrollingUnits(byref aUnits)
{
	while (A_Index <= getSelectionCount())		;loop thru the units in the selection buffer	
		if isUnitPatrolling(unit := getSelectedUnitIndex(A_Index -1))
			aUnits.insert(unit)
	return
}
sortSelectedUnitsByDistance(byref aSelectedUnits, Amount = 3)	;takes a simple array which contains the selection indexes (begins at 0)
{ 													; the 0th selection index (1st in this array) is taken as the base unit to measure from
	aSelectedUnits := []
	sIndexBaseUnit := rand(0, getSelectionCount() -1) ;randomly pick a base unit 
	uIndexBase := getSelectedUnitIndex(sIndexBaseUnit)
	Base_x := getUnitPositionX(uIndexBase), Base_y := getUnitPositionY(uIndexBase)
	aSelectedUnits.insert({"Unit": uIndexBase, "Priority": getUnitSubGroupPriority(uIndexBase), "Distance": 0})

	while (A_Index <= getSelectionCount())	
	{
		unit := getSelectedUnitIndex(A_Index -1)
		if (sIndexBaseUnit = A_Index - 1)
			continue 
		else
		{
			unit_x := getUnitPositionX(unit), unit_y := getUnitPositionY(unit)
			aSelectedUnits.insert({"Unit": unit, "Priority": getUnitSubGroupPriority(unit), "Distance": Abs(Base_x - unit_x) + Abs(Base_y - unit_y)})
		}
	}
	bubbleSort2DArray(aSelectedUnits, "Distance", 1)
	while (aSelectedUnits.MaxIndex() > Amount)
		aSelectedUnits.Remove(aSelectedUnits.MaxIndex()) 	
	bubbleSort2DArray(aSelectedUnits, "Unit", 0) ;clicks highest units first, so dont have to calculate new click positions due to the units moving down one spot in the panel grid	
	bubbleSort2DArray(aSelectedUnits, "Priority", 1)	; sort in ascending order so select units lower down 1st	
	return 
} 


debugData()
{ 	global aPlayer, O_mTop, GameIdentifier
	, A_UnitGroupSettings, aLocalPlayer
	Player := getLocalPlayerNumber()
	unit := getSelectedUnitIndex()
	DllCall("QueryPerformanceFrequency", "Int64*", Frequency), DllCall("QueryPerformanceCounter", "Int64*", CurrentTick)
	getSystemTimerResolutions(MinTimer, MaxTimer)
	result := "Trainer Vr: " getProgramVersion() "`n"
	. "Script & Path: " A_ScriptFullPath "`n"
	. "Is64bitOS: " A_Is64bitOS "`n"
	. "PtrSize: " A_PtrSize "`n"
	. "IsUnicode: " A_IsUnicode "`n"
	. "OSVersion: " A_OSVersion "`n"
	. "Language Code: " A_Language "`n"
	. "Language: " getSystemLanguage() "`n"
	. "MinTimer: " MinTimer "`n"
	. "MaxTimer: " MaxTimer "`n"
	. "QPFreq: " Frequency "`n"
	. "QpTick: " CurrentTick "`n`n"
	. "==========================================="
	. "`n"
	. "XRes: " SC2HorizontalResolution() ", " A_ScreenWidth  "`n"
	. "YRes: " SC2VerticalResolution() ", " A_ScreenHeight "`n"
	. "Screen DPI: " A_ScreenDPI "`n" 
	. "Replay Folder: "  getReplayFolder() "`n"
	. "Account Folder: "  getAccountFolder() "`n"
	. "Game Exe: "	StarcraftExePath() "`n"
	. "Game Dir: "	StarcraftInstallPath() "`n"
	. "==========================================="
	. "`n"
	. "`n"
	result .= "GetGameType: " GetGameType(aPlayer) "`n"
	. "Enemy Team Size: " getEnemyTeamsize() "`n"
	. "Time: " gettime() "`n"
	. "Pause: " isGamePaused() "`n"
	. "Chat Focus: " isChatOpen() "`n"
	. "Menu Focus: " isMenuOpen() "`n"
	. "Idle Workers: " getIdleWorkers() "`n"
	. "Supply/Cap: " getPlayerSupply() "/" getPlayerSupplyCap() "`n"
	. "Gas: " getPlayerGas() "`n"
	. "Money: " getPlayerMinerals() "`n"
	. "GasIncome: " getPlayerGasIncome() "`n"
	. "MineralIncome: " getPlayerMineralIncome() "`n"
	. "BaseCount: " getBaseCameraCount() "`n"
	. "LocalSlot: " getLocalPlayerNumber() "`n"
	. "Colour: " getplayercolour(Player) "`n"
	. "Team: " getplayerteam(Player) "`n"
	. "Type: " getPlayerType(Player) "`n"
	. "Local Race: " getPlayerRace(Player) "`n"
	. "Local Name: " getPlayerName(Player) "`n"
	. "Unit Count: " getUnitCount() "`n"
	. "Highest Unit Index: " getHighestUnitIndex() "`n"
	. "Selected Unit: `n"
	. A_Tab "Index u1: " getSelectedUnitIndex() "`n"
	. A_Tab "Type u1: " getunittype(getSelectedUnitIndex()) "`n"
	. A_Tab "Priority u1: " getUnitSubGroupPriority(getSelectedUnitIndex()) "`n"
	. A_Tab "Count: " getSelectionCount() "`n"
	. A_Tab "Owner: " getUnitOwner(getSelectedUnitIndex()) "`n"
	. A_Tab "Timer: " getUnitTimer(getSelectedUnitIndex()) "`n"
	. A_Tab "Injected: " isHatchInjected(getSelectedUnitIndex()) "`n"
	. A_Tab "Chronoed: " isUnitChronoed(getSelectedUnitIndex()) "`n"
	. A_Tab "Mmap Radius: " getMiniMapRadius(getSelectedUnitIndex()) "`n" 
	. A_Tab "Energy: " getUnitEnergy(getSelectedUnitIndex()) "`n" 
	. A_Tab "PosZ Round: " round(getUnitPositionZ(unit), 1) "`n"
	. A_tab "PosZ : " getUnitPositionZ(unit) "`n"
	. "Map: `n"
	. A_Tab "Map Left: " getMapLeft() "`n"
	. A_Tab "Map Right: " getMapRight() "`n"
	. A_Tab "Map Bottom: " getMapBottom() "`n"
	. A_Tab "Map Top: " getMapTop() "`n"
	. A_Tab "Map Top: "ReadMemory(O_mTop, GameIdentifier) "`n"
	. A_Tab "`n`n"
	. "AutoGroupEnabled: " A_UnitGroupSettings["AutoGroup", aLocalPlayer["Race"], "Enabled"]
	return result
}



; Returns a number indicating that chat was open and text was saved
; this is just used in functions to easily store the current chat string
; and then send it back afterwards
; Just realised that if the person is chatting to someone else, e.g. a friend or 
; sending message to a player it will by default send it to an ally
class ChatString
{
	static ChatString, ChatStatus

	set()
	{ 	
		GLOBAL Escape
		if(this.ChatStatus := isChatOpen())
		{
			this.ChatString := getChatText()
			; send variable escape to close chat txt
			MTsend(Escape) 
			; Dont return the chat string because if chat is open
			; but nothing is typed then blank will be returned 
			; which is equivalent to false
			return 1
		}
		else return 0
	}
	send()
	{
		if this.ChatStatus
		{
			; cant use clipboard as if you chage the contents back to previous
			; before game processed the command then will paste the prevClipboard contents


			; Using controlSend can result in extra characters in text 
			; these are from the the artifical keystrokes sent using
			; post message for the automation more specifically from the WM_Char component
			SetStoreCapslockMode, on
			MTsend("{Enter}" this.ChatString)
			; restore capslock mode so text can be in correct case
			SetStoreCapslockMode, off	
			return
		}
	}

}


/*	Documents\StarCraft II\Accounts\<numbers>\Variables.txt 
	The Account Folder has the Variables.txt file
	and Hotkeys folder


	Within Variables.txt file is a hotkeyprofile= key
	Values For standard (non-modfied SC2 profiles):

	hotkeyprofile=0_Default  		; Standard
	hotkeyprofile=1_NameRightSide	; Standard for Lefties
	hotkeyprofile=2_GridLeftSide	; Grid
	hotkeyprofile=3_GridRightSide	; Grid for Lefties
	hotkeyprofile=4_Classic			; Classic

	If using a user hotkey profiles, it will contain the active hotkey file which is stored in ..\Hotkeys folder
	eg
	hotkeyprofile=Good 				; using the good Hotkey profile



*/
/*
	Default=[nothing] (that would be the Normal Left Side)
	Suffix=_NRS = Normal Right Side (for lefties)
	Suffix=_GLS = Grid Left Side
	Suffix=_GRS = Grid Right Side (for lefties)
	Suffix=_SC1 = Classic

*/


/*	Hotkey file eg Documents\StarCraft II\Accounts\<numbers>\Hotkeys\
	This is pretty much just an ini file containing the altered hotkeys
	
	-	Has a [Settings] section
		If based on grid profile will contian a 
		Grid=1 (this is missing in the other profiles)

	- A "Suffix=" line 
		indicating the standard hotkey profile the active settings are based on 
		(if there's no Suffix line then it's based on "Standard")

		_USDL ...not sure univeral? This appears in the mpq extracted hotkeys


	obviously for grid layout commands (command card) 00-14 corresond to the keyboard letters

*/

getAccountFolder()
{

		; example: D:\My Computer\My Documents\StarCraft II\Accounts\56064144\6-S2-1-79722\Replays\
	replayFolder := getReplayFolder()
	StringReplace, ModifiedString, replayFolder,  \Accounts\, ?, All ;replace with ? which can occur in name
	stringSplit, output, ModifiedString, ?
	; output1 D:\My Computer\My Documents\StarCraft II
	; output2 56064144\6-S2-1-79722\Replays\
	loop % strlen(output2)
		if ((Char := substr(output2, A_Index, 1)) = "\") ; read each character of account number until reach '\' of next folder
			break
		else AccountNumber .= Char ;

	return output1 "\" AccountNumber "\"
}


/*

. The two offsets I have listed right now are 0x2031078 and 0x03ED4970, but I can't remember exactly what they are for. I've changed the method I use a bit so that might not be much help. 

Also, and more importantly: all the hotkeys have been moved to new files:

patch-enUS.SC2Archive\Mods\Core.SC2Mod\enUS.SC2Data\LocalizedData

and

patch-enUS.SC2Archive\Mods\Liberty.SC2Mod\enUS.SC2Data\LocalizedData

they are both named GameHotkeys.txt (so we'll have to keep using the extraction merging)


and if you want to implement loading of the default hotkeys, the directory :

Mods\Core.SC2Mod\Base.SC2Data\UI\Hotkeys

contains all the files (the .SC2Hotkeys filetype is openable with notepad) that directs which setting goes with which suffix, here's the list :

Default=[nothing] (that would be the Normal Left Side)
Suffix=_NRS = Normal Right Side (for lefties)
Suffix=_GLS = Grid Left Side
Suffix=_GRS = Grid Right Side (for lefties)
Suffix=_SC1 = Classic



*/

splitByMouseLocation(SplitctrlgroupStorage_key)
{
	GLOBAL aLocalPlayer, aUnitID, NextSubgroupKey
	MouseGetPos, mx, my
	DllCall("Sleep", Uint, 5)
	HighlightedGroup := getSelectionHighlightedGroup()
	MTsend("^" SplitctrlgroupStorage_key)
}


/*
	tl 	27 62
	tR 	1883 62
	bL 13 733
	BR 	1894 756
*/

SplitUnits(SplitctrlgroupStorage_key, SleepSplitUnits)
{ 	GLOBAL aLocalPlayer, aUnitID, NextSubgroupKey

	sleep, % SleepSplitUnits
	HighlightedGroup := getSelectionHighlightedGroup()
	MTsend("^" SplitctrlgroupStorage_key)
;	BlockInput, MouseMove
;	mousegetpos, Xorigin, Yorigin
	aSelectedUnits := []
	xSum := ySum := 0

 	If (aLocalPlayer["Race"] = "Terran")
		worker := "SCV"	
	Else If (aLocalPlayer["Race"] = "Protoss")
		worker := "Probe"
	Else Worker := "Drone"	
	selectionCount := getSelectionCount()

	while (A_Index <= selectionCount)	
	{
		unit := getSelectedUnitIndex(A_Index -1)
		getUnitMiniMapMousePos(unit, mX, mY)
		aSelectedUnits.insert({"Unit": unit, "mouseX": mX, "mouseY": mY, absDistance: ""})

		if (getUnitType(unit) = aUnitID[Worker])
			workerCount++		
		Else if (getUnitType(unit) = aUnitID["WidowMine"])
			WidowMine++	
		Else if (getUnitType(unit) = aUnitID["SiegeTank"])
			SiegeTank++
	}

	if (workerCount / selectionCount >= .3 ) ; i.e. 30% of the selected units are workers
		uSpacing := 10 ; for hellbat and hellion spread
	Else if (WidowMine / selectionCount >= .9 ) ; i.e. 90% of the selected units are workers
		uSpacing := 8 ; for hellbat and hellion spread
	Else if (SiegeTank / selectionCount >= .9 ) ; i.e. 90% of the selected units are workers
		uSpacing := 9 ; for hellbat and hellion spread
	Else uSpacing := 5

	for index, unit in aSelectedUnits
		xSum += unit.mouseX, ySum += unit.mouseY
	xAvg := xSum/aSelectedUnits.MaxIndex(), yAvg := ySum/aSelectedUnits.MaxIndex()	
	while (aSelectedUnits.MaxIndex() > squareSpots := A_Index * A_Index)
		continue	
;	botLeftUnitX := xAvg-(sqrt(squareSpots)*uSpacing)/2 , botLeftUnitY := yAvg-(sqrt(squareSpots)*uSpacing)/2 ; should /2?? but is betr without it
	botLeftUnitX := xAvg-sqrt(squareSpots) , botLeftUnitY := yAvg-sqrt(squareSpots) ; should /2?? but is betr without it
	
;	clipboard := ""
	while (selectionCount > 0)
	{
		
		unit := aSelectedUnits[1] ;grab the closest unit
		boxSpot := A_Index
		X_offsetbox := y_offsetbox := 0
		while (boxSpot > floor(sqrt(squareSpots) * A_Index))
			y_offsetbox ++

		X_offsetbox := (boxSpot - 1) - sqrt(squareSpots) * y_offsetbox

		x := X_offsetbox*uSpacing + botLeftUnitX, Y := y_offsetbox*uSpacing + botLeftUnitY
	;	x := round(x), y := round(y)	;cos mousemove ignores decimal 
		x := round(x + rand(-.5,.5)), y := round(y + rand(-.5,.5)) 	;cos mousemove ignores decimal 
		for index, unit in aSelectedUnits
			unit.absDistance := Abs(x - unit.mouseX)+ Abs(y - unit.mouseY)
;		clipboard .= "(" x ", " y ")`n"

		bubbleSort2DArray(aSelectedUnits, "absDistance", 1)		
		tmpObject := []
		tmpObject.insert(aSelectedUnits[1])
		;send {click right %X%, %Y%}
		pClick(x, y, "Right")
		;MTsend("a{click left " x " " y "}")
		
	;	DeselectUnitsFromPanel(tmpObject, -1)		;might not have enough time to update the selections?
		
		DeselectUnitsFromPanel(tmpObject, 1)		;might not have enough time to update the selections?
		aSelectedUnits.remove(1)
		selectionCount--

	}
;	clipboard .= "avg (" xavg ", " yavg ")`n"
;	clipboard .= "BL (" botLeftUnitX ", " botLeftUnity ")`n"
;	clipboard .= "Squarespots: " squareSpots "`n"
	sendSequence := SplitctrlgroupStorage_key
	loop % HighlightedGroup
		sendSequence .= NextSubgroupKey
	MTsend(sendSequence)

;	BlockInput, MouseMoveOff
;	send {click %Xorigin%, %Yorigin%, 0}
		return
}



SplitUnitsWorking(SplitctrlgroupStorage_key, SleepSplitUnits)
{
	MTsend("^" SplitctrlgroupStorage_key)
	mousegetpos, Xorigin, Yorigin
	aSelectedUnits := []
	xSum := ySum := 0
	while (A_Index <= getSelectionCount())	
	{
		unit := getSelectedUnitIndex(A_Index -1)
		getUnitMiniMapMousePos(unit, mX, mY)
		aSelectedUnits.insert({"Unit": unit, "mouseX": mX, "mouseY": mY})
	}
	bubbleSort2DArray(aSelectedUnits, "Unit", 0) ;clicks highest units first, so dont have to calculate new click positions due to the units moving down one spot in the panel grid	
	bubbleSort2DArray(aSelectedUnits, "Priority", 1)	; sort in ascending order so select units lower down 1st	

	for index, unit in aSelectedUnits
		xSum += unit.mouseX, ySum += unit.mouseY
	xAvg := xSum/aSelectedUnits.MaxIndex(), yAvg := ySum/aSelectedUnits.MaxIndex()

	while (getSelectionCount() > 1)
	{
		unit := aSelectedUnits[1]
	;	xR := rand(-2,2), yR := rand(-2,2)
		FindAngle(Direction, Angle, xAvg,yAvg,unit.mouseX,unit.mouseY)
		FindXYatAngle(X, Y, Angle, Direction, 4, unit.mouseX, unit.mouseY)
		x += rand(-2,2), y += rand(-2,2)
		send {click right %X%, %Y%}
		tmpObject := []
		tmpObject.insert(aSelectedUnits[1])
		DeselectUnitsFromPanel(tmpObject, SleepSplitUnits)
		aSelectedUnits.remove(1)
		if (aSelectedUnits.MaxIndex() <= 3)
			break
	}
	MTsend(SplitctrlgroupStorage_key)
	send {click  %Xorigin%, %Yorigin%, 0}
		return
}


FindAngle(byref Direction, byref Angle, x1,y1,x2,y2)
{
	v1 := [], v2 := [], vR := []
	v1.x := x1, v1.y := y1	;avg
	v2.x := x2, v2.y := y2

	vR.x := v2.x - v1.x, vR.y := v2.y - v1.y


	Vr.l := sqrt(vR.x**2 + vR.y**2)
	pi := 4 * ATan(1)
	a := abs(vR.x)	;side adjacent angle
	b := abs(vR.y)	;side opposite angle
	c := Vr.l
	if (abs(vR.x) >= abs(vR.y))
		Angle := Asin(b/c) * 180/pi 
	else
		Angle := Asin(b/c) * 180/pi 
	if 	(vR.x > 0)
		Direction := "R"
	else Direction := "L"
	if (vR.y > 0)
		Direction .= "U"
	else Direction .= "D"
	;dir RU, RD, LU, LD
return
}

FindXYatAngle(byref ResultX, byref ResultY,	Angle, Direction, distance, X, Y)
{
	pi := 4 * ATan(1)
	AngleRad :=  pi/180 * Angle
	c := distance
	a := C*cos(AngleRad) 
	b := c*sin(AngleRad) 
	if Direction contains R
		ResultX :=  X + b
	if Direction contains L
		ResultX :=  X - b
	if Direction contains U
		ResultY := Y + a
	if Direction contains D
		ResultY := Y - a
	return
}

/*
	object looks like this
	(owner)	|----3
	(Priority)	 |-----2
	(unit)			   |------247

*/

; an easier way to do this would just to create an array containg an object of each unit
; each unit object would then have type, owner, priorty property
; and it could then be sorted by each property in turn to get the order correct
; but tipple sorting an array would take 'considerable' time, at least relative to not sorthing it
; so i would rather do it without sorting the array

getEnemyUnitCount(byref aEnemyUnits, byref aEnemyBuildingConstruction, byref aUnitID)
{
	GLOBAL DeadFilterFlag, aPlayer, aLocalPlayer, aUnitTargetFilter, aUnitInfo, 
	aEnemyUnits := [], aEnemyBuildingConstruction := []
;	if !aEnemyUnitPriorities	;because having  GLOBAL aEnemyUnitPriorities := [] results in it getting cleared each function run
;		aEnemyUnitPriorities := []

	Unitcount := DumpUnitMemory(MemDump)
	while (A_Index <= Unitcount)
	{

 		unit := A_Index - 1
	    TargetFilter := numgetUnitTargetFilter(MemDump, unit)
	    if (TargetFilter & DeadFilterFlag || TargetFilter & aUnitTargetFilter.Hallucination)
	       Continue
		owner := numgetUnitOwner(MemDump, Unit) 

	    if  (aPlayer[Owner, "Team"] <> aLocalPlayer["Team"] && Owner)
	    {
	    	pUnitModel := numgetUnitModelPointer(MemDump, Unit)
	    	Type := numgetUnitModelType(pUnitModel)
	    	if  (Type < aUnitID["Colossus"])
				continue	
			if (!Priority := aUnitInfo[Type, "Priority"]) ; faster than reading the priority each time - this is splitting hairs!!!
				aUnitInfo[Type, "Priority"] := Priority := numgetUnitModelPriority(pUnitModel)

			if (TargetFilter & aUnitTargetFilter.UnderConstruction)
			{
				aEnemyBuildingConstruction[Owner, Priority, Type] := aEnemyBuildingConstruction[Owner, Priority, Type] ? aEnemyBuildingConstruction[Owner, Priority, Type] + 1 : 1
				aEnemyBuildingConstruction[Owner, "TotalCount"] := aEnemyBuildingConstruction[Owner, "TotalCount"] ? aEnemyBuildingConstruction[Owner, "TotalCount"] + 1 : 1
			}		; this is a cheat and very lazy way of incorporating a count into the array without stuffing the for loop and having another variable
			Else 
			{
				if (Type = aUnitID["CommandCenter"] && MorphingType := isCommandCenterMorphing(unit))	; this allows the orbital to show as a 'under construction' unit on the right
					Priority := aUnitInfo["CommandCenter", "Priority"], aEnemyBuildingConstruction[Owner, Priority, MorphingType] := aEnemyBuildingConstruction[Owner, Priority, MorphingType] ? aEnemyBuildingConstruction[Owner, Priority, MorphingType] + 1 : 1 ;*** use 4 as morphing has no 0 priority, which != 4/CC
				else if (Type = aUnitID["Hatchery"] || aUnitID["Lair"]) && MorphingType := isHatchOrLairMorphing(unit)
					Priority := aUnitInfo["Hatchery", "Priority"], aEnemyBuildingConstruction[Owner, Priority, MorphingType] := aEnemyBuildingConstruction[Owner, Priority, MorphingType] ? aEnemyBuildingConstruction[Owner, Priority, MorphingType] + 1 : 1
				else
					aEnemyUnits[Owner, Priority, Type] := aEnemyUnits[Owner, Priority, Type] ? aEnemyUnits[Owner, Priority, Type] + 1 : 1 ;note +1 (++ will not work!!!)
			}
	   	}
	}
	Return
}

FilterUnits(byref aEnemyUnits, byref aEnemyBuildingConstruction, byref aUnitPanelUnits, byref aUnitID, aPlayer)	;care have used aUnitID everywhere else!!
{	global aUnitInfo
	;	aEnemyUnits[Owner, Type]
	STATIC aRemovedUnits := {"Terran": ["BarracksTechLab","BarracksReactor","FactoryTechLab","FactoryReactor","StarportTechLab","StarportReactor"]
							, "Protoss": ["Interceptor"]
							, "Zerg": ["CreepTumorBurrowed","Broodling","Locust"]}

	STATIC aAddUnits 	:=	{"Terran": {SupplyDepotLowered: "SupplyDepot", WidowMineBurrowed: "WidowMine", CommandCenterFlying: "CommandCenter", OrbitalCommandFlying: "OrbitalCommand"
										, BarracksFlying: "Barracks", StarportFlying: "Starport", SiegeTankSieged: "SiegeTank", VikingAssault: "VikingFighter"}
							, "Zerg": {DroneBurrowed: "Drone", ZerglingBurrowed: "Zergling", HydraliskBurrowed: "Hydralisk", UltraliskBurrowed: "Ultralisk", RoachBurrowed: "Roach"
							, InfestorBurrowed: "Infestor", BanelingBurrowed: "Baneling", QueenBurrowed: "Queen", SporeCrawlerUprooted: "SporeCrawler", SpineCrawlerUprooted: "SpineCrawler"}} 

	STATIC aAddConstruction := {"Terran": {BarracksTechLab: "TechLab", BarracksReactor: "Reactor", FactoryTechLab: "TechLab", FactoryReactor: "Reactor", StarportTechLab: "TechLab", StarportReactor: "Reactor"}}


	STATIC aUnitOrder := 	{"Terran": ["SCV", "OrbitalCommand", "PlanetaryFortress", "CommandCenter"]
							, "Protoss": ["Probe", "Nexus"]
							, "Zerg": ["Drone","Hive","Lair", "Hatchery"]}

	; aUnitPanelUnits is an object which contains the custom filtered (removed) user selected units
	;	aUnitPanelUnits ----Race
	;						|------- FilteredCompleted
	;						|------- FilteredUnderConstruction
	;
		/*
		units.insert({"Unit": unitID, Priority: UnitPriority, built: count, constructing: conCount})
		this will look like
		index 	1
				|
				|----- Unit:
				|------Priority etc
				= etc
				|
				2
				|----- Unit:
		Then use sort to arrange correctly
			*/



									; note - could have just done - if name contains "Burrowed" check, substring = minus burrowed
									; overlord cocoon = morphing overseer (and it isnt under construction)
									;also need to account for morphing drones into buildings 
/*									; SupplyDepotDrop
	object looks like this
	(owner)		 3
	(Priority)	 |-----2
	(unit)			   |------247--->Count

*/
	for owner, priorityObject in aEnemyUnits
	{
	;	aDeleteKeys := []					;****have to 'save' the delete keys, as deleting them during a for loop will cause you to go +2 keys on next loop, not 1
		race := aPlayer[owner, "Race"]		;it doesn't matter if it attempts to delete the same key a second time (doesn't effect anything)

		if (race = "Zerg" && priorityObject[aUnitInfo[aUnitID["Drone"], "Priority"], aUnitID["Drone"]] && aEnemyBuildingConstruction[Owner, "TotalCount"])
			priorityObject[aUnitInfo[aUnitID["Drone"], "Priority"], aUnitID["Drone"]] -= aEnemyBuildingConstruction[Owner, "TotalCount"] ; as drones morphing are still counted as 'alive' so have to remove them		

		for index, removeUnit in aRemovedUnits[race]
		{
			removeUnit := aUnitID[removeUnit]
			priority := aUnitInfo[removeUnit, "Priority"]
			priorityObject[priority].remove(removeUnit, "")
		}

		for subUnit, mainUnit in aAddUnits[Race]
		{
			subunit := aUnitID[subUnit]
			subPriority := aUnitInfo[subunit, "Priority"]
			if (total := priorityObject[subPriority, subunit])			;** care as if unit has not been seen before, then this priority may be blank!!
			{														;** actually its the other unit priority which may be blank
				mainUnit := aUnitID[mainUnit]
				if !priority := aUnitInfo[mainUnit, "Priority"]
					priority := subPriority		;take a change, hopefully they will have same priority



				if priorityObject[priority, mainUnit]
					priorityObject[priority, mainUnit] += total
				else priorityObject[priority, mainUnit] := total
				priorityObject[subPriority].remove(subunit, "")
			;	aEnemyUnits[owner, priority, subunit] := ""
			;	aEnemyUnits[owner, priority].remove(subunit, "")
			}	
		}

		for index, removeUnit in aUnitPanelUnits[race, "FilteredCompleted"]
		{
			removeUnit := aUnitID[removeUnit]
			priority := aUnitInfo[removeUnit, "Priority"]
			priorityObject[priority].remove(removeUnit, "")
		}


		for index, unit in aUnitOrder[race]
			if (count := priorityObject[aUnitInfo[aUnitID[unit], "Priority"], aUnitID[unit]])
			{
				index := 0 - aUnitOrder[race].maxindex() + A_index ; hence so the first unit in array eg SCV will be on the left - last unit will have priority 0
			 	priorityObject[index, aUnitID[unit]] := count 		;change priority to fake ones - so that Obital is on far left, followed by
			 	priority := aUnitInfo[aUnitID[unit], "Priority"]		; PF and then CC
			 	priorityObject[priority].remove(aUnitID[unit], "")	
			}		


;		for index, unit in aDeleteKeys												; **********	remove(unit, "") Removes an integer key and returns its value, but does NOT affect other integer keys.
;			priorityObject[aEnemyUnitPriorities[unit]].remove(unit, "")				;				as the keys are integers, otherwise it will decrease the keys afterwards by 1 for each removed unit!!!!													
	}

	for owner, priorityObject in aEnemyBuildingConstruction
	{
		race := aPlayer[owner, "Race"]	

		for subUnit, mainUnit in aAddConstruction[Race]
		{
			subunit := aUnitID[subUnit]
			subPriority := aUnitInfo[subunit, "Priority"]
			if (total := priorityObject[subPriority, subunit])
			{
				mainUnit := aUnitID[mainUnit]
				if !priority := aUnitInfo[mainUnit, "Priority"]
					priority := subPriority		;take a change, hopefully they will have same priority can cause issues

				if priorityObject[priority, mainUnit]
					priorityObject[priority, mainUnit] += total
				else priorityObject[priority, mainUnit] := total
				priorityObject[subPriority].remove(subunit, "")
				aEnemyBuildingConstruction[Owner, "TotalCount"] -= total 	;these counts still seem to be out, but works for zerg?
			}		
		}

		for index, removeUnit in aUnitPanelUnits[race, "FilteredUnderConstruction"]
		{
			removeUnit := aUnitID[removeUnit]
			priority := aUnitInfo[removeUnit, "Priority"]
			priorityObject[priority].remove(removeUnit, "")
		}

		for index, unit in aUnitOrder[race]		;this will ensure the change in priority matches the changes made above to make the order correct, so they can be added together.
			if (count := priorityObject[aUnitInfo[aUnitID[unit], "Priority"], aUnitID[unit]])
			{
				index := 0 - aUnitOrder[race].maxindex() + A_index ; hence so the first unit in array eg SCV will be on the left - last unit will have priority 0
			 	priorityObject[index, aUnitID[unit]] := count 		;change priority to fake ones - so that Obital is on far left, followed by
			 	priority := aUnitInfo[aUnitID[unit], "Priority"]		; PF and then CC
			 	priorityObject[priority].remove(aUnitID[unit], "")	
			}	


	}
	return
}

getLongestEnemyPlayerName(aPlayer)
{
	localTeam := getPlayerTeam(getLocalPlayerNumber())
	for index, Player in aPlayer
		if (player.team != localTeam && StrLen(player.name) > StrLen(LongestName))
			LongestName := player.name
	return player.name
}

DrawUnitOverlay(ByRef Redraw, UserScale = 1, PlayerIdentifier = 0, Drag = 0)
{
	GLOBAL aEnemyUnits, aEnemyBuildingConstruction, a_pBitmap, aPlayer, aLocalPlayer, HexColour, GameIdentifier, config_file, UnitOverlayX, UnitOverlayY, MatrixColour 
	static Font := "Arial", Overlay_RunCount, hwnd1, DragPrevious := 0, a_pBrush := [], TransparentBlack := 0x78000000
	Overlay_RunCount ++	
	DestX := i := 0
	Options := "Center cFFFFFFFF r4 s" 17*UserScale					;these cant be static	
	If (Redraw = -1)
	{
		Try Gui, UnitOverlay: Destroy
		Overlay_RunCount := 0
		Redraw := 0
		Return
	}	
	Else if (ReDraw AND WinActive(GameIdentifier))
	{
		Try Gui, UnitOverlay: Destroy
		Overlay_RunCount := 1
		Redraw := 0
	}
	If (Overlay_RunCount = 1)
	{
		Gui, UnitOverlay: -Caption Hwndhwnd1 +E0x20 +E0x80000 +LastFound  +ToolWindow +AlwaysOnTop
		Gui, UnitOverlay: Show, NA X%UnitOverlayX% Y%UnitOverlayY% W400 H400, UnitOverlay
		OnMessage(0x201, "OverlayMove_LButtonDown")
		OnMessage(0x20A, "OverlayResize_WM_MOUSEWHEEL")
		if !a_pBrush[TransparentBlack]	;faster than creating same colour again 
			a_pBrush[TransparentBlack] := Gdip_BrushCreateSolid(TransparentBlack)	; Create a partially transparent, black brush
	}	
	If (Drag AND !DragPrevious)
	{	DragPrevious := 1
		Gui, UnitOverlay: -E0x20
	}
	Else if (!Drag AND DragPrevious)
	{	DragPrevious := 0
		Gui, UnitOverlay: +E0x20 +LastFound
		WinGetPos,UnitOverlayX,UnitOverlayY		
		IniWrite, %UnitOverlayX%, %config_file%, Overlays, UnitOverlayX
		Iniwrite, %UnitOverlayY%, %config_file%, Overlays, UnitOverlayY		
	}
	hbm := CreateDIBSection(A_ScreenWidth, A_ScreenHeight)
	hdc := CreateCompatibleDC()
	obm := SelectObject(hdc, hbm)
	G := Gdip_GraphicsFromHDC(hdc)
	DllCall("gdiplus\GdipGraphicsClear", "UInt", G, "UInt", 0)
	setDrawingQuality(G)	
	for slot_number, priorityObject in aEnemyUnits ; slotnumber = owner and slotnuber is an object
	{
		DestY := i ? i*Height : 0
		DestX := 0

		If (PlayerIdentifier = 1 Or PlayerIdentifier = 2 )
		{	
			IF (PlayerIdentifier = 2)
				OptionsName := " Bold cFF" HexColour[aPlayer[slot_number, "Colour"]] " r4 s" 17*UserScale
			Else IF (PlayerIdentifier = 1)
				OptionsName := " Bold cFFFFFFFF r4 s" 17*UserScale		
			gdip_TextToGraphics(G, getPlayerName(slot_number), "x0" "y"(DestY +12*UserScale)  OptionsName, Font) ;get string size	
		;	StringSplit, TextSize, TextData, | ;retrieve the length of the string		
			if !LongestNameSize
			{
				LongestNameData :=	gdip_TextToGraphics(G, getLongestEnemyPlayerName(aPlayer), "x0" "y"(DestY)  " Bold c00FFFFFF r4 s" 17*UserScale	, Font) ; text is invisible ;get string size	
				StringSplit, LongestNameSize, LongestNameData, | ;retrieve the length of the string
				LongestNameSize := LongestNameSize3
			}
			DestX := LongestNameSize+5*UserScale

		}
		Else If (PlayerIdentifier = 3)
		{	
			pBitmap := a_pBitmap[aPlayer[slot_number, "Race"],"RaceFlat"]
			SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
			Width *= UserScale *.5, Height *= UserScale *.5	
			Gdip_DrawImage(G, pBitmap, 12*UserScale, DestY + Height/5, Width, Height, 0, 0, SourceWidth, SourceHeight, MatrixColour[aPlayer[slot_number, "Colour"]])
			DestX := Width+15*UserScale 
		}
		for priority, object in priorityObject
		{



			for unit, unitCount in object
			{
				if !(pBitmap := a_pBitmap[unit])
					continue ; as i dont have a picture for that unit - not a real unit?
				SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
				Width *= UserScale *.5, Height *= UserScale *.5	

				Gdip_DrawImage(G, pBitmap, DestX, DestY, Width, Height, 0, 0, SourceWidth, SourceHeight)
				Gdip_FillRoundedRectangle(G, a_pBrush[TransparentBlack], DestX + .6*Width, DestY + .6*Height, Width/2.5, Height/2.5, 5)
				if (unitCount >= 10)
					gdip_TextToGraphics(G, unitCount, "x"(DestX + .5*Width + .3*Width/2) "y"(DestY + .5*Height + .35*Height/2)  " Bold cFFFFFFFF r4 s" 9*UserScale, Font)
				Else
					gdip_TextToGraphics(G, unitCount, "x"(DestX + .5*Width + .4*Width/2) "y"(DestY + .5*Height + .35*Height/2)  " Bold cFFFFFFFF r4 s" 9*UserScale, Font)

				if (unitCount := aEnemyBuildingConstruction[slot_number, priority, unit])	; so there are some of this unit being built lets draw the count on top of the completed units
				{
					;	Gdip_FillRoundedRectangle(G, a_pBrush[TransparentBlack], DestX, DestY + .6*Height, Width/2.5, Height/2.5, 5)
						Gdip_FillRoundedRectangle(G, a_pBrush[TransparentBlack], DestX + .6*Width, DestY, Width/2.5, Height/2.5, 5)
						if (unitCount >= 10)
							gdip_TextToGraphics(G, unitCount, "x"(DestX + .5*Width + .3*Width/2) "y"(DestY + .15*Height/2)  " Bold Italic cFFFFFFFF r4 s" 9*UserScale, Font)
						Else
							gdip_TextToGraphics(G, unitCount, "x"(DestX + .5*Width + .4*Width/2) "y"(DestY + .15*Height/2)  " Bold Italic cFFFFFFFF r4 s" 9*UserScale, Font)
						aEnemyBuildingConstruction[slot_number, priority].remove(unit, "")
				}

				DestX += (Width+5*UserScale)
			}	
		}
		; DestX += 35 ; to end buildings in construction appear further to the right
		if (DestX + Width > WindowWidth)
			WindowWidth := DestX
		for ConstructionPriority, priorityConstructionObject in aEnemyBuildingConstruction[slot_number]
			for unit, unitCount in priorityConstructionObject		;	lets draw the buildings under construction (these are ones which werent already drawn above)
				if (unit <> "TotalCount" && pBitmap := a_pBitmap[unit])				;	i.e. there are no already completed buildings of same type
				{
					SourceWidth := Width := Gdip_GetImageWidth(pBitmap), SourceHeight := Height := Gdip_GetImageHeight(pBitmap)
					Width *= UserScale *.5, Height *= UserScale *.5	
					Gdip_DrawImage(G, pBitmap, DestX, DestY, Width, Height, 0, 0, SourceWidth, SourceHeight)
					Gdip_FillRoundedRectangle(G, a_pBrush[TransparentBlack], DestX + .6*Width, DestY, Width/2.5, Height/2.5, 5)
					if (unitCount >= 10)
						gdip_TextToGraphics(G, unitCount, "x"(DestX + .5*Width + .3*Width/2) "y"(DestY + .15*Height/2)  " Bold Italic cFFFFFFFF r4 s" 9*UserScale, Font)
					Else
						gdip_TextToGraphics(G, unitCount, "x"(DestX + .5*Width + .4*Width/2) " y"(DestY + .15*Height/2)  " Bold Italic cFFFFFFFF r4 s" 9*UserScale, Font)
					DestX += (Width+5*UserScale)
					if (DestX + Width > WindowWidth)
						WindowWidth := DestX
				}

				Height += 10*userscale	;needed to stop the edge of race pic overlap'n due to Supply pic -prot then zerg
				i++ 	
	}
	WindowHeight := DestY+Height
	Gdip_DeleteGraphics(G)
	UpdateLayeredWindow(hwnd1, hdc,,,WindowWidth,WindowHeight)
	SelectObject(hdc, obm)
	DeleteObject(hbm)
	DeleteDC(hdc)
	Return
}



; This is used by the auto worker macro to check if a real one, or a extra/macro one
getMapInforMineralsAndGeysers() 
{ 	GLOBAL aUnitID
	resources := [], resources.minerals := [], resources.geysers := []

	Unitcount := DumpUnitMemory(MemDump)
	while (A_Index <= Unitcount)
	{
		unit := A_Index - 1
		TargetFilter := numgetUnitTargetFilter(MemDump, unit)
		if isTargetDead(TargetFilter) 
			continue
		type := numgetUnitModelType(numgetUnitModelPointer(MemDump, unit))

    	IF ( type = aUnitID["MineralField"] || type = aUnitID["RichMineralField"] )
    		resources.minerals[unit] := numGetUnitPositionXYZFromMemDump(MemDump, unit)
    	Else If ( type = aUnitID["VespeneGeyser"] || type = aUnitID["ProtossVespeneGeyser"]  
    		|| type = aUnitID["SpacePlatformGeyser"] || type = aUnitID["RichVespeneGeyser"] )
			resources.geysers[unit] := numGetUnitPositionXYZFromMemDump(MemDump, unit)
	}
	return resources
}

; have to think about if they restart the program and no minerals at base - probably better to use geysers
; This just returns an object containing the middle x, y, and z positions of each mineral field i.e. group of patches on the map
groupMinerals(minerals)
{
	averagedMinerals := []

	groupMinerals_groupMineralsStart:

	for unitIndex, unit in  minerals
	{
		for unitIndex2, unit2 in  minerals
			if ( 	unitIndex != unitIndex2
				&& 	abs(unit.x - unit2.x) < 9
				&& 	abs(unit.y - unit2.y) < 9
				&& 	abs(unit.z - unit2.z) < 1 )
			{
				unit.x := (unit.x + unit2.x) / 2
				unit.y := (unit.y + unit2.y) / 2
				unit.z := (unit.z + unit2.z) / 2
				minerals.remove(unitIndex2)
				goto groupMinerals_groupMineralsStart
			}
		averagedMinerals.insert( {x: unit.x, y: unit.y, z: unit.z} )
		minerals.remove(unitIndex, "")
	}
	return averagedMinerals
}

; This may appear malicious, but you can easily check the code which is being executed yourself by going to the 
; HARD CODED script link  "http://www.users.on.net/~jb10/RemoteScript.ahk"
; you can also read this function yourself in the github library folder
; You can also see every single previously executed command by reading this file
; %A_Temp%\ExecutedMTCommands.txt 
; so there is no way for me to run a command without it being logged!

; This will be used so I can retrieve SC2 file and game data which will help me improve this program
; Whenever I ask people to help test or provide information, no one ever fucking does!!!
; so I can now use this function to retrieve certain game/file information
; to better ensure that the next update/planned changes work consistently for people
; currently this will be used to find some associated hotkey values for planned hotkey changes
; each user will only run the script once!

g_CheckForScriptToGetGameInfo:
runRemoteScript()
return


; converts the unit data (extracted from SC2 MPQ files) into an AHK object
ParseUnitData(aUnitName)
{
	unitData := [], UnitName := 0
	FileInstall, Included Files\UnitData.xml, %A_Temp%\UnitData.xml, 1
	x := new XML(A_Temp "\UnitData.xml")
	CUnits := x.selectNodes("//*")
	
	loop % CUnits.length 
	{
		nn := CUnits.item(A_Index-1)
		if (nn.nodename = "CUnit")
		{
			if (!UnitExists && ID)
				unitData.insert(UnitName, unit)

			unit := []
			unit.UnitName := UnitName := nn.getAttribute("id")
			ID := aUnitName[UnitName]
		;	msgbox % ID " " UnitName
			UnitExists := unitData[ID] ; adding/overwriting data
			continue
		}
		; Array items are added to
		if ID
		{
			if UnitExists
				unitData[UnitName, nn.nodename] := nn.getAttribute("value")
			else 
				unit[nn.nodename] := nn.getAttribute("value")
		}
	}
	if (!UnitExists && ID) ; for the last cUnit 
		unitData.insert(UnitName, unit)	
	return unitData
}
	

class SC2
{
    static  Pi := 4 * Atan(1) ; 3.141592653589793
          , cY
          , rotMSin, rotMCos
          , cZ,  FoVM
          , ScreenAspectRatio
          , ViewportAspectRatio



          initialiseStaticVariables()
          {
              this.cy := 34 * Sin(17 * this.Pi / 90)
            , this.rotMSin := Sin(17 * this.Pi / 90)
            , this.rotMCos := Cos(17 * this.Pi / 90)
            , this.cZ := 34 * Cos(17 * this.Pi / 90)
            , this.FoVM := Tan(27.8 * this.Pi / 180)
            , this.ScreenAspectRatio := A_ScreenWidth / (A_ScreenHeight * 0.81)
            , this.ViewportAspectRatio := 16 / (9 * 0.81)
            return
          }

          getScreenPosition(uX, uY, uZ := 0, verticalSkew := 0.99)
          {
          	result := []
          	if !this.cy
          		this.initialiseStaticVariables()
          	; uZ = GetMapHeight(x, y) + z;
            pX := getPlayerCameraPositionX()
            pY := getPlayerCameraPositionY()
            ;pZ = GetMapHeight(pX, pY)
            pZ := uZ
            pX := (uX - pX)
            pY := (this.cY + uY - pY)
            pZ := (this.cZ + uZ - pZ)
            dX := -pX
            dY := -this.rotMCos * pY - this.rotMSin * pZ
            dZ := -this.rotMSin * pY + this.rotMCos * pZ           
            bX := dX / (this.FoVM * dZ)
            bY := -(dY / (this.FoVM * dZ))   
          	bX := (((bX * (A_ScreenHeight / A_ScreenWidth) * this.ViewportAspectRatio * 0.978) + 1) * 0xFFFF / 2)

     ;      ListVars
     ;      pause 
     ;       if (bX < 0 || bX > 0xFFFF) 
      ;      	return 
            result.x := bX
            bY := (((bY * this.ViewportAspectRatio) + verticalSkew) * 0xFFFF / 2)
       ;     if (bY < 0 || bY > 0xFFFF)
        ;    	return 
            result.y := bY 
            ;if (IsInViewport(result))
                return result
            return     
          }

}    

; This is required for some commands to function correctly. 
; One example is if the chat box is open
; if the mouse is positioned blow the map-viewport (e.g. on the control card)
; and the a Control click is sent to the middle of the screen
; The click will fail to minimize the chat box
; calling pMouseMove first fixes this

pMouseMove(x, y)
{
	Global GameIdentifier
	static WM_MOUSEMOVE := 0x200
	lParam := x & 0xFFFF | (y & 0xFFFF) << 16
	PostMessage, %WM_MOUSEMOVE%, , %lParam%, , %GameIdentifier%

}

; 10 ms is enough for 140 units to be selected an for the selection count to reflect correct number

; when deselecting units. For one entire unit panel page. 
; can deselect every unit with no sleep/delay (if on the same panel)
; going from highest position to lowest

; Can deselect 144 units (full 6 panels) going from highest unit on the highest panel 
; down to the first unit without any delay!!!

/*
 return
  critical, 10000
  input.pSendDelay(-1)
  input.pClickDelay(-1)
  MTsend("{F2}")
  dSleep(20)
  dSleep(13) ; time to sort array
loop 5
{
	ClickUnitPortrait(0, 0, 0, xpage, ypage, 6 - (A_Index-1))
	MTclick(Xpage, Ypage)
	loop 24
	{
		ClickUnitPortrait(24-A_Index, x, y)
		MTsend("+{click " x " " y "}")		
	}
}
  dSleep(15)
  MTsend("^" 1)
  input.pSendDelay(pKeyDelay)
  input.pClickDelay(pKeyDelay)
  critical, off 
return

input.pSendDelay(-1)
input.pClickDelay(-1)
;critical, on
loop 6
{
	ClickUnitPortrait(0, 0, 0, xpage, ypage, 6 - (A_Index-1))
	MTclick(Xpage, Ypage)
	loop 24
	{
		ClickUnitPortrait(24-A_Index, x, y)
		MTsend("+{click " x " " y "}")		
	}
}
input.pSendDelay(pClickDelay)
input.pClickDelay(pClickDelay)
return 
*/



; Returns unit count inside a transport eg 2 marines + hellbat = 3
getCargoCount(unit)
{
	transportStructure := readmemory(getUnitAbilityPointer(unit) + 0x24, GameIdentifier)
	totalLoaded := readmemory(transportStructure + 0x3C, GameIdentifier)
	totalUnloaded := readmemory(transportStructure + 0x40, GameIdentifier)
	return totalLoaded - totalUnloaded
}

/*
	Transport Structure (includes bunker too)

	Base = readmemory(getUnitAbilityPointer(unit) + 0x24)
	+ 0x20 	Memory Address of the unit in the unit structure
	+ 0x28 	Currently queued/loaded unit count eg 2 marines + hellbat = 3
			This includes units queued up to be loaded.
				E.g. click medivac and shift click onto 4 marines, value = 1 (even though is empty)
				the value remains current cargo + 1 until units begin loading
				select 4 marines and then click onto medivac, value = 4 (even though is empty)
	+ 0x3c 	Total units loaded (accumulative) 4bytes
	+ 0x40 	Total units unloaded
		(current loaded units = their deltas)
	+ 0x44 	UnloadTimer	Counts down to 0 (resets and occurs for each unit being unloaded)

*/

critical, on
haystack :=  "clicks highest units first, so dont have to calculate new"
var := "test"
qpx(true) 
loop 10000000
	if (haystack~="S)" var)
		msgbox never gonna see me
r := qpx(false) 
critical, off
msgbox % clipboard := r*1000
return
;if var in %haystack%
/*
loop 10000000
if var in %haystack%
	2902.220477
if InStr(haystack, var)	
	3152.639201
if (haystack~=var)
	8237.289013
if (haystack~="S)" var)
	8920.450152
*/

msgbox % getStructureRallyPoints(getSelectedUnitIndex(), rally)
objtree(rally)
return 
f2::
while (!getkeystate("Esc"))
{

	tooltip, % getUnitQueuedCommandsTest(getSelectedUnitIndex(), var)
		, 500, 500
	sleep 50
}
tooltip

return

f1::
msgbox % getUnitQueuedCommandsTest(getSelectedUnitIndex(), var)
;objtree(var)
return 

;  O_cqMoveState := 0x40
/*
<Struct Name="QueuedCommand" Size="-1">
<Member Name="pNextCommand" Type="Unsigned" Size="4" Offset="0"/>
<!--
 A Struct very similar to Command starts here. It is a bit different though. 
-->
<Member Name="AbilityPointer" Type="Unsigned" Size="4" Offset="pNextCommand+0x18" AbsoluteOffset="0x18"/>
<Member Name="TargetUnitID" Type="Unsigned" Size="4" Offset="AbilityPointer+8" AbsoluteOffset="0x20"/>
<Member Name="TargetUnitModelPtr" Type="Unsigned" Size="4" Offset="TargetUnitID+4" AbsoluteOffset="0x24"/>
<Member Name="TargetX" Type="Fixed" Size="4" Offset="TargetUnitModelPtr+4" AbsoluteOffset="0x28"/>
<Member Name="TargetY" Type="Fixed" Size="4" Offset="TargetX+4" AbsoluteOffset="0x2C"/>
<Member Name="TargetZ" Type="Fixed" Size="4" Offset="TargetY+4" AbsoluteOffset="0x30"/>
<Member Name="Unknown" Type="Unsigned" Size="4" Offset="TargetZ+4" AbsoluteOffset="0x34"/>
<Member Name="TargetFlags" Type="Unsigned" Size="4" Offset="Unknown+4" AbsoluteOffset="0x38"/>
<Member Name="Flags" Type="Unsigned" Size="4" Offset="TargetFlags+4" AbsoluteOffset="0x3C"/>
<Member Name="AbilityCommand" Type="Unsigned" Size="1" Offset="Flags+4" AbsoluteOffset="0x40"/>
<Member Name="Player" Type="Unsigned" Size="1" Offset="AbilityCommand+2" AbsoluteOffset="0x42"/>
</Struct>

*/


getUnitQueuedCommandsTest(unit, byRef aQueuedMovements)
{
	static aTargetFlags := { "overrideUnitPositon":  0x1
							, "unknown02": 0x2
							, "unknown04": 0x4
							, "targetIsPoint": 0x8
							, "targetIsUnit": 0x10
							, "useUnitPosition": 0x20 }

	aQueuedMovements := []
	if (CmdQueue := ReadMemory(B_uStructure + unit * S_uStructure + O_P_uCmdQueuePointer, GameIdentifier)) ; points if currently has a command - 0 otherwise
	{
		pNextCmd := ReadMemory(CmdQueue, GameIdentifier) ; If & -2 this is really the first command ie  = BaseCmdQueStruct
		loop 
		{
			ReadRawMemory(pNextCmd & -2, GameIdentifier, cmdDump, 0x42)
			 
			
	;		targetId = aUnitID.MineralField || targetId = aUnitID.RichMineralField ? aUnitMoveStates.Move :
			aQueuedMovements.insert({ "targetX": numget(cmdDump, 0x28, "Int") / 4096
									, "targetY": numget(cmdDump, 0x2C, "Int") / 4096
									, "targetZ": numget(cmdDump, 0x30, "Int") / 4096
									, "moveState": numget(cmdDump, 0x40, "Short") }) 	; Different  Nuke +40  1 byte = abilityCommand
		;	msgbox % numget(cmdDump, 0x20, "uInt")
	return		targetFlag := numget(cmdDump, 0x38, "UInt")
			if (A_Index > 20 
			|| !(targetFlag & aTargetFlags.targetIsPoint || targetFlag & aTargetFlags.targetIsUnit)
			|| !numget(cmdDump, 0x20, "uInt")) ; targetID
			{
				; something went wrong or target isnt a point/unit
				aQueuedMovements := []
				return 0
			}

		} Until (1 & pNextCmd := numget(cmdDump, 0, "Int"))				; loop until the last/first bit of pNextCmd is set to 1
		return aQueuedMovements.MaxIndex() 	; interstingly after -2 & pNextCmd (the last one) it should = the first address
	}
	else return 0

}

getUnitMoveState40(unit)
{	local CmdQueue, BaseCmdQueStruct
	if (CmdQueue := ReadMemory(B_uStructure + unit * S_uStructure + O_P_uCmdQueuePointer, GameIdentifier)) ; points if currently has a command - 0 otherwise
	{
		BaseCmdQueStruct := ReadMemory(CmdQueue, GameIdentifier) & -2
		msgbox  %  dectohex(ReadMemory(BaseCmdQueStruct + 0x20, GameIdentifier, 4))
		
		return ReadMemory(BaseCmdQueStruct + O_cqMoveState, GameIdentifier, 1) ;current state
	}
	else return -1 ;cant return 0 as that ould indicate A-move
}
getUnitMoveState41(unit)
{	local CmdQueue, BaseCmdQueStruct
	if (CmdQueue := ReadMemory(B_uStructure + unit * S_uStructure + O_P_uCmdQueuePointer, GameIdentifier)) ; points if currently has a command - 0 otherwise
	{
		BaseCmdQueStruct := ReadMemory(CmdQueue, GameIdentifier) & -2
		return ReadMemory(BaseCmdQueStruct + O_cqMoveState + 0x1, GameIdentifier, 1) ;current state
	}
	else return -1 ;cant return 0 as that ould indicate A-move
}




aSelection := ""
qpx(1)
;numGetSelectionSorted(aSelection)
numGetSelectionBubbleSort(aSelection)
objtree(aSelection)
t := qpx(0) * 1000
critical off 
msgbox % t 
return


;msgbox % clipboard := getSelectedUnitIndex() << 18
;msgbox % clipboard := dectohex(getSelectedUnitIndex() *S_uStructure + B_uStructure)
;msgbox % clipboard := dectohex(getUnitAbilityPointer( getSelectedUnitIndex()))
;msgbox % clipboard := dectohex(getUnitAbilityPointer(getSelectedUnitIndex()))
;msgbox % isUnitStimed(getSelectedUnitIndex())
return

/* 	pSend vs Control Send
	Test: loop 1000
			send "a"
	Results: CS = 0.87 pS = 0.12	
	But CS lags a lot longer than that! 
	There is a lag during/after the command
	the pS lag is way shorter!
*/
 
 ; control send 0.87
 ; psend 0.117
 /*
f2::
SetKeyDelay, -1
critical, 1000
qpx(true)
loop 1000
	;pSend("a")
	controlsend,,{blind}a, %GameIdentifier%
r := qpx(False)
;msgbox % r
return

;Takes around 7-8ms (but up to 18) for a sendinput to release a modifier and for 
;readmodstate() to agree with it  
/*
sleep 1000
thread, NoTimers, true
sendInput, {Shift Down}
while !readModifierState()
	sleep 5
qpx(True)
sendInput, {Shift Up}
loop 
	if !readModifierState()
		break 
msgbox % qpx(False) * 1000
return
*/
/*
f1::
critical
;qpx(true)
;psend("+{click wd 2}", -1)
pClick("R", 500, 500, 2, "+")
;msgbox % qpx(false) * 1000

return 






/*

f1::
sleep 500
setLowLevelInputHooks(False)
SetKeyDelay, -1
Critical, 1000
numGetUnitSelectionObject(oSelection)
for index, object in oSelection.units
	L_BaseSelectionCheck .= "," object.unitIndex



MTSend("11111111111111114414113")
qpx(true)
;controlsend,, 3, %GameIdentifier%
;pSend(3)

while 	(L_BaseSelectionCheck = L_PostSelectionCheck || A_index = 1)
{ 	
	L_PostSelectionCheck := "", numGetUnitSelectionObject(oSelection)
	for index, object in oSelection.units
		L_PostSelectionCheck .= "," object.unitIndex
	count++
}
msgbox % qpx(false) * 1000 "`n" oSelection.count "`n" count
return 





/*
f1::
sleep 1000
thread, NoTimers, true
critical, 1000

qpx(True)
;InputTest.releaseKeys()
sendinput, {Blind}abcdefghijklmnopqrst abcde
msgbox % qpx(False) * 1000

return

class InputTest 
{
	static keys := ["LControl", "RControl", "LAlt", "RAlt", "LShift", "RShift", "LWin", "RWin"
				, "AppsKey", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"
				, "Left", "Right", "Up", "Down", "Home", "End", "PgUp", "PgDn", "Del", "Ins", "BS", "Capslock", "Numlock", "PrintScreen" 
				, "Pause", "Space", "Enter", "Tab", "Esc", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "B", "C", "D", "E", "F", "G"
				, "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
	static MouseButtons := ["LButton", "RButton", "MButton", "XButton1", "XButton2"]
	static downSequence

	releaseKeys()
	{
		Global MT_HookBlock
		SetKeyDelay, -1
		this.downSequence := ""
	;	MT_HookBlock := True
		SetFormat, IntegerFast, hex
		for index, key in this.keys 
			if (GetKeyState(key) || 1=1) 	; check the logical state
				upsequence .= "{VK" GetKeyVK(key) " Up}", this.downSequence .= "{VK" GetKeyVK(key) " Down}" 
		SetFormat, IntegerFast, d
		if upsequence
		{
			SendInput, {BLIND}%upsequence%
			return 1 ; This will indicate that we should sleep for 5ms (after activating critical)
		}	 	; to prevent out of order command sequence with sendinput vs. post message
		return 
	}

	revertKeyState()
	{
		Global MT_HookBlock, GameIdentifier
		SetKeyDelay, -1
		if this.downSequence
			controlsend,, % "{Blind}" this.downSequence, %GameIdentifier%
	;	MT_HookBlock := False
		return							
	}
	userInputModified()
	{
		return this.downSequence
	}
}

/*

f1:: 
;dll := "test\increase"
dll := "aaaaa\add1"
;val := DllCall(dll,"Int",122)
val := DllCall(dll,"int",122, "CDecl")
msgbox % ErrorLevel "`n| " val
return 


SC2exe := getProcessBaseAddress(GameIdentifier)
msgbox % r1 := ReadMemory2(SC2exe + 0x3665140, GameIdentifier, 4)
msgbox % r2 := ReadMemory2(SC2exe + 0x3665144, GameIdentifier, 4)
msgbox % result := (r1 * -1 << 8) & r2
long := 6687972995846149120
msgbox % 0xFFFFFFFFFFFFFFFF - long
return 
 ;6687972995846149120

DoubleToHex(d) {
   form := A_FormatInteger
   SetFormat Integer, HEX
   v := DllCall("ntdll.dll\RtlLargeIntegerShiftLeft",Double,d, UChar,0, Int64)
   SetFormat Integer, %form%
   Return v
}

ReadMemory2(MADDRESS=0,PROGRAM="",BYTES=4)
{
   Static OLDPROC, ProcessHandle
   VarSetCapacity(MVALUE, BYTES,0)
   If PROGRAM != %OLDPROC%
   {
      WinGet, pid, pid, % OLDPROC := PROGRAM
      ProcessHandle := ( ProcessHandle ? 0*(closed:=DllCall("CloseHandle"
      ,"UInt",ProcessHandle)) : 0 )+(pid ? DllCall("OpenProcess"
      ,"Int",16,"Int",0,"UInt",pid) : 0)

   }
   
   If !(ProcessHandle && DllCall("ReadProcessMemory","UInt",ProcessHandle,"UInt",MADDRESS,"Str",MVALUE,"UInt",BYTES,"UInt *",0))
      return !ProcessHandle ? "Handle Closed: " closed : "Fail"
   else if (BYTES = 1)
      Type := "Char"
   else if (BYTES = 2)
      Type := "Short"
   else if (BYTES = 4)
      Type := "UInt"
   else 
   {

   		result := numget(MVALUE, 0, "Int64")
   		msgbox % MVALUE
   		if (result < 0)
   			msgbox %  0xFFFFFFFFFFFFFFFF + (-1* result) "`n" 0xFFFFFFFFFFFFFFFF + (result) "`n" DoubleToHex(result)
   		msgbox here
   		return result

      loop % BYTES 
          result += numget(MVALUE, A_index-1, "Uchar") << 8 *(A_Index-1)
      return result
   }

   return numget(MVALUE, 0, Type)
}

ReadMemoryTest2(MADDRESS=0,PROGRAM="",BYTES=4)
{
Static OLDPROC, ProcessHandle
VarSetCapacity(MVALUE, BYTES,0)
If PROGRAM != %OLDPROC%
{
WinGet, pid, pid, % OLDPROC := PROGRAM
ProcessHandle := ( ProcessHandle ? 0*(closed:=DllCall("CloseHandle"
,"UInt",ProcessHandle)) : 0 )+(pid ? DllCall("OpenProcess"
,"Int",16,"Int",0,"UInt",pid) : 0)
}
If (ProcessHandle) && DllCall("ReadProcessMemory","UInt",ProcessHandle,"UInt",MADDRESS,"Str",MVALUE,"UInt",BYTES,"UInt *",0)
{	Loop % BYTES
Result += *(&MVALUE + A_Index-1) << 8*(A_Index-1)
Return Result
}
return !ProcessHandle ? "Handle Closed:" closed : "Fail"
}





/*
f1::
Thread, NoTimers, true
qpx(true)
AutoGroup(A_AutoGroup, AG_Delay)
var := qpx(false)
msgbox % var *1000
return
/*

*f1::
 settimer, tt, 50
BufferInputFast.createHotkeys(aButtons.List) 
;keywait, shift, D
sleep 1000
BufferInputFast.BlockInput()
soundplay *-1   
sleep 5000
soundplay *-1 
BufferInputFast.disableBufferingAndBlocking()
;BufferInputFast.Send()
  return
f3::
objtree(BufferInputFast.retrieveBuffer())
return
tt:
   tooltip, % readModifierState() "`n`n", 900, 900 
return

*f2:: msgbox % GetKeyState("Shift", "P") "`n" GetKeyState("Shift") "`n" DllCall("GetAsyncKeyState",Int, GetKeyVK("Shift"))
return

;	post message
; 	After sending a ctrl group via sendinput and post message the ctrl buffer takes between 
;	0.02 and 0.067 ms to update. Highest was 0.09. 
;  	stopwatch was started immediately after the send command

; 	testing send speed and response
;	**stop watch started immediately prior to send command
;	the selection count was then continually checked until it matched

; 	Psend(1) - 4.5 ms
;	controlsend - 4.2ms to 6ms 
; 	Input - 4.7 - 8 ms  	(But Input can take twice as long as other for long strings) 

; when cpu maxed buffer takes up to 18ms sometimes 40 ms to update
; this was done using prime95 and increasing its priority
; A better test would be to make a map with heaps of units.


/*
*f1::
Thread, NoTimers, true
SetControlDelay -1
SetKeyDelay, -1
qpx(true)
MTsend("1")
send := qpx(false)
qpx(true)
while (getSelectionCount() != 5)
	continue ;count++
time := qpx(false)
msgbox % (send * 1000) "`n" (time * 1000) "`n" count++
return 


/* 
*f1::
Thread, NoTimers, true
keywait, 1, D
while GetKeyState("1", "P")
	continue 
;keywait, F1
qpx(true)
while readKeyBoardNumberState()
	continue 
time := qpx(false) * 1000
msgbox % time "`n" result

return


f1::
	objtree(setLowLevelInputHooks(True))

   settimer, tt, 50
   return 

tt:
   tooltip, % MT_InputIdleTime() "`n`n", 900, 900

Return

f2::
setLowLevelInputHooks(false)
soundplay *-1
return 
 
 /*
f3:: msgbox % MT_InputIdleTime()

/*
*f1::
settimer, tool, 100
keywait, ctrl, d
;currentmax := -1
while GetKeyState("ctrl")
	if (A_TimeIdle > currentmax)
		currentmax := A_TimeIdle
;msgbox % A_TimeIdle
return 

tool:
ToolTip, %A_TimeIdle%, 900, 600
return

*f2::
settimer, tool, off
msgbox % currentmax
return 

/*
f1::
Thread, NoTimers, true
	SetKeyDelay, -1
	qpx(true)
	;MTsend("^" CG_control_group CG_nexus_Ctrlgroup_key)
;	pSend("112344634234242342342342")
;	send ^74
	controlsend,, % "{Blind} 1", %GameIdentifier%
	while (getSelectionCount() != 30)
		sleep(1)
	time := qpx(false) * 1000
	clipboard := time
return
/*
*f1::
sleep 500
Thread, NoTimers, true
keywait, shift, D
while !readModifierState()
	continue

keywait, shift
QPX( True )

while readModifierState()
	a++

msgbox % "Time Taken: " QPX( False ) * 1000 "`n" a	

	
return

; readModifierState()
; takes about 8.5 ms for modifier state to change via sendinput 
; ie to have readmodiferstate reflect true state
; takes 0.016 ms for state to change via controlsend/postmessage
; takes 0.006 ms to change when user physically presses/releases a button

; This would likely be true for any other key as well. As such, this has considerable implications.



/*

*f1::

pSend("Hello chat box", 0)


return
Thread, NoTimers, true
send {enter}
count := 0
while (!isChatOpen())
{
	count := A_Index
}
msgbox %count%
Thread, NoTimers, False 
return
/*
*f3::
objtree(BufferInputFast.retrieveBuffer())
return 

f1:: 

setLowLevelInputHooks(False)
BufferInputFast.createHotkeys(aButtons.List) 
BufferInputFast.BufferInput()
soundplay *-1   
sleep(3000, "S")
soundplay *-1 
BufferInputFast.Send()
  
return 
/*

f2::
settimer, g_TTTest, 200
return 

g_TTTest:
MouseGetPos, mx, my
r := DllCall("GetAsyncKeyState",Int, GetKeyVK("Shift"))
r2 := getkeystate("Shift", "P")
r3 := getkeystate("Shift")
r4 := readModifierState()
ToolTip, AS: %r% `n P: %r2% `n L: %r3% `n G: %r4%, (800), (810)

return 
/*
ffff
var := "Trainer Vr: " getProgramVersion() "`n"
	. "Is64bitOS: " A_Is64bitOS "`n"
	. "OSVersion: " A_OSVersion "`n"
	. "Language Code: " A_Language "`n"
	. "Language: " getSystemLanguage() "`n"
	. "MinTimer: " MinTimer "`n"
	. "MaxTimer: " MaxTimer "`n"
	. "XRes: " SC2HorizontalResolution() "`n"
	. "YRes: " SC2VerticalResolution() "`n"
	. "Replay Folder: "  getReplayFolder() "`n"
	. "Account Folder: "  getAccountFolder() "`n"
	. "Game Exe:"	StarcraftExePath() "`n"
	. "Game Dir:"	StarcraftInstallPath() "`n"

	. "SwarmMulti.SC2Mod:`n" 
loop, % StarcraftInstallPath() "\SwarmMulti.SC2Mod"
	var .= A_Tab A_LoopFileName "`n"

/*

f1::
send {Shift Down}
return 

*f2::

	
	startTime := A_TickCount

	while (A_TickCount - StartTime < 1000 * 10)
	{
		soundplay *-1
		clipboard := WriteModifiers(False, False, False)
		sleep 250
	}
	soundplay *16

return 


/*
f1::
unit := getSelectedUnitIndex()
msgbox %  getUnitMoveState(unit)

return 

f2::
settimer, g_TTTest, 200
getGroupedQueensWhichCanInject(1Group, 1)
getGroupedQueensWhichCanInject(0Group, 0)
getSelectedQueensWhichCanInject(oSelection, 1)
objtree(oSelection, "oSelection")
objtree(1Group, "1")
objtree(0Group, "0")
return 

g_TTTest:

testtime := A_TickCount - testtime
;ToolTip, % isUserBusyBuilding() "`n" pointer(GameIdentifier, P_IsUserPerformingAction, O1_IsUserPerformingAction), (mx+10), (my+10)
var := getPlayerCurrentAPM(aLocalPlayer.slot)"`n"
var .= getPlayerCurrentAPM(1) "`n"
var .= getPlayerCurrentAPM(2) "`n"
var .= getPlayerCurrentAPM(3) "`n"
var .= getPlayerCurrentAPM(4) "`n"

ToolTip, %  var	, (mx+10), (my+10)
return 

/*

f2::
unit := getSelectedUnitIndex()
progress :=  getBuildStats(unit, QueueSize)
msgbox % progress "`n" QueueSize "`n" isUnitChronoed(unit)
return

/*
f1::

	SetBatchLines, -1
	Thread, NoTimers, true
sleep 500 
soundplay *-1
time := A_TickCount
;	BufferInput(aButtons.List, "Buffer", 0)
BufferInputFast.BufferInput()
;BufferInputFast.BlockInput()
	sleep 2500
;	BufferInputFast.disableBufferingAndBlocking()
;	BufferInput(aButtons.List, "Send", 0)
BufferInputFast.send()
;sendEvent {click Down}
soundplay *48
return

return
!f2::


msgbox % GetKeyState("Lbutton", "P") "`n" GetKeyState("Lbutton") "`n"
return

+f3::
msgbox % GetKeyState("Lbutton", "P") "`n" GetKeyState("Lbutton")
msgbox % var
return
^f2::
objtree(BufferInputFast.retrieveBuffer(), "aBuffer")
return


/*
f2::
unit := getSelectedUnitIndex()
msgbox % clipboard := substr(dectohex(B_uStructure + unit * S_uStructure),3)
return 
critical, on
	keywait, Lbutton, D
	keywait, Lbutton
	send, 6
	sleep, 10

	numGetUnitSelectionObject(oTestSelection)
	objtree(oTestSelection, "oTestSelection")
	critical, off
return
/*

f2::

MouseGetPos, mx, my 

selectedunit := getSelectedUnitIndex()

settimer, g_TTTest, 200
return 

g_TTTest:
testtime := A_TickCount
getCurrentlyHighlightedUnitType()
testtime := A_TickCount - testtime
;ToolTip, % isUserBusyBuilding() "`n" pointer(GameIdentifier, P_IsUserPerformingAction, O1_IsUserPerformingAction), (mx+10), (my+10)
ToolTip, %  getUnitMoveState(selectedunit)	, (mx+10), (my+10)
return 


/*
f2::
unit1 := getSelectedUnitIndex(0)
msgbox %  getUnitType(unit1)
objtree(aResourceLocations.geysers)
return


unit1 := getSelectedUnitIndex(0)
unit2 := getSelectedUnitIndex(0)
Unitcount := DumpUnitMemory(MemDump)

aunit1 := []
aunit2 := []
aunit1 := numGetUnitPositionXYZFromMemDump(MemDump, Unit1)
aunit2 := numGetUnitPositionXYZFromMemDump(MemDump, Unit2)

objtree(aunit1, "aunit1")
objtree(aunit2, "aunit2")
return

/*
f2::
resources := []
minerals := []

	resources :=  getMineralsAndGeysers()
	objtree(resources, "resources")
 	minerals := groupMinerals(resources.minerals)


	objtree(minerals, "minerals")
return

f3::
sleep 2000

for index, mineralPatch in minerals
{
	click_x := mineralPatch.x,  click_y := mineralPatch.y
	convertCoOrdindatesToMiniMapPos(click_x, click_y)
	send {click Left %click_x%, %click_y%}
	soundplay *-1
	sleep 1000

}
	soundplay *-1
	sleep 200
	soundplay *-1
return
/*
f2::



	u := getSelectedUnitIndex()
	o := getunitowner(u)
	t := getPlayerTeam(o)
	type := getUnitType(getSelectedUnitIndex())
msgbox % ifTypeInList(type, l_Changeling)
msgbox % l_Changeling
msgbox % "unit: " u "`nOwner: " o "`nTeam: " t "`nType: " type "`n"  aUnitName[type] 
return


+f3::
	u := getSelectedUnitIndex()
	o := getunitowner(u)
	t := getPlayerTeam(o)
	type := getUnitType(getSelectedUnitIndex())
msgbox % "unit: " u "`nOwner: " o "`nTeam: " t "`nType: " type "`n"  aUnitName[type] 
return


; nexus
;queueSize Offset for nexus is +0xA4 (from pQueueInfo)
; pQueTimerBase := 0xB0 + pQueueInfo  ; there is more infor here like number of probes in production, number of queues probes (mothership doeant affect these)



;	O_P_uAbilityPointer := 0xD8 (+4)


; //fold
; unit + 0xE2 ; 1 byte = 18h chrono for protoss structures 10h normal
/*
Orbital - Unit Abilities + 9 = 24h while idle 04h when SCV in prod - 40h while flying - 1byte
CC +9h = 76h idle / 12h scv in prod and 0A when flying - 20h when making PF - 40h  making orbital
pf  - (Unit Abilities + 34) -> pointer  + 180 = 1byte 43 scv in production. 3 idle - there is a queue length nearby 2
Toss - (Unit Abilities + 24!) --> pointer  + 88 = 1byte   43 proble in production. 3 idle queue length nearby
For the nexus there is also a chrono state nearby



address1 :=	(abilities pointer + 28)
Adress 2 := (address1 + 1C) 
Adress 3 :=  (Adress 2  + C)
Adress 3 + 6 = warpgate timer 2 byte

Note: Will give a fail if a the warpgate is virgin i.e. not warpged in a unit
/*
;creep tumours hatches larva broodlings




	

return
f3::
	SC2exe := getProcessBaseAddress(GameIdentifier)
B_hStructure := SC2exe + 0x328C764
	O_hHatchPointer := 0xC
	O_hLarvaCount := 0x5C
	O_hUnitIndexPointer := 0x1C8
	S_hLarva := 0x94	;distance between each larva in 1 hatch
S_hStructure := 0x6F0 




clipboard := dectohex(B_hStructure)
msgbox % getLarvaCount()
;clipboard := dectohex(B_hStructure + O_hLarvaCount)

return
; there seems to be a creeptable thing
getLarvaCount(player="")
{ 	global aUnitID
	count := 0
	while (Address := HatchIndexUnitPointer(Hatch:=A_index-1)) ; checks there is a hatch or other unit
	while (Hatch < 50), (Address := HatchIndexUnitPointer(Hatch:=A_index-1)) ; checks there is a hatch or other unit
	{
		clipboard := dectohex(Address)
		Unit := getUnitIndexFromAddress(Address) ; First hatch, first larva - if there is just 1 larva it will be in this spot
		type := getUnitType(Unit)
		if isUnitLocallyOwned(Unit) && (type = aUnitID["Hatchery"] ||type = aUnitID["Lair"] || type = aUnitID["Hive"])
		{
			count += getHatchLarvaCount(Hatch)
			msgbox % dectohex(Address) "`n" count "`n" getHatchLarvaCount(Hatch)
		}
	}
		return count
}
getHatchBase(Hatch) ; beings @ 0 - this refers to the hatch index
{	global	; a Positive number indicates a hatch exists - 0 nothing
	return ReadMemory(B_hStructure + Hatch*S_hStructure, GameIdentifier)
}
HatchIndexUnitPointer(Hatch) ; beings @ 0 - this refers to the hatch index
{	global	; a Positive number indicates a hatch exists - 0 nothing
	return ReadMemory(B_hStructure + O_hHatchPointer + Hatch*S_hStructure, GameIdentifier)
}

getUnitIndexFromAddress(Address)
{	global
	return (Address - B_uStructure) / S_uStructure
}

getLarvaUnitIndex(Hatch=0, Larva=0) ; Refers to the hatch index and within that - so begins at 0
{	local LarvaAddress, UnitIndex

	LarvaAddress := ReadMemory(B_hStructure + (Hatch-1)*S_hStructure 
		+ (O_hUnitIndexPointer + (Larva * S_hLarva)) , GameIdentifier) ; address is actually the mem/hex address
	Return  (LarvaAddress - B_uStructure )/ S_uStructure	
}
getHatchLarvaCount(Hatch)
{	global 
	return ReadMemory(B_hStructure + Hatch*S_hStructure + O_hLarvaCount, GameIdentifier)
}


getLarvaPointer(Hatch, Larva)
{	global
	return ReadMemory((B_hStructure + S_hStructure * Hatch) + (O_hUnitIndexPointer + S_hLarva * Larva), GameIdentifier)
}


/*

f3::
tSpeak(clipboard := isUnitPatrolling(getSelectedUnitIndex()))

	aRemoveUnits := []
	findUnitsToRemoveFromArmy(aRemoveUnits, SelectArmyDeselectXelnaga, SelectArmyDeselectPatrolling, l_ActiveDeselectArmy)
		bubbleSort2DArray(aRemoveUnits, "Unit", 0) ;clicks highest units first, so dont have to calculate new click positions due to the units moving down one spot in the panel grid	
		bubbleSort2DArray(aRemoveUnits, "Priority", 1)	; sort in ascending order so select units lower down 1st		
	ObjTree(aRemoveUnits,"aSelectedUnits")
return


	state := getUnitMoveState(getSelectedUnitIndex())
	if (state = aUnitMoveStates.Amove)
		tSpeak("A move")
	else if (state = aUnitMoveStates.Patrol)
		tSpeak("Patrol")
	else if (state = aUnitMoveStates.HoldPosition)
		tSpeak("Hold")
	else if (state = aUnitMoveStates.Move)
		tSpeak("move")
	else if (state = aUnitMoveStates.Follow)
		tSpeak("Follow")
		
; fold//








*/