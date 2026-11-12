on run
	showControls()
end run

on reopen
	showControls()
end reopen

on showControls()
	set actions to {"Start ComfyUI", "Stop ComfyUI"}
	set selectedAction to choose from list actions with title "ComfyUI Agentic" with prompt "Choose what to do with the local ComfyUI server." default items {"Start ComfyUI"} OK button name "Run" cancel button name "Cancel"
	if selectedAction is false then return

	if item 1 of selectedAction is "Start ComfyUI" then
		set action to "start"
	else
		set action to "stop"
	end if

	try
		set resultText to runLauncher(action)
		display dialog resultText buttons {"OK"} default button 1 with title "ComfyUI Agentic"
	on error errorMessage number errorNumber
		display dialog errorMessage buttons {"OK"} default button 1 with title "ComfyUI Agentic" with icon stop
	end try
end showControls

on runLauncher(action)
	set infoPath to POSIX path of (path to me) & "Contents/Info.plist"
	set companionRoot to do shell script "/usr/libexec/PlistBuddy -c 'Print :ComfyUIAgenticRoot' " & quoted form of infoPath
	set launcherPath to companionRoot & "/run_comfyui_cdp.sh"
	return do shell script quoted form of launcherPath & " " & action
end runLauncher

on quit
	try
		runLauncher("stop")
	on error errorMessage number errorNumber
		display dialog errorMessage buttons {"OK"} default button 1 with title "ComfyUI Agentic" with icon stop
		return
	end try
	continue quit
end quit
