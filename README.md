# Kalle Paint
A paint program for the [NES](https://en.wikipedia.org/wiki/Nintendo_Entertainment_System). Also known as Qalle Paint. Tested on FCEUX and Mednafen.

Screenshots (the last one is from *Doom* by id Software):

![screenshot](snap1.png)
![screenshot](snap2.png)
![screenshot](snap3.png)

Table of contents:
* [List of files](#list-of-files)
* [Features](#features)
* [How to use](#how-to-use)
  * [Paint mode](#paint-mode)
  * [Attribute edit mode](#attribute-edit-mode)
  * [Palette edit mode](#palette-edit-mode)
  * [Button summary](#button-summary)
* [Technical info](#technical-info)
* [To do](#to-do)

## List of files
Text:
* `assemble.sh`: a Linux script that assembles the program (warning: deletes files)
* `chr-pt0-gen.py`: a Python program that generates CHR ROM data for pattern table 0 (background for all modes except title screen)
* `paint.asm`: source code (assembles with [ASM6](https://www.romhacking.net/utilities/674/))
* `png2fm2.py`: a Python program that converts a PNG image into an FM2 (FCEUX) movie that draws the image

Images:
* `chr-pt1.png`: CHR ROM data for pattern table 1; the first 32 tiles are for title screen background, the next 32 are for sprites; can be encoded with `nes_chr_encode.py` in [my NES utilities](https://github.com/qalle2/nes-util)
* `convtest*.png`: test images for `png2fm2.py`
* `snap*.png`: screenshots

Other (gzip compressed):
* `chr-pt0.bin.gz`: background CHR ROM data (see `chr-pt0-gen.py`)
* `chr-pt1.bin.gz`: sprite CHR ROM data (see `chr-pt1.png`)
* `convtest*.fm2.gz`: FCEUX movies created with `png2fm2.py`
* `paint.nes.gz`: assembled program (iNES format)

## Features
* 64&times;60 "pixels" (4&times;4 hardware pixels each)
* 13 colors simultaneously from the NES master palette
* 1&times;1-pixel or 2&times;2-pixel brush

Restrictions on color use:
* There are four subpalettes with four colors each.
* On an imaginary grid of 4&times;4 pixels, each square ("attribute block") can only use one subpalette.
* The first color is shared between all subpalettes. (Only the last three colors in each subpalette can be freely defined.)

By default, the screen is filled with the first color of the first subpalette.

## How to use
First, press start to exit the title/help screen. (You can't get back to it.) Afterwards, there are three modes. Press select at any time to cycle between them.

### Paint mode

The cursor is a small or medium non-blinking square. It reflects the selected brush size and paint color.

Buttons:
* up/down/left/right: move cursor (hold down to move repeatedly)
* start: toggle between small and large brush
* B: increment paint color (there are four colors per subpalette)
* A: paint at cursor using selected color and brush (can be held down while moving the cursor)
* select: switch to attribute edit mode

Note: The cursor is invisible if it is on a pixel of the same color or at the very top of the screen. Depending on your screen, the cursor may also disappear near the top or bottom of the screen.

Hint: to move long distances faster, switch to the large brush.

### Attribute edit mode

This mode looks like the paint mode except that the cursor is a large blinking square.

Buttons:
* up/down/left/right: move cursor
* B/A: decrement/increment subpalette at cursor (there are four subpalettes)
* select: switch to palette edit mode
* start: unused

Notes:
* Changing the subpalette has no visible effect if the selected square only contains the first color of a subpalette. (That color is shared between all subpalettes.)
* The cursor is partially invisible at the top of the screen. It may also be partially invisible at the bottom depending on your screen.

### Palette edit mode

The palette editor is a black window at the bottom right corner of the screen.

Indicators:
* `Pal`: number of subpalette being edited (`0`&ndash;`3`)
* colored squares: colors in selected subpalette (topmost = first)
* blinking cursor: highlights the color being edited
* digits next to colors: NES color numbers in hexadecimal (`00`&ndash;`3F`); the first digit roughly corresponds to brightness (dark/light) and the second one to hue (red/green/etc.)

Buttons:
* start: increment subpalette (there are four subpalettes)
* up/down: move cursor
* left/right: decrement/increment ones of color number
* B/A: decrement/increment 16s of color number
* select: switch to paint mode

Note: the first (topmost) color is shared between all subpalettes.

### Button summary
```
Button | In paint mode          | In attribute edit mode | In palette edit mode
-------+------------------------+------------------------+---------------------
up     |                          cursor up
-------+-----------------------------------------------------------------------
down   |                          cursor down
-------+-------------------------------------------------+---------------------
left   |                  cursor left                    | color -1
-------+-------------------------------------------------+---------------------
right  |                  cursor right                   | color +1
-------+------------------------+------------------------+---------------------
B      | color +                | palette -              | color -16
-------+------------------------+------------------------+---------------------
A      | paint                  | palette +              | color +16
-------+------------------------+------------------------+---------------------
start  | brush size             | unused                 | palette +
-------+------------------------+------------------------+---------------------
select | to attribute edit mode | to palette edit mode   | to paint mode
```

## Technical info
* mapper: NROM
* PRG ROM: 16 KiB
* CHR ROM: 8 KiB
* name table mirroring: vertical
* name table 0: all modes except title screen
* name table 1: title screen
* compatibility: NTSC &amp; PAL

## To do
* only use NTSC visible area
* test with other emulators
* paint cursor should accelerate
