# convert a PNG image into an FM2 movie that draws the image in Qalle Paint

import collections, itertools, os, sys
from PIL import Image  # Pillow, https://python-pillow.org

# NES master palette
# key=index, value=(red, green, blue); source: FCEUX (fceux.pal)
# colors omitted (hexadecimal): 0d-0e, 1d-20, 2d-2f, 3d-3f
NES_PALETTE = {
    0x00: (0x74, 0x74, 0x74),
    0x01: (0x24, 0x18, 0x8c),
    0x02: (0x00, 0x00, 0xa8),
    0x03: (0x44, 0x00, 0x9c),
    0x04: (0x8c, 0x00, 0x74),
    0x05: (0xa8, 0x00, 0x10),
    0x06: (0xa4, 0x00, 0x00),
    0x07: (0x7c, 0x08, 0x00),
    0x08: (0x40, 0x2c, 0x00),
    0x09: (0x00, 0x44, 0x00),
    0x0a: (0x00, 0x50, 0x00),
    0x0b: (0x00, 0x3c, 0x14),
    0x0c: (0x18, 0x3c, 0x5c),
    0x0f: (0x00, 0x00, 0x00),
    0x10: (0xbc, 0xbc, 0xbc),
    0x11: (0x00, 0x70, 0xec),
    0x12: (0x20, 0x38, 0xec),
    0x13: (0x80, 0x00, 0xf0),
    0x14: (0xbc, 0x00, 0xbc),
    0x15: (0xe4, 0x00, 0x58),
    0x16: (0xd8, 0x28, 0x00),
    0x17: (0xc8, 0x4c, 0x0c),
    0x18: (0x88, 0x70, 0x00),
    0x19: (0x00, 0x94, 0x00),
    0x1a: (0x00, 0xa8, 0x00),
    0x1b: (0x00, 0x90, 0x38),
    0x1c: (0x00, 0x80, 0x88),
    0x21: (0x3c, 0xbc, 0xfc),
    0x22: (0x5c, 0x94, 0xfc),
    0x23: (0xcc, 0x88, 0xfc),
    0x24: (0xf4, 0x78, 0xfc),
    0x25: (0xfc, 0x74, 0xb4),
    0x26: (0xfc, 0x74, 0x60),
    0x27: (0xfc, 0x98, 0x38),
    0x28: (0xf0, 0xbc, 0x3c),
    0x29: (0x80, 0xd0, 0x10),
    0x2a: (0x4c, 0xdc, 0x48),
    0x2b: (0x58, 0xf8, 0x98),
    0x2c: (0x00, 0xe8, 0xd8),
    0x30: (0xfc, 0xfc, 0xfc),
    0x31: (0xa8, 0xe4, 0xfc),
    0x32: (0xc4, 0xd4, 0xfc),
    0x33: (0xd4, 0xc8, 0xfc),
    0x34: (0xfc, 0xc4, 0xfc),
    0x35: (0xfc, 0xc4, 0xd8),
    0x36: (0xfc, 0xbc, 0xb0),
    0x37: (0xfc, 0xd8, 0xa8),
    0x38: (0xfc, 0xe4, 0xa0),
    0x39: (0xe0, 0xfc, 0xa0),
    0x3a: (0xa8, 0xf0, 0xbc),
    0x3b: (0xb0, 0xfc, 0xcc),
    0x3c: (0x9c, 0xfc, 0xf0),
}

# default palette in Qalle Paint
DEFAULT_PALETTE = (
    (0x0f, 0x15, 0x25, 0x35),
    (0x0f, 0x18, 0x28, 0x38),
    (0x0f, 0x1b, 0x2b, 0x3b),
    (0x0f, 0x12, 0x22, 0x32),
)
# default cursor position in Qalle Paint
DEFAULT_CURSOR_POS = (32, 28)

# see https://fceux.com/web/FM2.html
FM2_HEADER = """\
version 3
emuVersion 20500
rerecordCount 0
palFlag 0
romFilename foo
romChecksum base64:AAAAAAAAAAAAAAAAAAAAAA==
guid 00000000-0000-0000-0000-000000000000
fourscore 0
microphone 0
port0 1
port1 0
port2 0
FDS 0
NewPPU 1
RAMInitOption 0
RAMInitSeed 569937536"""

def color_diff(rgb1, rgb2):
    # get difference (0-768) of two colors (red, green, blue)
    return sum(abs(comp[0] - comp[1]) for comp in zip(rgb1, rgb2))

def closest_nes_color(rgb):
    # get best match (NES color number) for color (red, green, blue)
    minDiff = min(color_diff(NES_PALETTE[i], rgb) for i in NES_PALETTE)
    return [
        i for i in sorted(NES_PALETTE)
        if color_diff(NES_PALETTE[i], rgb) == minDiff
    ][0]

