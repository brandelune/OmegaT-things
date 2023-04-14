(* 
------------------------------------------------------------------------------------------
	-- Auth: Jean-Christophe Helary
	-- Help: Shane Stanley, Steve Mills
	-- Thread: https://lists.apple.com/archives/applescript-users/2017/Mar/msg00271.html
	-- dCre: 2021/12/19
	-- dMod: 2021/12/19
	-- Appl: TextEdit
	-- Task: Convert TextEdit documents to TMX
	-- Libs: None
	-- Osax: None 
	-- Tags: @Applescript, @ASObj-C, @TextEdit, @TMX, @XML
	------------------------------------------------------------------------------------------

This code is distributed under the GPL3 licence.

*)

use AppleScript version "2.4" -- Yosemite (10.10) or later
use framework "Foundation"
use scripting additions
use BridgePlus : script "BridgePlus"
load framework
-- this is necessary to use BridgePlus functions
-- see https://www.macosxautomation.com/applescript/apps/BridgePlus.html

tell application "TextEdit"
	
	set myNbofDocuments to number of documents
	-- number of documents to handle
	set theLANGAttributes to {}
	-- language codes to serve as <tuv>'s xml:lang attributes
	set myLines to 0
	-- number of lines in each document
	set myRawData to {}
	-- an array of lists that contains all the paragraphs for each document
	set myTMData to {}
	-- the array above reorganized so that each paragraph is associated to the paragraphs of the same rank in the other documents
	-- this takes too much time (although less than the TMX creation loop), especially for big data sets:
	-- 500 x 2 = ~5s, 6000 x 2 = ~ 70s
	
	-- get the language codes
	set visible of windows to false
	repeat with i from 1 to myNbofDocuments
		set visible of window i to true
		set end of theLANGAttributes to text returned of (display dialog " Language code for " & (name of front window) default answer "")
		set visible of window i to false
	end repeat
	set visible of windows to false
	
	
	-- get the maximum line number
	repeat with i from 1 to myNbofDocuments
		try
			set myCurrentNb to number of paragraphs of document i
			if myCurrentNb > myLines then
				set myLines to myCurrentNb
			end if
		on error
			set myLines to myCurrentNb
		end try
	end repeat
	
	
	-- fill the data set with the contents of the documents
	repeat with i from 1 to myNbofDocuments
		try
			set theDocument to document i
			set theText to text of theDocument
			set theParagraphs to my tid(theText, linefeed)
			
		on error error_message number error_number
			if the error_number is not -128 then display alert "TextEdit" message error_message as warning
			return
		end try
		set end of myRawData to theParagraphs
	end repeat
	set visible of windows to true
	display alert "Début de la conversion"
	
	-- we can work outside of TextEdit now
end tell

-- attempt at showing progress
set progress total steps to myLines
set progress completed steps to 0
set progress description to "Processing TUVs..."
set progress additional description to "Preparing to process."

-- reorder the data set to create something like:
-- {{paragraph 1 of document 1, paragraph 1 of document 2, ...}
--  {paragraph 2 of document 1, paragraph 2 of document 2, ...}
-- {paragraph myLines of document 1, paragraph myLines of document 2, ...}}
-- which happens to be the structure of Excel's "used range"
-- and is the basis of our TMX creation loop.
-- this part takes *way* too much time.

--repeat with i from 1 to length of item 1 of myRawData
--	
--	set progress additional description to "Processing raw data " & i & " of " & myLines
--	-- Increment the progress
--	set progress completed steps to i
--	
--	set oneTU to {}
--	repeat with j from 1 to length of myRawData
--		set end of oneTU to item i of item j of myRawData
--	end repeat
--	set end of myTMData to oneTU
--end repeat

set myTMData to current application's SMSForder's colsToRowsIn:myRawData |error|:(missing value)



-- The rest below is basically a copy-paste of the relevant part from the "<xls2tmx" script that I use for Excel data

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
set myTMsrclang to item 1 of theLANGAttributes

-- creationdate is an ISO8601 date
set theDate to current application's NSDate's |date|()
set myDateString to (current application's NSISO8601DateFormatter's stringFromDate:theDate timeZone:(current application's NSTimeZone's timeZoneWithAbbreviation:"GMT") formatOptions:115) as text

-- the other attributes are hard coded
set headerAttributesDict to current application's NSDictionary's dictionaryWithObjects:{"paragraph", "0.1", "txt2tmx", "en", "unknown", myTMsrclang, "TextEdit", myDateString} forKeys:{"segtype", "creationtoolversion", "creationtool", "adminlang", "datatype", "srclang", "o-tmf", "creationdate"}
(tmxHeader's setAttributesWithDictionary:headerAttributesDict)

-- creation of the <body> element, no attributes
set tmxBody to current application's NSXMLNode's elementWithName:"body"


-- back to the data
-- processing the TM data, from the first line of the documents
repeat with i from 1 to myLines
	
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
	
	--	repeat with j from 1 to length of myTU
	repeat with j from 1 to myTU's |count|()
		-- each item in myTU will be a <tuv>
		set myTUV to item j of myTU
		-- myTUV's xml:lang attribute will be the item with the same index in theLANGAttribute
		set newTuv to (current application's NSXMLNode's elementWithName:"tuv")
		set myLANGAttribute to item j of theLANGAttributes
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
set theTMXFilePath to "/users/suzume/Desktop/TextEdit2tmx_" & myDateString & ".tmx"
set theData to theTMXdocument's XMLDataWithOptions:((current application's NSXMLDocumentTidyXML) + (get current application's NSXMLNodePrettyPrint))
theData's writeToFile:theTMXFilePath atomically:true

tell application "TextEdit" to set visible of windows to true
tell application "Finder" to activate desktop

-- Reset the progress information
set progress total steps to 0
set progress completed steps to 0
set progress description to ""
set progress additional description to ""

on tid(theInput, theDelimiter)
	set d to AppleScript's text item delimiters
	set AppleScript's text item delimiters to theDelimiter
	if class of theInput = text then
		set theOutput to text items of theInput
	else if class of theInput = list then
		set theOutput to theInput as text
	end if
	set AppleScript's text item delimiters to d
	return theOutput
end tid
