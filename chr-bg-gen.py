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

import os, sys

def generate_bytes():
    for i in range(0x100):  # tile index
        yield (i >> 6 & 1) * 0xf0 | (i >> 4 & 1) * 0x0f
        yield (i >> 2 & 1) * 0xf0 | (i      & 1) * 0x0f
        yield (i >> 7 & 1) * 0xf0 | (i >> 5 & 1) * 0x0f
        yield (i >> 3 & 1) * 0xf0 | (i >> 1 & 1) * 0x0f

def main():
    if len(sys.argv) != 2:
        sys.exit("Argument: output file (will be overwritten)")

    data = bytearray()
    for byte in generate_bytes():
        data += 4 * bytes((byte,))

    with open(sys.argv[1], "wb") as target:
        target.seek(0)
        target.write(data)

main()
