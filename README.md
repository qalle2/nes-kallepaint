# Kalle Paint
A paint program for the [NES](https://en.wikipedia.org/wiki/Nintendo_Entertainment_System). Written in 6502 assembly. Assembles with [ASM6](https://github.com/qalle2/asm6/) (probably with [ASM6f](https://github.com/freem/asm6f) too). Tested on FCEUX and Mednafen.

Table of contents:
* [List of files](#list-of-files)
* [How to assemble](#how-to-assemble)
* [Features](#features)
* [How to use](#how-to-use)
  * [Paint mode](#paint-mode)
  * [Attribute edit mode](#attribute-edit-mode)
  * [Palette edit mode](#palette-edit-mode)
  * [Button summary](#button-summary)
* [Technical info](#technical-info)
* [Hexadecimal source](#hexadecimal-source)
* [To do](#to-do)

## List of files
* `assemble.sh`: Linux script that assembles the program (warning: deletes files)
* `chr-bg.bin.gz`: background CHR ROM data (gzip compressed)
* `chr-bg-gen.py`: Python script that generates background CHR ROM data
* `chr-spr.bin.gz`: sprite CHR ROM data (gzip compressed)
* `chr-spr.png`: sprites as an image
* `paint.asm`: source code (ASM6)
* `paint.nes.gz`: assembled program (iNES format, gzip compressed)
* `snap*.png`: screenshots

## How to assemble
* Get the background CHR data:
  * Either extract `chr-bg.bin.gz`&hellip;
  * &hellip;or run `python3 chr-bg-gen.py chr-bg.bin`
* Get the sprite CHR data:
  * Either extract `chr-spr.bin.gz`&hellip;
  * &hellip; or get `nes_chr_encode.py` and its dependencies from [my NES utilities](https://github.com/qalle2/nes-util) and run `python3 nes_chr_encode.py chr-spr.png chr-spr.bin`
* Assemble: run `asm6 paint.asm paint.nes`

## Features
* 64&times;56 pixels (4&times;4 hardware pixels each)
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

Note: the cursor is invisible if it is on a pixel of the same color.

Hint: to move long distances faster, switch to the large brush.

### Attribute edit mode
![attribute edit mode](snap2.png)

This mode looks like the paint mode except that the cursor is a large blinking square.

Buttons:
* up/down/left/right: move cursor
* B/A: decrement/increment subpalette at cursor (0/1/2/3)
* select: switch to palette edit mode
* start: unused

Note: changing the subpalette has no visible effect if the selected square only contains the first color of a subpalette. (That color is shared between all subpalettes.)

### Palette edit mode
![palette edit mode](snap3.png)

The palette editor is a black window at the bottom right corner of the screen.

Indicators:
* `P`: number of subpalette being edited (`0`&ndash;`3`)
* `C`: NES color number of selected color in hexadecimal (`00`&ndash;`3F`); the first digit roughly corresponds to brightness (dark/light) and the second one to hue (red/green/etc.)
* colored squares: colors in selected subpalette (topmost = first)
* blinking cursor: highlights the color being edited

Buttons:
* start: increment subpalette (0 &rarr; 1 &rarr; 2 &rarr; 3 &rarr; 0)
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
* mapper: NROM (iNES mapper number 0)
* PRG ROM: 16 KiB (only the last 2 KiB is actually used)
* CHR ROM: 8 KiB
* name table mirroring: vertical
* save RAM: none
* compatibility: NTSC and PAL

## Hexadecimal source
Assembled PRG ROM in hexadecimal, excluding unused space and interrupt vectors (may not be up to date):
```
78d8a2408e1740a2ff9ae88e00208e01208e10408e154020d6f8a900aa95009d
00029d00039d00049d0005e8d0efa20fbddff89500ca10f8a25fbdfff89d0006
ca10f7a204a03f208ffca91e852fa91a8530e62e20d6f8a03f209cfcaabddff8
8d0720e8e020d0f5a020209cfca004aa8d0720e8d0fa88d0f62c0220a000209c
fc8d0520a9f88d052020d6f8a9888d0020a91e8d0120242710fc4627a5288529
a9018d164085284a8d1640ad16402903c901262890f5a93f8510a9138516a20f
a5312910f002a230861ca901852ae631205ff94c96f82c02202c022010fb600f
1525350f1828380f1b2b3b0f1222320f0f0f150f0f15300f0f25000f0f3500ff
100000ff120000ff124000ff128000ff12c000ff1100e8af1401e0af1501e8af
0001f0b70c01e0b70001e8b70001f0bf1600e8c71601e8cf1602e8d71603e8bf
1301e0bf1301f0c71301e0c71301f0cf1301e0cf1301f0d71301e0d71301f0a6
26bd6af948bd6df94860f9fafb6fadaaa5292970d03ea5282920f014a9ff8d00
06a93c252f852fa93c25308530e62660a5282940f008a62ee88a2903852ea528
2910f010a52d4901852df008462f062f46300630a528290fd004852cf04da52c
f004c62c1045a5284ab0054ab0099010a52f38652d1005a52f18e52d293f852f
a5284a4a4ab0054ab00f901ba53038652dc938d010a900f00ca53018e52d1005
a93818e52d8530a90a852ca52f0a0a8d0306a5300a0a69078d0006a62dbda4fa
8d0106a62ef0192079fb2067fba000b124e000f0044acad0fc29030a0a052eaa
b500851da93f8511a9138517e62aa5282980f04fa5304a484a4a4a8523682907
4a6a6a052f6a8522208efba52df008a62ebda6fa4c9cfaa000b12448a52f4aa5
302a2903aabdaafa49ff852ba42eb9a6fa3daafaaa68252b862b052ba0009124
209afb6010110055aaffc0300c03a529f0034c38fba5282920f018a204a00420
8ffcbdfff89d0006e8e8e8e8e060d0f2e62660a52829c0f0252079fb2067fba0
00b124483d5ffb242810060af007e810040ad001e8685d5ffb9124209afba528
4ab0054ab008900ea52f69039004a52fe904293f852fa5284a4a4ab0054ab00e
9016a5306903c938d00ca900f008a530e9041002a9348530a52f0a0a8d07068d
0f0669088d0b068d1306a5300a0a69078d04068d080669088d0c068d10066001
03040c103040c0a53029044aaaa52f2904c9048a69000aaa60a9038523a53029
38852ba52f4a4a4a052b09c08522a5228524a902186523852560a62a951ca920
05239510a5229516e62a60a529d076a5284ab03c4ab0414ab0264ab0284ab016
4ab0074ab051d045f05ba214a013208ffca900852660a5336900290385331045
a632e81003a632ca8a29038532aa10352083fcb400c810062083fcb400889829
0f852bb5002930052b950010182083fcb50018691010082083fcb50038e91029
3f95001000a5338d2106a5320a0a0a69bf8d14062083fcb5004a4a4a4a8d2906
b500290f8d2d06a93fa2049511ca10fb2083fcb500851d8617a500851ea91285
18a5330a0aaab501851fa9168519b5028520a91a851ab5038521a91e851ba906
852a60a532f006a5330a0a0532aa60a9ff9d0006e8e8e8e888d0f660a9008c06
208d062060488a4898482c0220a9008d0320a9068d1440a2ffe8e42af00fb410
b516209efcb51c8d07204cb9fca000209cfc8d0520a9f88d052038662768a868
aa6840
```

Python commands used to create the listing above:
```
f=open("paint.nes","rb"); f.seek(0x3810); d=f.read(0x800); f.close()
for i in range(0,len(d),32): print(d[i:i+32].hex())
```

## To do
* test with other emulators
* a Python script to convert an image file into an FCEUX movie that draws the image
