(* 
------------------------------------------------------------------------------------------
	-- Auth: Jean-Christophe Helary
	-- Help: Shane Stanley, Steve Mills
	-- Thread: https://lists.apple.com/archives/applescript-users/2017/Mar/msg00271.html
	-- dCre: 2017/03/25
	-- dMod: 2021/12/19
	-- Appl: Excel
	-- Task: Convert Excel "used range" to TMX
	-- Libs: None
	-- Osax: None 
	-- Tags: @Applescript, @ASObj-C, @Excel, @TMX, @XML
	------------------------------------------------------------------------------------------

This code is distributed under the GPL3 licence.

*)

use AppleScript version "2.4" -- Yosemite (10.10) or later
use framework "Foundation"
use scripting additions

(*
 creates a TMX file from tabular data in an opened Excel file
	
 Excel contains tabular data with the following structure:
 First row is a list of language names
 Columns have translations of the first column in the language given in the first row
 	en         fr         ja
  Airport    Aéroport   空港
  Expressway Autoroute  高速道路
 etc.
	
 TMX structure:
 <?xml...>
 <!DOCTYPE...>
 <tmx>
	<header attributes...>
	</header>
	<body>
		<tu>
			<tuv xml:lang="en"><seg>Airport</seg></tuv>
			<tuv xml:lang="fr"><seg>Aéroport</seg></tuv>
			<tuv xml:lang="ja"><seg>空港</seg></tuv>
		</tu>
		<tu>
			<tuv xml:lang="en"><seg>Expressway</seg></tuv>
			<tuv xml:lang="fr"><seg>Autoroute</seg></tuv>
			<tuv xml:lang="ja"><seg>高速道路</seg></tuv>
		</tu>
 ...
	</body>
 </tmx>
	
 get the TM data from the used range of the first worksheet
 cells can be empty, the corresponding <tuv> will also be empty
*)

(*
TODO
✔️ create GIT repository
✔️ commit .applescript
*)

tell application "Microsoft Excel"
	set myFile to name of active workbook
	set myPath to path of active workbook
	tell active sheet of active workbook
		set myTMData to the string value of used range
	end tell
end tell


(*
TODO
        • rewrite with handlers
	• add support to Word tables
	• add support to multiple sheets
*)

if myTMData is equal to "" then
	display alert "The file is empty."
	quit me
end if

(*
TODO
	✔️ if the worksheet is empty, quit → 03/26
	• check that an Excel file is actually opened if not, open a dialog to select one
	• create TMData for each sheet → create TM for each TMData, with sheet name appended
*)


-- attempt at showing progress
set myLines to length of myTMData
set progress total steps to myLines
set progress completed steps to 0
set progress description to "Processing TUs..."
set progress additional description to "Preparing to process."


-- language codes to serve as <tuv>'s xml:lang attributes
set theLANGAttribute to list 1 of myTMData

(*
 TODO
 	• check that the language codes are ISO codes → alert if not but proceed
 	• propose ISO codes if not ISO compliant
 	• propose a different srclang from the available languages or *all*
*)

-- create the DTD, although not requested for TMX
-- new() is used to create an instance of NSXMLDTD
-- then, various methods are used to create the DTD contents
set theDTD to current application's NSXMLDTD's new()
theDTD's setName:"tmx"
theDTD's setPublicID:"-//LISA OSCAR:1998//DTD for Translation Memory eXchange//EN"
theDTD's setSystemID:"tmx14.dtd"

-- create the XML document
-- then creation of the root elements (<tmx>) and it's only attribute
set tmxRoot to current application's NSXMLNode's elementWithName:"tmx"
set tmxVersion to (current application's NSXMLNode's attributeWithName:"version" stringValue:"1.4")
(tmxRoot's addAttribute:tmxVersion)

-- creation of the TMX document
-- alloc() is used to create a new instance of the NSXMLDocument class
-- to complete the initialization process, init is required
-- then, vaious methods are used to create the root parameters
set theTMXdocument to current application's NSXMLDocument's alloc()'s initWithRootElement:tmxRoot
theTMXdocument's setDocumentContentKind:(current application's NSXMLDocumentXMLKind)
theTMXdocument's setCharacterEncoding:"UTF-8"
theTMXdocument's setDTD:theDTD

