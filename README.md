# Kalle Paint
A paint program for the [NES](https://en.wikipedia.org/wiki/Nintendo_Entertainment_System). Written in 6502 assembly. Assembles with [ASM6](https://github.com/qalle2/asm6/) (probably with [ASM6f](https://github.com/freem/asm6f) too). Tested on FCEUX and Mednafen.

## Table of contents
* [Files](#files)
* [How to assemble](#how-to-assemble)
* [Features](#features)
* [How to use](#how-to-use)
** [Paint mode](#paint-mode)
** [Attribute edit mode](#attribute-edit-mode)
** [Palette edit mode](#palette-edit-mode)
* [Technical info](#technical-info)
* [Hexadecimal source](#hexadecimal-source)
* [To do](#to-do)

## Files
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
There are three modes. Press select at any time to cycle between them.

### Paint mode
![paint mode](snap1.png)

The program starts in this mode. The cursor reflects the selected brush size and paint color.

Buttons:
* up/down/left/right: move cursor (hold down to move repeatedly)
* start: toggle between small and large brush (1&times;1 pixels and 2&times;2 pixels)
* B: change paint color (0 &rarr; 1 &rarr; 2 &rarr; 3 &rarr; 0)
* A: paint at cursor using selected color and brush
* select: switch to attribute edit mode

Note: the cursor is invisible if it is on a pixel of the same color.

Hint: to move long distances faster, switch to the large brush.

### Attribute edit mode
![attribute edit mode](snap2.png)

This mode looks like the paint mode except that the cursor is a large blinking square (4&times;4 pixels).

Buttons:
* up/down/left/right: move cursor
* B/A: decrement/increment subpalette at cursor (0/1/2/3)
* select: switch to palette edit mode

Note: changing the subpalette has no visible effect if the selected square only contains the first color of a subpalette. (That color is shared between all subpalettes.)

### Palette edit mode
![palette edit mode](snap3.png)

The palette editor is a small black window at the bottom right corner of the screen.

Indicators:
* `P`: number of subpalette being edited (`0`&ndash;`3`)
* `C`: NES color number of selected color in hexadecimal (`00`&ndash;`3F`); the first digit roughly corresponds to brightness (dark/light) and the second one to hue (red/green/etc.)
* colored squares: colors in selected subpalette
* blinking cursor: highlights the color being edited

Buttons:
* start: increment subpalette (0 &rarr; 1 &rarr; 2 &rarr; 3 &rarr; 0)
* up/down: move cursor
* left/right: decrement/increment ones of color number
* B/A: decrement/increment 16s of color number
* select: switch to paint mode

Note: the first (topmost) color is shared between all subpalettes.

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
78d8a2408e1740a2ff9ae88e00208e01208e10408e154020dbf8a900aa95009d
00029d00039d00049d0005e8d0efa20fbde4f89530ca10f8a25fbd04f99d0006
ca10f7a204a03f20b0fca91e854da91a854ee64c20dbf8a03f20bdfcaabde4f8
8d0720e8e020d0f5a02020bdfca004aa8d0720e8d0fa88d0f62c0220a00020bd
fc8d0520a9f88d052020dbf8a9888d0020a91e8d0120244510fc4645a5468547
a9018d164085464a8d1640ad16402903c901264690f5a93f8500a9138510a20f
a54f2910f002a2308620a9008548e64f2064f9a648a9009501f0bb2c02202c02
2010fb600f1525350f1828380f1b2b3b0f1222320f0f0f150f0f15300f0f2500
0f0f3500ff100000ff120000ff124000ff128000ff12c000ff1100e8af1401e0
af1501e8af0001f0b70c01e0b70001e8b70001f0bf1600e8c71601e8cf1602e8
d71603e8bf1301e0bf1301f0c71301e0c71301f0cf1301e0cf1301f0d71301e0
d71301f0a644bd6ff948bd72f94860f9fafb74b6b5a5472970d03ea5462920f0
14a9ff8d0006a93c254d854da93c254e854ee64460a5462940f008a64ce88a29
03854ca5462910f010a54b4901854bf008464d064d464e064ea546290fd00485
4af04da54af004c64a1045a5464ab0054ab0099010a54d38654b1005a54d18e5
4b293f854da5464a4a4ab0054ab00f901ba54e38654bc938d010a900f00ca54e
18e54b1005a93818e54b854ea90a854aa54d0a0a8d0306a54e0a0a69078d0006
a64bbdadfa8d0106a64cf0192082fb2070fba000b142e000f0044acad0fc2903
0a0a054caab53048e648a648a93f9500a9139510689520a5462980f04fa54e4a
484a4a4a85416829074a6a6a054d6a85402097fba54bf008a64cbdaffa4ca5fa
a000b14248a54d4aa54e2a2903aabdb3fa49ff8549a44cb9affa3db3faaa6825
4986490549a000914220a3fb6010110055aaffc0300c03a547f0034c41fba546
2920f018a204a00420b0fcbd04f99d0006e8e8e8e8e060d0f2e64460a54629c0
f0252082fb2070fba000b142483d68fb244610060af007e810040ad001e8685d
68fb914220a3fba5464ab0054ab008900ea54d69039004a54de904293f854da5
464a4a4ab0054ab00e9016a54e6903c938d00ca900f008a54ee9041002a93485
4ea54d0a0a8d07068d0f0669088d0b068d1306a54e0a0a69078d04068d080669
088d0c068d1006600103040c103040c0a54e29044aaaa54d2904c9048a69000a
aa60a9038541a54e29388549a54d4a4a4a054909c08540a5408542a902186541
85436048e648a648a92005419500a540951068952060a547d076a5464ab03c4a
b0414ab0264ab0284ab0164ab0074ab051d045f05ba214a01320b0fca9008544
60a5516900290385511045a650e81003a650ca8a29038550aa103520a4fcb430
c8100620a4fcb4308898290f8549b530293005499530101820a4fcb530186910
100820a4fcb53038e910293f95301000a5518d2106a5500a0a0a69bf8d140620
a4fcb5304a4a4a4a8d2906b530290f8d2d0620a4fc48a648a93f9501689511a8
b930009521a93f9502a9129512a5309522a5510a0aa8a93f9503a9169513b931
009523a93f9504a91a9514b932009524a93f9505a91e9515b9330095258a1869
05854860a550f006a5510a0a0550aa60a9ff9d0006e8e8e8e888d0f660a9008c
06208d062060488a4898482c0220a9008d0320a9068d1440a200b400f00eb510
20bffcb5208d0720e84cdafca000840020bdfc8d0520a9f88d052038664568a8
68aa6840
```

Python commands used to create the listing above:
```
f=open("paint.nes","rb"); f.seek(0x3810); d=f.read(0x800); f.close()
for i in range(0,len(d),32): print(d[i:i+32].hex())
```

## To do
* test with other emulators
* a Python script to convert an image file into an FCEUX movie that draws the image
