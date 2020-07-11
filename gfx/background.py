"""Generate background CHR ROM data for Kalle Paint.
- 256 tiles
- 4 KiB
- all combinations of 2*2 subpixels * 4 colors
- bits of tile index: AaBbCcDd
    - Aa = top left subpixel
    - Bb = top right subpixel
    - Cc = bottom left subpixel
    - Dd = bottom right subpixel
    - capital letter = MSB, small letter = LSB"""

import os
import sys

def CHR_byte(i, lPos, rPos):
    """i: tile index
    lPos: bit position to extract left half from
    rPos: bit position to extract right half from
    return: NES CHR byte (8*1 pixels, 1 bitplane)"""

    return (i >> lPos & 1) * 0xf0 | (i >> rPos & 1) * 0x0f

def main():
    # read args
    if len(sys.argv) != 2:
        sys.exit("Arg: outputFile")
    targetFile = sys.argv[1]
    if os.path.exists(targetFile):
        sys.exit("Target file already exists.")

    # generate data
    data = bytearray()
    for i in range(256):  # tile index
        # less significant bitplane
        data += 4 * bytes((CHR_byte(i, 6, 4),))  # top half
        data += 4 * bytes((CHR_byte(i, 2, 0),))  # bottom half
        # more significant bitplane
        data += 4 * bytes((CHR_byte(i, 7, 5),))  # top half
        data += 4 * bytes((CHR_byte(i, 3, 1),))  # bottom half

    # write file
    with open(targetFile, "wb") as target:
        target.seek(0)
        target.write(data)

    print(f"{targetFile} written.")

if __name__ == "__main__":
    main()

