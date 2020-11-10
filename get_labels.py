"""Get PRG ROM labels from Lua symbol file (asm6f -f)."""

def get_labels(handle):
    """Read file, yield one (address, label) per call.
    Each line: e.g. 'label = 0xffff'"""

    handle.seek(0)
    for line in handle:
        (label, addr) = line.rstrip().split(" = ")
        addr = int(addr, 16)
        if addr <= 0xffff and not label.startswith("_"):
            yield (addr, label)

def main():
    # get labels from file
    with open("paint.lua", "rt", encoding="ascii") as handle:
        labels = dict(get_labels(handle))

    # print labels sorted by address
    for addr in sorted(labels):
        print(f"${addr:04x}: {labels[addr]}")

if __name__ == "__main__":
    main()

