# generate background CHR ROM data for Kalle Paint
# - 256 tiles
# - 4 KiB
# - all combinations of 2*2 subpixels and 4 colors
# - bits of tile index: AaBbCcDd
#     Aa = top    left  subpixel
#     Bb = top    right subpixel
#     Cc = bottom left  subpixel
#     Dd = bottom right subpixel
#     (capital letter = MSB, small letter = LSB)

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
