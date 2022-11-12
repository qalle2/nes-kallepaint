# Note: this script will DELETE files. Use at your own risk.
rm -f *.bin
python3 chr-bg-gen.py chr-bg.bin
python3 ../nes-util/nes_chr_encode.py chr-spr.png chr-spr.bin
python3 png2fm2.py convtest1.png > convtest1.fm2
python3 png2fm2.py convtest2.png > convtest2.fm2
asm6 paint.asm paint.nes
gzip -9fk *.bin *.fm2 *.nes
