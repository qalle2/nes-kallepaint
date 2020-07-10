"""Convert the Kalle Paint logo from PNG into binary data (NES tile indexes).
Grayscale 0x00 -> NES color 0
Grayscale 0x55 -> NES color 1
Grayscale 0xaa -> NES color 2
Grayscale 0xff -> NES color 3"""

import os
import sys
from PIL import Image  # Pillow

def encode_image(img):
    """Read 64*6 PNG pixels, convert them into 2-bit NES colors, convert them into 3*32 bytes
    (NES tile indexes).
    1 byte = 2*2 pixels:
        - bits: AaBbCcDd
        - pixels: Aa = upper left, Bb = upper right, Cc = lower left, Dd = lower right
        - capital letter = MSB, small letter = LSB
    img: Pillow image
    yield: 32 bytes per call"""

    encoded = bytearray()  # row of encoded bytes

    # encode 3*32 hexadecimal bytes (64*6 pixels)
    for bi in range(3 * 32):  # target byte index (bits: YYX XXXX)
        # encode 1 byte (2*2 pixels)
        byte = 0
        for pi in range(4):  # source pixel index (bits: yx)
            y = bi >> 4 & 0x06 | pi >> 1  # bits: YYy
            x = bi << 1 & 0x3e | pi & 1   # bits: XX XXXx
            byte = byte << 2 | img.getpixel((x, y)) // 0x55
        encoded.append(byte)
        if bi & 0x1f == 0x1f:
            yield encoded
            encoded.clear()

def main():
    """The main function."""

    # read args
    if len(sys.argv) != 3:
        sys.exit("Args: sourceFile targetFile")
    (sourceFile, targetFile) = (sys.argv[1], sys.argv[2])

    # validate args
    if not os.path.isfile(sourceFile):
        sys.exit(f"{sourceFile} not found.")
    if os.path.exists(targetFile):
        sys.exit(f"{targetFile} already exists.")

    # convert image
    try:
        with open(sourceFile, "rb") as source:
            source.seek(0)
            img = Image.open(source)
            if img.width != 64 or img.height != 6 or img.mode != "L":
                sys.exit("The image must be 64*6 pixels and grayscale.")
            with open(targetFile, "wb") as target:
                target.seek(0)
                for row in encode_image(img):
                    target.write(row)
    except OSError:
        sys.exit("Error reading/writing files.")

    print(f"{targetFile} written.")

if __name__ == "__main__":
    main()