def get_palette(image):
    # get color indexes and their best NES equivalents from the image:
    # {pngIndex: nesColor, ...}

    if image.width != 64 or image.height != 60 or image.mode != "P":
        sys.exit("Image must be 64*60 pixels and have a palette.")

    usedColors = image.getcolors(13)  # [(count, index), ...] or None
    if usedColors is None:
        sys.exit("Image has more than 13 unique colors.")
    usedColors = [c[1] for c in usedColors]

    # get best NES equivalents: {pngIndex: nesColor, ...}
    palette = image.getpalette()  # [R, G, B, ...]
    palette = dict(
        (i, closest_nes_color(palette[i*3:(i+1)*3])) for i in usedColors
    )
    if len(set(palette.values())) < len(palette):
        sys.exit("More than one PNG color maps to same NES color.")

    return palette

def create_subpalettes(colorSets):
    # split sets of color indexes into subpalettes
    # colorSets: set of sets of color indexes in attribute blocks
    # return: list of 4 subpalettes (sets) with up to 3 color indexes each
    # TODO: speed this up

    # delete sets that are a subset of another set
    colorSets = {
        s1 for s1 in colorSets
        if not any(s1.issubset(s2) and s1 != s2 for s2 in colorSets)
    }

    # try all permutations
    for colorSetsPerm in itertools.permutations(colorSets):
        subpals = [set() for i in range(4)]
        success = True
        for colorSet in colorSetsPerm:
            # get maximum number of common colors with a subpalette in which
            # the new colors fit
            try:
                maxCnt = max(
                    len(s & colorSet) for s in subpals
                    if len(s | colorSet) <= 3
                )
            except ValueError:
                success = False
                break
            # which subpalette was it (first one if several)
            bestSubpal = [
                i for (i, s) in enumerate(subpals)
                if len(s & colorSet) == maxCnt and len(s | colorSet) <= 3
            ][0]
            # add colors there
            subpals[bestSubpal].update(colorSet)
        if success:
            break

    if not success:
        sys.exit("Couldn't arrange colors into subpalettes.")

    return subpals

def get_color_sets(image):
    # generate attribute blocks as sets of PNG color indexes
    # (each PNG pixel will be 4*4 NES pixels)
    for y in range(0, 15 * 4, 4):
        for x in range(0, 16 * 4, 4):
            yield frozenset(image.crop((x, y, x + 4, y + 4)).getdata())

def generate_at_data(image, subpals, bgIndex):
    # generate AT data (int 0-3 for each attribute block)
    subpals = [sp | {bgIndex} for sp in subpals]
    yield from (
        [i for i in range(4) if subpals[i].issuperset(colorSet)][0]
        for colorSet in get_color_sets(image)
    )

def generate_pixels(image, attrData, palette, subpalsNes):
    # generate pixels as 2-bit ints
    for (i, pixel) in enumerate(image.getdata()):
        # get subpalette for this pixel (bits: YYYYyyXXXXxx -> YYYYXXXX)
        subpal = attrData[(i >> 4) & 0b1111_0000 | (i >> 2) & 0b1111]
        # convert PNG indexes to subpalette indexes
        yield subpalsNes[subpal].index(palette[pixel])

def process_image(image):
    palette = get_palette(image)  # {pngIndex: nesColor, ...}

    # get the PNG index of the color that appears in the largest number of
    # attribute blocks
    bgIndex = collections.Counter(itertools.chain.from_iterable(
        get_color_sets(image)
    )).most_common(1)[0][0]
    print(f"BG color (NES): ${palette[bgIndex]:02x}", file=sys.stderr)

    # get unique sets of color indexes in attribute blocks
    colorSets = {frozenset(s - {bgIndex}) for s in get_color_sets(image)}
    if max(len(s) for s in colorSets) > 3:
        sys.exit("Too many colors per attribute block.")

    # split sets of color indexes into subpalettes
    subpals = create_subpalettes(colorSets)

    # convert subpalettes into NES colors and pad with background color
    subpalsNes = [
        [palette[bgIndex]]
        + sorted(palette[c] for c in sp) + (3 - len(sp)) * [palette[bgIndex]]
        for sp in subpals
    ]

    # get attribute data using subpalettes
    attrData = list(generate_at_data(image, subpals, bgIndex))

    # get pixel data using subpalettes
    pixels = list(generate_pixels(image, attrData, palette, subpalsNes))

    return (subpalsNes, attrData, pixels)

