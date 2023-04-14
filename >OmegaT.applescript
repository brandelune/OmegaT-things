(* 
------------------------------------------------------------------------------------------
	-- Auth: Jean-Christophe Helary
	-- Appl: OmegaT
	-- Task: Launch OmegaT on a Finder selected project
	-- Libs: None
	-- Osax: None 
	-- Tags: @Applescript, @OmegaT
	------------------------------------------------------------------------------------------

This code is distributed under the GPL3 licence.

*)

use AppleScript version "2.4" -- Yosemite (10.10) or later
use scripting additions
use framework "Foundation"

# This version: Wednesday, September 8, 2022
# → remove UI scripting for Terminal access
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

## identify the OmegaT preference folders
set user_preferences_folder to ((POSIX path of (path to home folder)) & "Library/Preferences/")
set omegat_configuration_folder to user_preferences_folder & "OmegaT/"

#### the two items below are specific to this script, they may well not exist.
#
# that "OmegaT configuration" folder will be the place where this script creates project specific configuration folders.
# the script checks whether a configuration folder with the same name as the project exists and uses it for launching the project.
# if the folder does not exist, OmegaT asks (later) whether the project should use one or not
#

set projects_configuration_folder to user_preferences_folder & "OmegaT configurations/"
try #to see if the project specific configuration folder exists
	alias POSIX file projects_configuration_folder
on error # if it does not exist, create it
	do shell script "mkdir " & quoted form of projects_configuration_folder
end try

#
# the launch preference file mainly contains the path to the prefered OmegaT.jar file
# 
# there are probably other ways to use this file
#

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

#
####

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
		set user_choice to button returned of (display dialog ¬
			"You can launch OmegaT to later open a project, or create a project." with title ¬
			"No OmegaT project has been selected" buttons {"Launch OmegaT", "Create Project", "Cancel"} ¬
			default button "Create Project" cancel button "Cancel")
	else if (is_team_project = true) and (is_IP_connected = true) then # this is a team project and the machine is connected:  open team project or open locally
		set user_choice to button returned of (display dialog ¬
			"Do you want to open the team project for synchronization, or do you want to keep your modifications local for this session?" with title ¬
			"You have selected an OmegaT team project" buttons {"Synchronize", "Keep local", "Cancel"} ¬
			default button "Keep local" cancel button "Cancel")
	else if (is_team_project = true) and (is_IP_connected = false) then # this is a team project and the machine is not connected:  open team project without synchronization
		set user_choice to button returned of (display dialog ¬
			"You have selected a team project, but there is no connection. Do you want to open the team project for synchronization when the connection resumes, or do you want to keep your modifications local for this session?" with title ¬
			"You have selected an OmegaT team project" buttons {"Synchronize", "Keep local", "Cancel"} ¬
			default button "Keep local" cancel button "Cancel")
	else # this is a local OmegaT project: open project or create project
		set user_choice to button returned of (display dialog ¬
			"You have selected a local OmegaT project. You can open the project, or create a new project." with title ¬
			"You have selected a local OmegaT project" buttons {"Open Project", "Create Project", "Cancel"} ¬
			default button "Open Project" cancel button "Cancel")
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
		my CreateProject()
		# display dialog "OmegaT will now be launched. Use \"Project > New...\" to create a new project." with title "Create a new project with OmegaT" buttons {"OK"} default button "OK"
		set command_parameters to ""
	end if
	set myCommand to omegat_command & command_parameters
on error
	display alert "Something went wrong..."
	return
end try

my launchMyCommand(myCommand, project_folder)


#### Utilities ####

