# OmegaT

This repository contains a number of scripts, mostly in Applescript, for use by translators who work on macOS.

## How to run all that?

1. Save the files to your disk
2. Open them with Script Editor
3. Run them from there, or save them as applications and run them from Spotlight (my personal choice)

## Expectations

I am not a professional programmer, the scripts can be buggy, and you should not have *any* expectations about them working on your machine. Really. **Never just run stuff you find on the net without taking a look at its contents. Ever.**

The scripts work for me, I try to fix the random thing that won't work in the few edge cases I discover on my machine, but I am not trying (and I am not able) to produce production "grade" code.

Let me know if you find issues, though, but don't expect much user support here.

## OmegaT related things

**>OmegaT.applescript** is an OmegaT launcher that proposes various actions depending on what kind of folder is selected when you launch it.

## TMX related things

**<xls2tmx.applescript** creates a TMX from data pasted in Excel: first line should be valid language codes, the data below should be aligned textual contents.

**<text2tmx.applescript** adapts the **<xls2tmx** script above to deal with TextEdit windows that each contain some text: a dialog asks for the language of each window and the data inside the files should be aligned textual contents.

Unlike the Excel script above, the script requires to reorganize the data so that it can later be processed by the XML "builder". It thus takes slightly more time to run. The advantage is that TextEdit comes with macOS out of the box, unlike Excel, and that it does not try to interpret quotation marks are "strings groupers" or whatever.

# Who am I?

I am Jean-Christophe Helary, a JA/EN to FR professional translator. I've worked with OmegaT since 2002.
