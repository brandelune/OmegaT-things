# OmegaT
OmegaT related things

* **>OmegaT.applescript** is an OmegaT launcher that proposes various actions depending on what kind of folder is selected when you launch it.

* **<xls2tmx.applescript** creates a TMX from data pasted in Excel: first line should be valid language codes, the data below should be aligned textual contents.

* **<text2tmx.applescript** adapts the <xls2tmx script to deal with TextEdit windows that each contain some text: a dialog asks for the language of each window and the data inside the files should be aligned textual contents.

Unlike the Excel script above, the script requires to reorganize the data so that it can later be processed by the XML "builder". It thus takes slightly more time to run. The advantage is that TextEdit comes with macOS out of the box, unlike Excel, and that it does not try to interpret quotation marks are "strings groupers".