on CreateProject()
	set ressource_list to {"Source files", "TMs", "Glossaries"}
	set project_ressources to {"source", "tm", "glossary", "target", "omegat", "dictionary", "mt", "auto", "enforce", "penalty-010"}
	set default_location to item 1 of getMySelectedFolders()
	# returns an AS alias: the first item of a list of AS aliases
	set project_folder to (choose folder with prompt "Dossier dans lequel créer le projet :" default location default_location)
	# //choose folder// returns an AS alias
	
	try
		set originals_folder to ((project_folder as text) & "originaux") as alias # coercion from alias to text, to alias → alias
	on error
		set originals_folder to project_folder # → alias
	end try
	
	set item 1 of ressource_list to choose file with prompt (item 1 of ressource_list) default location originals_folder with multiple selections allowed # //choose file// returns an AS alias
	
	try
		if button returned of (display dialog "Any reference files?" buttons {"Oui", "Non"} default button "Non" cancel button "Non") is "Oui" then
			repeat with i from 2 to 3
				try
					set item i of ressource_list to choose file with prompt (item i of ressource_list) default location originals_folder with multiple selections allowed # //choose file// returns an AS alias
				on error
					set item i of ressource_list to {}
				end try
			end repeat
		end if
	on error
		log "no reference files"
	end try
	
	set project_name to text returned of (display dialog "Nom du projet :" default answer "") # //text returned// returns text
	
	set project_folder to (project_folder as text) & project_name # text, can't be an alias, the folder doesn't exist yet
	do shell script "mkdir -p " & (quoted form of POSIX path of project_folder)
	
	repeat with i from 1 to 6
		set myFolder to (quoted form of POSIX path of (project_folder & ":" & item i of (project_ressources)))
		do shell script "mkdir -p " & myFolder
	end repeat
	
	repeat with i from 7 to number of items in (project_ressources)
		set myFolder to (quoted form of POSIX path of (project_folder & ":tm:" & item i of (project_ressources)))
		do shell script "mkdir -p " & myFolder
	end repeat
	
	repeat with i from 1 to 3
		repeat with ressource_file in (item i of ressource_list)
			if class of ressource_file is alias then
				try
					set myProjectRessource to (quoted form of POSIX path of (project_folder & ":" & item i of (project_ressources)))
					do shell script "cp " & (quoted form of POSIX path of ressource_file) & " " & myProjectRessource
				on error
					log "pas de fichiers à copier"
				end try
			end if
		end repeat
	end repeat
	
	set project_settings to {"JA-JP", "FR-FR", "true", "true", "Langue source :", "Langue cible :", "Appliquer les règles de segmentation ?", "Retirer les marqueurs ?"}
	set projet_standard to button returned of (display dialog "JA-JP → FR-FR / segmenté / sans marqueurs ?" buttons {"Oui", "Non"} default button "Oui")
	
	if projet_standard = "Non" then # ask for new parameters
		repeat with i from 1 to 2
			set item i of project_settings to text returned of (display dialog (item (i + 4) of project_settings) default answer (item i of project_settings))
		end repeat
		repeat with i from 3 to 4
			set item i of project_settings to button returned of (display dialog (item (i + 4) of project_settings) buttons {"Oui", "Non"} default button {"Oui"})
			if item i of project_settings = "Non" then
				set item i of project_settings to "false"
			else
				set item i of project_settings to "true"
			end if
		end repeat
	end if
	
	set ParametersList to {"__DEFAULT__", "__DEFAULT__", "__DEFAULT__", "__DEFAULT__", "__DEFAULT__", "__DEFAULT__", item 1 of project_settings, item 2 of project_settings, "source tok", "target tok", item 3 of project_settings, true, item 4 of project_settings, "", ((POSIX path of (project_folder as alias)) & "omegat.project")}
	
	my createOmegaTProjectFile(ParametersList)
	
	if button returned of (display dialog "Ouvrir le projet dans OmegaT ?" buttons {"Oui", "Non"} default button "Oui") is "Oui" then
		set launch_OmegaT to true
		set OmegaTPreferences to my GetOmegaTPreferences()
		set myProjectPreferences to my GetProjectPreferences(item 1 of OmegaTPreferences, item 2 of OmegaTPreferences, project_folder, launch_OmegaT)
		launchMyCommand(item 2 of myProjectPreferences, project_folder)
	else
		tell application "Finder" to activate
	end if
	
	tell application "Finder"
		open file "Courant.savedSearch" of folder "Saved Searches" of folder "Library" of home
		set bounds of front window to {960, 25, 1440, 900}
		open project_folder
		set bounds of front window to {481, 25, 961, 462}
	end tell
	
end CreateProject

