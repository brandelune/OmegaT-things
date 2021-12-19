use AppleScript version "2.4" -- Yosemite (10.10) or later
use scripting additions

# This version: Sunday, December 19, 2021
# → modify the Java paths
# This version: Wednesday, September 29, 2021
# → add more references to existing variables
# This version: Saturday, September 25, 2021
# → add code for running on Finder aliases
# This version: Sunday, September 19, 2021
# → simplify the settings

## Default OmegaT parameters
# identify the various paths to the existing JREs
# TODO some JREs may not be installed. Maybe a script to check the available options would be better
property java_path_temurin_17 : "/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home/bin/java"
property java_path_temurin_11 : "/Library/Java/JavaVirtualMachines/temurin-11.jdk/Contents/Home/bin/java"

# set the JRE that will be used
set java_path to java_path_temurin_11
try #to see if the selected JRE exists
	alias POSIX file java_path
on error # if it does not exist, use the default path assuming that Java is installed...
	display alert "The specified Java version is not installed, using the default /usr/bin/java instead."
	set java_path to "/usr/bin/java"
end try

return

## identify the OmegaT preference folders
set user_preferences_folder to ((POSIX path of (path to home folder)) & "Library/Preferences/")
set omegat_configuration_folder to user_preferences_folder & "OmegaT/"

# the two items below are specific to this script, they may well not exist.
# that "OmegaT configuration" folder will be the place where this script creates project specific configuration folders.
# the script checks whether a configuration folder with the same name as the project exists and uses it for launching the project.
# if the folder does not exist, OmegaT asks (later) whether the project should use one or not
set projects_configuration_folder to user_preferences_folder & "OmegaT configurations/"
try #to see if the project specific configuration folder exists
	alias POSIX file projects_configuration_folder
on error # if it does not exist, create it
	do shell script "mkdir " & quoted form of projects_configuration_folder
end try

# the launch preference file mainly contains the path to the prefered OmegaT.jar file
# 
# there are probably other ways to use this file
set omegat_launch_preference_file to omegat_configuration_folder & "omegat_launch.plist"
try #to see if the omegat launch preferences file exists
	alias POSIX file omegat_launch_preference_file
	tell application "System Events"
		# parse the contents of the launch file to find the relevant information
		# TODO check the current OmegaT version and the one available for download
		# TODO if different, ask whether to update or not
		set omegat_launch_preferences to contents of property list file omegat_launch_preference_file
		set omegat_path to value of item 1 of (property list items of omegat_launch_preferences whose name is "Path")
		set omegat_type to value of item 1 of (property list items of omegat_launch_preferences whose name is "Type")
		set omegat_version to value of item 1 of (property list items of omegat_launch_preferences whose name is "Version")
	end tell
on error # if it does not exist, create it
	display dialog "If you use the OmegaT.app application, select it and the script will automatically find the OmegaT.jar file inside the application." with title "This script requires OmegaT.jar to run." buttons {"OK"} default button {"OK"} with icon 1
	set omegat_location to (choose file with prompt "Location of OmegaT.jar:" default location (path to applications folder))
	# this checks that the selected application is OmegaT.something
	# and adds the necessary path if OmegaT.app was selected
	tell application "System Events"
		if items 1 through 6 of ((name of omegat_location) as text) as string is not "OmegaT" then
			display dialog "Select either OmegaT.app or OmegaT.jar. Run the script again and select the required file." with title "This script requires OmegaT.jar to run." buttons {"OK"} default button {"OK"} with icon 1
			return
		end if
		if (name extension of omegat_location) is "app" then
			set omegat_path to (POSIX path of (omegat_location) & "/Contents/Java/OmegaT.jar") as string
		else
			set omegat_path to (POSIX path of (omegat_location)) as string
		end if
	end tell
	
	tell application "System Events"
		set the launch_preferences to make new property list item with properties {kind:record}
		set omegat_launch_preference_file to make new property list file with properties {contents:launch_preferences, name:omegat_launch_preference_file}
		set omegat_type to (name extension of omegat_location)
		set omegat_version to (short version of omegat_location)
		if omegat_version = "" then
			# this expects to have the version number displayed on the last line of the --help output
			set omegat_version to do shell script "java -jar " & omegat_path & " -h | tail -1"
		end if
		tell property list items of omegat_launch_preference_file
			make new property list item at its end with properties {kind:record, name:"Path", value:omegat_path}
			make new property list item at its end with properties {kind:record, name:"Type", value:omegat_type}
			make new property list item at its end with properties {kind:record, name:"Version", value:omegat_version}
		end tell
	end tell
end try