-- creation of the <header> element
set tmxHeader to current application's NSXMLNode's elementWithName:"header"

(*
TODO
	• add <prop> to the header to define the TMX contents
	contents can include XLS file name, languages, comment from the creator
*)

-- <header> attributes

-- srclang is the language in the first column of the first row of the data set
set myTMsrclang to item 1 of theLANGAttribute

-- creationdate is an ISO8601 date
set theDate to current application's NSDate's |date|()
set myDateString to (current application's NSISO8601DateFormatter's stringFromDate:theDate timeZone:(current application's NSTimeZone's timeZoneWithAbbreviation:"GMT") formatOptions:115) as text

-- the other attributes are hard coded
set headerAttributesDict to current application's NSDictionary's dictionaryWithObjects:{"paragraph", "0.1", "xls2tmx", "en", "unknown", myTMsrclang, "Microsoft Excel", myDateString} forKeys:{"segtype", "creationtoolversion", "creationtool", "adminlang", "datatype", "srclang", "o-tmf", "creationdate"}
(tmxHeader's setAttributesWithDictionary:headerAttributesDict)

-- creation of the <body> element, no attributes
set tmxBody to current application's NSXMLNode's elementWithName:"body"

-- back to the data
-- processing the TM data, from the second row
repeat with i from 2 to length of myTMData
	
	-- Update the progress detail
	set progress additional description to "Processing TUs " & i & " of " & myLines
	-- Increment the progress
	set progress completed steps to i
	
	-- creation of the <tu> element, no attributes
	set TUElement to (current application's NSXMLNode's elementWithName:"tu")
	-- myTU is a given row, contains as many <tuv> elements as there are items in the row
	set myTU to item i of myTMData
	
	(*
	TODO
		• dump the empty rows
		• dump the duplicated rows
	*)
	
	repeat with j from 1 to length of myTU
		-- each item in myTU will be a <tuv>
		set myTUV to item j of myTU
		-- myTUV's xml:lang attribute will be the item with the same index in theLANGAttribute
		set newTuv to (current application's NSXMLNode's elementWithName:"tuv")
		set myLANGAttribute to item j of theLANGAttribute
		set newAttribute to (current application's NSXMLNode's attributeWithName:"xml:lang" stringValue:myLANGAttribute)
		(newTuv's addAttribute:newAttribute)
		-- newSeg is the segment <seg> for that <tuv>
		set newSeg to (current application's NSXMLNode's elementWithName:"seg" stringValue:myTUV)
		-- <seg> is defined as a child of <tuv>
		(newTuv's addChild:newSeg)
		-- <tuv> is defined as a child of <tu>
		(TUElement's addChild:newTuv)
	end repeat
	-- <tu> contains all the <tuv> in one row
	-- <tu> is defined as a child of <body>
	(tmxBody's addChild:TUElement)
end repeat
-- <header> comes before <body> and is defined as a child of <tmx>
(tmxRoot's addChild:tmxHeader)
-- <body> comes after <header> and is defined as a child of <tmx>
(tmxRoot's addChild:tmxBody)

-- the data is saved as XML data, pretty printed and written to a file
set theTMXFilePath to (POSIX path of (path to desktop)) & "xls2tmx_" & myDateString & ".tmx"
set theData to theTMXdocument's XMLDataWithOptions:((current application's NSXMLDocumentTidyXML) + (get current application's NSXMLNodePrettyPrint))
theData's writeToFile:theTMXFilePath atomically:true

tell application "Finder" to activate desktop

-- Reset the progress information
set progress total steps to 0
set progress completed steps to 0
set progress description to ""
set progress additional description to ""

(*
----------------------------------------------------------------------------------------
The whole thing should be as fast as possible, so hardcode all the defaults and don't use any GUI if possible. Basically the user opens the Excel file, checks the data, if satisfied runs the script and the TMX is created where the Excel file is stored, to be used right away. Et voilà.
----------------------------------------------------------------------------------------

Convert Word
tell application "Microsoft Word"
word 1 of cell 1 of row 1 of front table of active document
end tell
*)
