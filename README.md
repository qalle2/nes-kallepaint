# Kalle Paint
A paint program for the [NES](https://en.wikipedia.org/wiki/Nintendo_Entertainment_System). Also known as Qalle Paint. Tested on FCEUX and Mednafen.

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
* `assemble.sh`: Linux script that assembles the program (warning: deletes files)
* `chr-bg.bin.gz`: background CHR ROM data (gzip compressed)
* `chr-bg-gen.py`: Python script that generates background CHR ROM data
* `chr-spr.bin.gz`: sprite CHR ROM data (gzip compressed)
* `chr-spr.png`: sprite CHR ROM data as an image (can be encoded with `nes_chr_encode.py` in [my NES utilities](https://github.com/qalle2/nes-util))
* `paint.asm`: source code (assembles with [ASM6](https://www.romhacking.net/utilities/674/))
* `paint.nes.gz`: assembled program (iNES format, gzip compressed)
* `snap*.png`: screenshots

## Features
* 64&times;60 "pixels" (4&times;4 hardware pixels each; a couple of topmost and bottommost pixel rows may be invisible depending on your screen)
* 13 colors simultaneously from the NES master palette
* 1&times;1-pixel or 2&times;2-pixel brush

Restrictions on color use:
* There are four subpalettes with four colors each.
* On an imaginary grid of 4&times;4 pixels, each square ("attribute block") can only use one subpalette.
* The first color is shared between all subpalettes. (Only the last three colors in each subpalette can be freely defined.)

By default, the screen is filled with the first color of the first subpalette.

## How to use
There are three modes. Press select at any time to cycle between them. However, beginners are advised to stick to the default mode (paint mode) for quite a while before experimenting with the other modes.

### Paint mode
![paint mode](snap1.png)

The program starts in this mode. The cursor is a small or medium non-blinking square. It reflects the selected brush size and paint color.

Buttons:
* up/down/left/right: move cursor (hold down to move repeatedly)
* start: toggle between small and large brush
* B: increment paint color (there are four colors per subpalette)
* A: paint at cursor using selected color and brush (can be held down while moving the cursor)
* select: switch to attribute edit mode

Note: The cursor is invisible if it is on a pixel of the same color or at the very top of the screen. Depending on your screen, the cursor may also disappear near the top or bottom of the screen.

Hint: to move long distances faster, switch to the large brush.

### Attribute edit mode
![attribute edit mode](snap2.png)

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
![palette edit mode](snap3.png)

The palette editor is a black window at the bottom right corner of the screen.

Indicators:
* `P`: number of subpalette being edited (`0`&ndash;`3`)
* `C`: NES color number of selected color in hexadecimal (`00`&ndash;`3F`); the first digit roughly corresponds to brightness (dark/light) and the second one to hue (red/green/etc.)
* colored squares: colors in selected subpalette (topmost = first)
* blinking cursor: highlights the color being edited

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
* name table mirroring: does not matter
* compatibility: NTSC &amp; PAL

## To do
* test with other emulators
* a Python script to convert an image file into an FCEUX movie that draws the image
* paint cursor should accelerate