def fm2_line(buttons=""):
    # format FM2 line (buttons pressed on controller 1)
    # none: "|0|........|||"
    # all:  "|0|RLDUTSBA|||" (T = start)
    buttons2 = "".join((b if b in buttons else ".") for b in "RLDUTSBA")
    return "|0|" + buttons2 + "|||"

def smallest_of_most_common(items):
    # return smallest of most common items; e.g. (2, 2, 1, 1, 0) -> 1
    maxCnt = max(items.count(i) for i in set(items))
    return sorted(i for i in set(items) if items.count(i) == maxCnt)[0]

def generate_program_paint(pixels):
    # generate button presses for FM2 program while in paint mode

    yield "T"  # big cursor

    # go to upper left corner
    yield from DEFAULT_CURSOR_POS[0] // 2 * "L"
    yield from DEFAULT_CURSOR_POS[1] // 2 * "U"

    cursColor = 1  # current cursor (paint) color (0-3)

    # paint 2*2-pixel blocks
    for y in range(0, 60, 2):
        for x in range(0, 64, 2):
            # get colors of pixels in block (TL, TR, BL, BR)
            pixelColors \
            = pixels[y*64+x:y*64+x+2] + pixels[(y+1)*64+x:(y+1)*64+x+2]
            # get the smallest one of the most common colors (faster than
            # using the most common color that occurs first)
            blockColor = smallest_of_most_common(pixelColors)
            # paint the block with its most common color
            if blockColor != 0:
                yield from (blockColor - cursColor) % 4 * "B"
                yield "A"
                cursColor = blockColor
            # if all pixels are not the same, paint them individually
            if len(set(pixelColors)) > 1:
                yield "T"  # small cursor
                i = 0
                while True:
                    if pixelColors[i] != blockColor:
                        # paint pixel
                        yield from (pixelColors[i] - cursColor) % 4 * "B"
                        yield "A"
                        cursColor = pixelColors[i]
                    # pixels are visited in this order: 0, 1, 2, 3
                    if (i == 0 or i == 2) and pixelColors[i+1] != blockColor:
                        i += 1
                        yield "R"  # right
                    elif i == 1 and pixelColors[2] != blockColor:
                        i = 2
                        yield "DL"  # down & left
                    elif (i == 0 or i == 1) and pixelColors[i+2] != blockColor:
                        i += 2
                        yield "D"  # down
                    elif i == 0 and pixelColors[3] != blockColor:
                        i = 3
                        yield "DR"  # down & right
                    else:
                        break
                yield "T"  # big cursor
            yield "R"  # next block
        yield "D"  # next block row

    yield "T"  # small cursor

def generate_program_attr(attrData):
    # generate button presses for FM2 program while in attribute edit mode

    for y in range(15):
        for x in range(16):
            attr = attrData[y*16+x]
            if attr == 3:
                yield "B"
            else:
                yield from attr * "A"
            yield "R"  # right
        yield "D"  # down

def generate_program_palette(subpals):
    # generate button presses for FM2 program in palette edit mode

    for i in range(4):  # subpalette index
        for j in range(4):  # color index
            # only set BG color in first subpalette
            if i == 0 or j > 0:
                newColor = subpals[i][j]
                oldColor = DEFAULT_PALETTE[i][j]
                # sixteens
                diff = (newColor // 16 - oldColor // 16) % 4
                if diff == 3:
                    yield "B"
                else:
                    yield from diff * "A"
                # ones
                diff = (newColor % 16 - oldColor % 16) % 16
                if diff > 8:
                    yield from (16 - diff) * "L"
                else:
                    yield from diff * "R"
            yield "D"  # next color
        yield "T"  # next subpalette

def generate_program(subpals, attrData, pixels):
    # generate button presses for FM2 program

    # paint mode
    yield from generate_program_paint(pixels)
    # attribute edit mode
    yield "S"
    yield from generate_program_attr(attrData)
    # palette edit mode
    yield "S"
    yield from generate_program_palette(subpals)
    # paint mode
    yield "S"

def print_fm2(subpals, attrData, pixels):
    # print an FM2 file that inputs the image
    # program: strings of zero or more of "RLDUTSBA" (T = start)

    print(FM2_HEADER)

    # start-up delay (4 is the minimum)
    for i in range(6):
        print(fm2_line())

    for buttons in generate_program(subpals, attrData, pixels):
        print(fm2_line())
        print(fm2_line(buttons))

def main():
    if len(sys.argv) != 2:
        sys.exit(
            "Read a PNG image from file. Print an FM2 (FCEUX) movie that "
            "draws the image in Qalle Paint. Argument: filename"
        )

    with open(sys.argv[1], "rb") as handle:
        handle.seek(0)
        (subpals, attrData, pixels) = process_image(Image.open(handle))

    print_fm2(subpals, attrData, pixels)

main()