# set java launch parameters
# TODO who to use parameters when dealing with OmegaT.app ?
set omegat_command to java_path & " -Xdock:name=OmegaT -Duser.language=fr -jar " & quoted form of omegat_path & " "
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
		# the script only uses the first selected item
		# if that item is a Finder alias, it looks for the original item
		if (class of item 1 of (get selection) as text) is in {"alias file", "«class alia»"} then
			set mySelection to original item of item 1 of (get selection)
		else
			set mySelection to item 1 of (get selection)
		end if
		if document file "omegat.project" of mySelection exists then #it is an OmegaT project
			set project_folder to mySelection
			set project_name to name of project_folder
			set project_path to quoted form of POSIX path of (project_folder as alias)
			set is_project to true
			try # does the project have a dedicated configuration folder in ~/Library/Preferences/OmegaT configurations/ ?
				# when the configuration folder does not exist, this does not result into an error.
				# plus OmegaT automatically creates a configuration folder where the command points if it does not exist.
				# so we end up with a "default" configuration, instead of having the "user default" as set in /preferences/OmegaT...
				set this_project_configuration_folder to ((projects_configuration_folder & project_name) as POSIX file) as alias
				
				# TODO if the project configuration folder does not exist, ask whether it is necessary
			on error
				try
					set project_configuration to button returned of (display dialog "You can chose project specific settings, user specific settings, or the OmegaT defaults." with title "Select the settings you want to use with this project" buttons {"Project", "User", "Default"} default button "Project" cancel button "User")
				on error #in case "User" cancels the setting
					set this_project_configuration_folder to (user_preferences_folder & "OmegaT/" as POSIX file)
				end try
				
				if project_configuration is "Project" then
					tell application "Finder"
						set this_project_configuration_folder to POSIX path of ((make new folder at (POSIX file projects_configuration_folder as alias) with properties {name:project_name}) as alias)
						duplicate items of (POSIX file (user_preferences_folder & "OmegaT/") as alias) to (POSIX file this_project_configuration_folder)
						delete items of (POSIX file ((this_project_configuration_folder) & "logs") as alias)
						delete items of (POSIX file ((this_project_configuration_folder) & "script") as alias)
						delete items of (POSIX file ((this_project_configuration_folder) & "spelling") as alias)
						delete (POSIX file ((this_project_configuration_folder) & "segmentation.conf") as alias)
						delete (POSIX file ((this_project_configuration_folder) & "repositories.properties") as alias)
					end tell
				else if project_configuration is "Default" then
					set this_project_configuration_folder to (user_preferences_folder & "OmegaT configurations/Factory settings/" as POSIX file)
					delete items of (this_project_configuration_folder as alias)
				end if
				
			end try
			set config_parameter to " --config-dir=" & quoted form of POSIX path of this_project_configuration_folder
			try # is the project a 4.1 team project ?
				# TODO team projects for 3.6 and 4.1
				do shell script "ls " & project_path & ".repositories"
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
		set user_choice to button returned of (display dialog "You can launch OmegaT to later open a project, or create a project." with title "No OmegaT project has been selected" buttons {"Launch OmegaT", "Create Project", "Cancel"} default button "Create Project" cancel button "Cancel")
	else if (is_team_project = true) and (is_IP_connected = true) then # this is a team project and the machine is connected:  open team project or open locally
		set user_choice to button returned of (display dialog "Do you want to open the team project for synchronization, or do you want to keep your modifications local for this session?" with title "You have selected an OmegaT team project" buttons {"Synchronize", "Keep local", "Cancel"} default button "Keep local" cancel button "Cancel")
	else if (is_team_project = true) and (is_IP_connected = false) then # this is a team project and the machine is not connected:  open team project without synchronization
		set user_choice to button returned of (display dialog "You have selected a team project, but there is no connection. Do you want to open the team project for synchronization when the connection resumes, or do you want to keep your modifications local for this session?" with title "You have selected an OmegaT team project" buttons {"Synchronize", "Keep local", "Cancel"} default button "Keep local" cancel button "Cancel")
	else # this is a local OmegaT project: open project or create project
		set user_choice to button returned of (display dialog "You have selected a local OmegaT project. You can open the project, or create a new project." with title "You have selected a local OmegaT project" buttons {"Open Project", "Create Project", "Cancel"} default button "Open Project" cancel button "Cancel")
	end if
on error number -128
	set usercanceled to true
	return
end try
# user_choice is of {"Launch OmegaT", "Synchronize", "Keep local", "Open Project", "Create Project", "Cancel"}

try
	if user_choice is "Launch OmegaT" then
		# "Launch OmegaT"
		# launch OmegaT with default parameters, without specifying a project
		set command_parameters to ""
	else if user_choice is "Synchronize" then
		# "Open Team Project"
		# launch OmegaT with project parameters, connected, on the team project
		set command_parameters to project_path & config_parameter
	else if user_choice is "Keep local" then
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
		# temporarily, just launch OmegaT
		#	my CreateProject()
		display dialog "OmegaT will now be launched. Use \"Project > New...\" to create a new project." with title "Create a new project with OmegaT" buttons {"OK"} default button "OK"
		set command_parameters to ""
	end if
	set myCommand to omegat_command & command_parameters
on error
	display alert "Somethine went wrong..."
	return
end try

my launchOmegaT(myCommand)

on launchOmegaT(myCommand)
	set the clipboard to myCommand
	try
		set user_choice to button returned of (display dialog "This command will now be launched in a Terminal window:
" & myCommand & "

The command has also been copied to your clipboard." with title "Launch OmegaT in Terminal")
		tell application "Terminal" to activate
		tell application "System Events" to tell application process "Terminal"
			set frontmost to true
			delay 0.1
			try
				keystroke "t" using {command down}
			on error
				display alert "The script can't create a Terminal tab because it does not have UI access rights.
Modify Preferences > Accessibility to open the command in a new tab."
			end try
			tell application "Terminal"'s front window
				delay 0.1
				do script myCommand in its last tab
				activate
			end tell
		end tell
		return
	on error
		display alert "Canceling"
		return
	end try
end launchOmegaT

on CreateProject()
	display alert "Create a project"
	# TODO use code from project.app to create a working OmegaT project with required parameters
	return
end CreateProject
