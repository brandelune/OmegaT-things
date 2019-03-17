use AppleScript version "2.4" -- Yosemite (10.10) or later
use scripting additions
use Terminal : script "JC_Terminal"

# set default OmegaT parameters
set user_preferences_folder to ((POSIX path of (path to home folder)) & "Library/Preferences/")
set omegat_configuration_folder to user_preferences_folder & "OmegaT/"
set projects_configuration_folder to user_preferences_folder & "OmegaT configurations/"
set omegat_launch_preference_file to omegat_configuration_folder & "omegat_launch.plist"

# create the launch preference file if needed
tell application "System Events"
	try # does the omegat launch preference file exist ?
		# TODO check that the file is in the correct format
		set omegat_launch_preferences to contents of property list file omegat_launch_preference_file
		set omegat_path to value of item 1 of (property list items of omegat_launch_preferences whose name is "Path")
		# TODO check the current OmegaT version and the one available for download
		# if different, ask whether to update or not
		# set omegat_type to value of item 1 of (property list items of omegat_launch_preferences whose name is "Type")
		# set omegat_version to value of item 1 of (property list items of omegat_launch_preferences whose name is "Version")
	on error # create it
		set the launch_preferences to make new property list item with properties {kind:record}
		set omegat_launch_preference_file to make new property list file with properties {contents:launch_preferences, name:omegat_launch_preference_file}
		tell property list items of omegat_launch_preference_file
			set omegat_location to (choose file with prompt "Location of OmegaT:" default location (path to applications folder))
			set omegat_path to (POSIX path of (omegat_location)) as string
			set omegat_type to (name extension of omegat_location) as string
			set omegat_version to (short version of omegat_location) as string
			make new property list item at its end with properties {kind:record, name:"Path", value:omegat_path}
			make new property list item at its end with properties {kind:record, name:"Type", value:omegat_type}
			make new property list item at its end with properties {kind:record, name:"Version", value:omegat_version}
		end tell
	end try
end tell

# set java launch parameters
# TODO how to use parameters when dealing with OmegaT.app ?
set omegat_command to "java -Xdock:name=OmegaT -jar " & quoted form of omegat_path & " "
set is_local_parameter to " --no-team "

# set project parameters
set project_folder to ""
set project_path to ""
set config_parameter to ""
set is_project to false
set is_team_project to false
set is_IP_connected to false

tell application "Finder"
	try # is the folder an OmegaT project ?
		if document file "omegat.project" of item 1 of (get selection) exists then
			set project_folder to item 1 of (selection as alias list)
			set project_name to name of project_folder
			set project_path to quoted form of POSIX path of project_folder
			set is_project to true
			try # does the project have a dedicated configuration folder in ~/Library/Preferences/OmegaT configurations/ ?
				# when the configuration folder does not exist, this does not result into an error.
				# plus OmegaT automatically creates a configuration folder where the command points if it does not exist.
				# so we end up with a "default" configuration, instead of having the "user default" as set in /preferences/OmegaT...
				set this_project_configuration_folder to ((projects_configuration_folder & project_name) as POSIX file) as alias
				# if non existant, use dialog to ask "create settings with user defaults / OmegaT defaults ?"
				set config_parameter to " --config-dir=" & quoted form of POSIX path of this_project_configuration_folder
			end try
			try # is the project a 4.1 team project ?
				# TODO team projects for 3.6 and 4.1
				do shell script "ls " & (quoted form of (POSIX path of item 1 of (selection as alias list)) & ".repositories")
				set is_team_project to true
				try # is the machine online ?
					# TODO the project could be a local team project, so need to check the connection in other ways
					do shell script ("ping -c 2 " & "www.omegat.org")
					set is_IP_connected to true
				end try
			end try
		end if
	end try
end tell

#return

try
	if is_project = false then # this is not an OmegaT project: either create a project at selection or open OmegaT empty
		set user_choice to button returned of (display dialog "Launch OmegaT / Create project?" buttons {"Launch OmegaT", "Create Project", "Cancel"} default button "Create Project" cancel button "Cancel")
	else if (is_team_project = true) and (is_IP_connected = true) then # this is a team project and the machine is connected:  open team project or open locally
		set user_choice to button returned of (display dialog "Open team project / Open project locally?" buttons {"Open Team Project", "Open Project Locally", "Cancel"} default button "Open Project Locally" cancel button "Cancel")
	else # this is an OmegaT project, either team and not connected or local: open project or create project
		set user_choice to button returned of (display dialog "Open selected project / Create project?" buttons {"Open Project", "Create Project", "Cancel"} default button "Open Project" cancel button "Cancel")
	end if
on error number -128
	set usercanceled to true
	return
end try
# user_choice is of {"Launch OmegaT", "Open Team Project", "Open Project Locally", "Open Project", "Create Project", "Cancel"}

try
	if user_choice is "Launch OmegaT" then
		# "Launch OmegaT"
		# launch OmegaT with default parameters, without specifying a project
		set command_parameters to ""
	else if user_choice is "Open Team Project" then
		# "Open Team Project"
		# launch OmegaT with project parameters, connected, on the team project
		set command_parameters to project_path & config_parameter
	else if user_choice is "Open Project Locally" then
		# "Open Project Locally"
		# launch OmegaT with project parameters, not connected, on the team project
		set command_parameters to project_path & is_local_parameter & config_parameter
	else if user_choice is "Open Project" then
		# "Open Project"
		# launch OmegaT with project parameters, not connected, on the local project
		set command_parameters to project_path & is_local_parameter & config_parameter
	else if user_choice is "Create Project" then
		# "Create Project"
		# TODO use code from project.app to create a working OmegaT project with required parameters
		my CreateProject()
		return
	end if
	set myCommand to omegat_command & command_parameters
on error
	display alert "Somethine went wrong..."
	return
end try

my launchOmegaT(myCommand)

on launchOmegaT(myCommand)
	tell application "Terminal" to activate
	tell application "System Events" to tell application process "Terminal"
		set frontmost to true
		delay 0.1
		keystroke "t" using {command down}
	end tell
	
	tell application "Terminal"'s front window
		delay 0.1
		do script myCommand in its last tab
		activate
	end tell
	
	return
end launchOmegaT

on CreateProject()
	display alert "Create a project"
	# TODO use code from project.app to create a working OmegaT project with required parameters
	return
end CreateProject
