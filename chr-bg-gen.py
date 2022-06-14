"""
Generate background CHR ROM data for Kalle Paint.

- 4 KiB, 256 tiles, all combinations of 2*2 subpixels and 4 colors
- bits of tile index: %AaBbCcDd:
    %Aa/%Bb = top    left/right subpixel
    %Cc/%Dd = bottom left/right subpixel
- to generate data:
    for %ab, %cd, %AB, %CD in each tile index:
      convert bit pair into byte as follows and write it 4 times:
      %00->$00, %01->$0f, %10->$f0, %11->$ff
  example: tile %10001011 = $00000000 $0f0f0f0f $f0f0f0f0 $ffffffff
"""

# TODO: do it in the manner described above

import os, sys

def chr_byte(i, l, r):
    # i: tile index, l/r: bit position to extract left/right half from
    # return: NES CHR byte (8*1 pixels, 1 bitplane)
    return (((i >> l) & 1) * 0xf0) | (((i >> r) & 1) * 0x0f)

def main():
    if len(sys.argv) != 2:
        sys.exit("Argument: output file (will be overwritten)")

    data = bytearray()
    for i in range(0x100):  # tile index
        data += 4 * bytes((chr_byte(i, 6, 4),))  # less significant bitplane, top    half
        data += 4 * bytes((chr_byte(i, 2, 0),))  # less significant bitplane, bottom half
        data += 4 * bytes((chr_byte(i, 7, 5),))  # more significant bitplane, top    half
        data += 4 * bytes((chr_byte(i, 3, 1),))  # more significant bitplane, bottom half

    with open(sys.argv[1], "wb") as target:
        target.seek(0)
        target.write(data)

main()
