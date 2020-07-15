# Kalle Paint
A paint program for the NES (Nintendo Entertainment System). Written in 6502 assembly. Only tested on FCEUX. Assembles with [asm6f](https://github.com/freem/asm6f). The binary files (`.bin`, `.nes`) are in `bin.zip`.

## How to assemble
First, get the `.bin` files. Just extract them from `bin.zip` or encode them using the Python scripts:
* Install Python 3.
* Copy `nes_chr_encode.py` and its dependencies from my [NES utilities](https://github.com/qalle2/nes-util) repository.
* Create `background.bin`: `python3 gfx/background.py background.bin`
* Create `sprites.bin`: `python3 nes_chr_encode.py gfx/sprites.png sprites.bin`

Then, assemble:
* Go to the `src` directory.
* Run `asm6f paint.asm ../paint.nes`

Note: the Linux script `assemble` is intended for my personal use. Don't run it before reading it.

## Features
* 64&times;56 "pixels" (4&times;4 actual pixels each)
* four colors at the same time (plus the GUI colors)
* palette editor
* 1&times;1-pixel or 2&times;2-pixel brush

## How to use
There are two modes.

### Paint mode
![paint mode](paint1.png)

The program starts in this mode.

Buttons:
* up/down/left/right: move cursor
* start: toggle between small (1&times;1-pixel) and large (2&times;2-pixel) brush
* B: cycle through four paint colors
* A: paint at cursor using selected color and brush
* select: enter palette editor

### Palette edit mode
![palette edit mode](paint2.png)

This mode also shows paint cursor coordinates (`x00`&hellip;`x63`, `y00`&hellip;`y55`).

Buttons:
* up/down: move cursor
* left/right: decrement/increment ones of color number
* B/A: decrement/increment 16s of color number
* select: return to paint mode

## Technical info
* mapper: NROM (iNES mapper number 0)
* PRG ROM: 1 KiB (padded to the end of 16 KiB because of iNES file format limitations)
* CHR ROM: 8 KiB
* name table mirroring: horizontal (does not really matter)
* save RAM: none
* compatibility: NTSC and PAL

