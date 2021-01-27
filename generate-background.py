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

def chr_byte(tileIndex, leftPos, rightPos):
    """leftPos/rightPos: bit position to extract left/right half from
    return: NES CHR byte (8*1 pixels, 1 bitplane)"""

    return (((tileIndex >> leftPos) & 1) * 0xf0) | (((tileIndex >> rightPos) & 1) * 0x0f)

def main():
    if len(sys.argv) != 2:
        sys.exit("Argument: output_file")
    fileName = sys.argv[1]
    if os.path.exists(fileName):
        sys.exit("File already exists.")

    data = bytearray()
    for tileIndex in range(0x100):
        # top/bottom half of less significant bitplane
        data += 4 * bytes((chr_byte(tileIndex, 6, 4),))
        data += 4 * bytes((chr_byte(tileIndex, 2, 0),))
        # top/bottom half of more significant bitplane
        data += 4 * bytes((chr_byte(tileIndex, 7, 5),))
        data += 4 * bytes((chr_byte(tileIndex, 3, 1),))

    with open(fileName, "wb") as target:
        target.seek(0)
        target.write(data)

    print(f"{fileName} written.")

if __name__ == "__main__":
    main()
