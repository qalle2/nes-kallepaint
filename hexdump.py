with open("paint.nes", "rb") as h:
    h.seek(-0x800, 2)
    d = h.read()
for i in range(0, len(d), 32):
    print(d[i:i+32].hex())