on createOmegaTProjectFile(ParametersList)
	set project_tags to {"source_dir", "target_dir", "tm_dir", "glossary_dir", "glossary_file", "dictionary_dir", "source_lang", "target_lang", "source_tok", "target_tok", "sentence_seg", "support_default_translations", "remove_tags", "external_command"}
	set masks to {"**/.svn/**", "**/CVS/**", "**/.cvs/**", "**/desktop.ini", "**/Thumbs.db", "**/.DS_Store"}
	set valueindex to 0
	set projectRoot to a reference to (current application's NSXMLNode's elementWithName:"omegat")
	set theProject to a reference to (current application's NSXMLNode's documentWithRootElement:projectRoot)
	theProject's setCharacterEncoding:"UTF-8"
	theProject's setStandalone:true
	set project to a reference to (current application's NSXMLNode's elementWithName:"project")
	set projectVersion to a reference to (current application's NSXMLNode's attributeWithName:"version" stringValue:"1.0")
	project's addAttribute:projectVersion
	projectRoot's addChild:project
	repeat with child in project_tags
		set valueindex to valueindex + 1
		set child to (a reference to (current application's NSXMLNode's elementWithName:child stringValue:(item valueindex of ParametersList)))
		(project's addChild:child)
	end repeat
	set child to (a reference to (current application's NSXMLNode's elementWithName:"source_dir_excludes"))
	(project's addChild:child)
	set source_dir_excludes to (project's elementsForName:"source_dir_excludes")'s firstObject()
	repeat with mask in masks
		set mask to (a reference to (current application's NSXMLNode's elementWithName:"mask" stringValue:mask))
		(source_dir_excludes's addChild:mask)
	end repeat
	set theData to theProject's XMLDataWithOptions:((get 131072) + (get 1024))
	theData's writeToFile:(item 15 of ParametersList) options:1 |error|:(missing value)
	return
end createOmegaTProjectFile

on GetOmegaTPreferences()
	# set default OmegaT parameters
	set user_preferences_folder to ((POSIX path of (path to home folder)) as text) & "Library/Preferences/"
	set projects_configuration_folder to user_preferences_folder & "OmegaT configurations/"
	set omegat_launch_preference_file to user_preferences_folder & "OmegaT/omegat_launch.plist"
	set factory_settings_configuration_folder to projects_configuration_folder & "Factory settings/"
	try
		alias (POSIX file projects_configuration_folder)
	on error
		do shell script "mkdir -p " & (quoted form of projects_configuration_folder)
	end try
	try
		do shell script "rm -r " & (quoted form of factory_settings_configuration_folder) & "*"
	on error
		do shell script "mkdir -p " & (quoted form of factory_settings_configuration_folder)
	end try
	tell application "System Events"
		try # does the omegat launch preference file exist ?		
			# TODO check that the file is in the correct format ?
			set omegat_launch_preferences to contents of property list file omegat_launch_preference_file
			set omegat_path to value of item 1 of (property list items of omegat_launch_preferences whose name is "Path")
			set omegat_type to value of item 1 of (property list items of omegat_launch_preferences whose name is "Type")
			set omegat_version to value of item 1 of (property list items of omegat_launch_preferences whose name is "Version")
		on error # create the omegat launch preference file
			set the launch_preferences to make new property list item with properties {kind:record}
			set omegat_launch_preference_file to make new property list file with properties {contents:launch_preferences, name:omegat_launch_preference_file}
			tell property list items of omegat_launch_preference_file
				set omegat_location to (choose file with prompt "Location of OmegaT:" default location (path to applications folder))
				if (name of omegat_location does not contain "OmegaT") then
					display alert "Select the version of OmegaT you want to use (either OmegaT.app or OmegaT.jar)"
					return
				end if
				set omegat_creation_date to modification date of omegat_location
				set omegat_type to (name extension of omegat_location) as string
				set omegat_version to ¬
					((year of (omegat_creation_date) as string) & ¬
						(text -2 thru -1 of ("00" & (month of (omegat_creation_date) as integer))) & ¬
						(text -2 thru -1 of ("00" & (day of (omegat_creation_date) as integer))) & ¬
						(text -5 thru -1 of ("00000" & (time of (omegat_creation_date) as integer)))) ¬
						as integer
				if name of omegat_location = "OmegaT.app" then
					set omegat_path to ((POSIX path of (omegat_location)) as string) & "/Contents/Java/OmegaT.jar"
				else if name of omegat_location = "OmegaT.jar" then
					set omegat_path to (POSIX path of (omegat_location)) as string
				end if
				make new property list item at its end with properties {kind:record, name:"Path", value:omegat_path}
				make new property list item at its end with properties {kind:record, name:"Type", value:omegat_type}
				make new property list item at its end with properties {kind:record, name:"Version", value:omegat_version}
			end tell
		end try
	end tell
	return {omegat_path, projects_configuration_folder}
end GetOmegaTPreferences

on GetProjectPreferences(omegat_path, projects_configuration_folder, project_folder, launch_OmegaT)
	# set project parameters
	#	set project_folder to ""
	#	set project_path to ""
	set config_parameter to ""
	set command_parameters to ""
	set is_project to false
	set is_team_project to false
	set is_IP_connected to false
	set is_local to ""
	set this_project_configuration_folder to projects_configuration_folder & "Factory settings/" as POSIX file
	set user_preferences_folder to ((POSIX path of (path to home folder)) as text) & "Library/Preferences/"
	tell application "Finder" # set some folder properties
		set selectedFolderName to name of (project_folder as alias)
		set selectedFolder to POSIX path of (project_folder as alias)
	end tell
	
	try # is the folder an OmegaT project ?
		alias POSIX file (selectedFolder & "omegat.project")
		set is_project to true
	end try
	
	try # is the project a 4.1 team project ?
		alias POSIX file (selectedFolder & ".repositories")
		set is_team_project to true
	end try
	
	try # is the project a 3.6 team project ?
		alias POSIX file (selectedFolder & ".git")
		set is_team_project to true
	end try
	
	if is_team_project is true then # check the connection
		try # is the machine online ?
			# TODO the project could be a local team project, so need to check the connection in other ways
			do shell script ("ping -c 2 " & "www.omegat.org")
			set is_IP_connected to true
		on error
			display alert "There is no internet connection, the project will be opened locally."
			set is_local to " --no-team "
		end try
	end if
	
	if is_project = true then # what is the action ?
		set project_path to quoted form of selectedFolder
		set project_name to selectedFolderName
		if (is_team_project = true) and (is_IP_connected = true) then # this is a team project and the machine is connected:  open team project or open locally
			set {Button_1, Button_2, Default_Button} to {"Open Team Project", "Open Project Locally", "Open Project Locally"}
		else # this is an OmegaT project, either team and not connected or local: open project or create project
			set {Button_1, Button_2, Default_Button} to {"Open Project", "Create Project", "Open Project"}
		end if
	else # this is not an OmegaT project: either create a project at selection or open OmegaT empty
		set {Button_1, Button_2, Default_Button} to {"Launch OmegaT", "Create Project", "Create Project"}
	end if
	
	if launch_OmegaT = true then
		set user_choice to "Launch OmegaT"
	else
		try # ask for the action
			set user_choice to button returned of (display dialog Button_1 & " / " & Button_2 buttons {Button_1, Button_2, "Cancel"} default button Default_Button cancel button "Cancel")
			if user_choice is "Create Project" then return {"Create Project", 0, 0, 0, 0}
		on error
			return {"Cancel", 0, 0, 0, 0}
		end try
	end if
	
	if user_choice is "Open Project Locally" then set is_local to " --no-team "
	
	if user_choice is "Launch OmegaT" then # ask which configuration to use
		try
			set project_configuration to button returned of (display dialog "Project settings / User settings / OmegaT defaults" buttons {"Project", "User", "Default"} default button "Project" cancel button "User")
		on error
			set project_configuration to "User"
		end try
	else
		try
			set project_configuration to button returned of (display dialog "User settings / OmegaT defaults" buttons {"User", "Default"} default button "User" cancel button "Default")
		on error
			set project_configuration to "Default"
		end try
	end if
	
	if project_configuration is "Project" then # check if there is a dedicated configuration folder
		try # does the project have a dedicated configuration folder in ~/Library/Preferences/OmegaT configurations/ ?
			alias POSIX file (projects_configuration_folder & project_name)
			set this_project_configuration_folder to (projects_configuration_folder & project_name) as POSIX file
		on error # Create a new configuration folder. If a project already exists with that name that configuration folder will be used so there will be no overwritting.
			tell application "Finder"
				set this_project_configuration_folder to POSIX path of ((make new folder at (POSIX file projects_configuration_folder as alias) with properties {name:project_name}) as alias)
				duplicate items of (POSIX file (user_preferences_folder & "OmegaT/") as alias) to (POSIX file this_project_configuration_folder)
				delete items of (POSIX file ((this_project_configuration_folder) & "logs") as alias)
				delete items of (POSIX file ((this_project_configuration_folder) & "script") as alias)
				delete items of (POSIX file ((this_project_configuration_folder) & "spelling") as alias)
				try
					delete (POSIX file ((this_project_configuration_folder) & "segmentation.conf") as alias)
				on error
					log "no segmentation file"
				end try
				try
					delete (POSIX file ((this_project_configuration_folder) & "repositories.properties") as alias)
				on error
					log "no repository properties file"
				end try
				
			end tell
		end try
	else if project_configuration is "User" then
		set this_project_configuration_folder to (user_preferences_folder & "OmegaT/" as POSIX file)
	end if
	
	set config_parameter to " --config-dir=" & quoted form of POSIX path of this_project_configuration_folder
	set myCommand to "java -Xdock:name=OmegaT -jar " & quoted form of omegat_path & " " & project_path & is_local & config_parameter
	
	return {user_choice, myCommand}
end GetProjectPreferences

# returns the selected folders (except for documents that are packages but are registered as document files) or the window target, or the Desktop, as an alias list
on getMySelectedFolders()
	tell application "Finder" to set myClasses to {folder, application file, package}
	# sets 3 classes that are special to Finder
	set selectedFolders to {}
	# sets an empty selectedFoders
	try
		tell application "Finder"
			if (selection as alias list) ≠ {} then
				# if the selection is not an empty //alias list// → Specific to Finder
				set mySelection to selection
				# put the list into mySelection
				repeat with thisItem in mySelection
					if class of thisItem is alias file then
						set thisItem to original item of thisItem
						# //original item// → Specific to Finder, the original item of an alias
					end if
					# here we have all the Finder aliases replaced with their original
					if class of thisItem is in myClasses then
						# now, if the item has one of the 3 classes above
						set the end of selectedFolders to thisItem as alias
						# puts a FS //alias// of this item at the end of selectedFolders defined above as empty
					else
						set the end of selectedFolders to container of thisItem as alias
						# otherwise put an AS alias to the container of this item as the last element.
					end if
				end repeat
			else
				set the end of selectedFolders to insertion location as alias
				# if the selection *is* an empty //alias list// → Specific to Finder
				# then put the insertion location at the end of selectedFolders
			end if
		end tell
	on error
		try
			tell application "Finder"
				(selection as alias list)
				set the end of selectedFolders to insertion location as alias
				# if there is an error in the selection process, just check that there is a selection
				# and add its insertion location to the end of selectedFolders
			end tell
		on error
			tell application "Finder"
				
				set the end of selectedFolders to desktop as alias
				# if there is an error here too
				# just use Desktop as selectedFolders
			end tell
		end try
		display alert "No containing folder: default to Desktop"
	end try
	return selectedFolders
	# returns a list of AS aliases
end getMySelectedFolders

on launchMyCommand(myCommand, project_folder)
	
	set myLaunch to text returned of (display dialog "" default answer myCommand with title "Launch OmegaT in Terminal") as text
	set the clipboard to myLaunch
	display dialog "The OmegaT launch command:
		
		" & myLaunch & "
		
		has also been copied to the clipboard."
	
	
	set myCommand to "cd " & quoted form of (POSIX path of (project_folder as alias)) & ";" & myLaunch
	tell application "Terminal"
		set T to do script myCommand
	end tell
	
	
	--# First I use GUI scripting to create a new Terminal window
	--tell application "Terminal" to activate
	--tell application "System Events" to tell application process "Terminal"
	--	set frontmost to true
	--	delay 0.1
	--	keystroke "t" using {command down}
	--end tell
	--	
	--# Then I ask the newly created window to run the command
	--tell application "Terminal"'s front window
	--	delay 0.1
	--	do script myCommand in its last tab
	--	activate
	--end tell
	
	--# And I eventually merge that window to the other so as to keep everything tidy
	--tell application "System Events" to tell application process "Terminal"
	--	set frontmost to true
	--	delay 0.1
	--	keystroke "m" using {control down, command down}
	--end tell
	return
end launchMyCommand
