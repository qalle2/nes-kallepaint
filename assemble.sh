# Note: this script will DELETE files. Use at your own risk.
rm -f *.bin *.gz
python3 chr-bg-gen.py chr-bg.bin
python3 ../nes-util/nes_chr_encode.py chr-spr.png chr-spr.bin
asm6 paint.asm paint.nes
gzip -k9 *.bin *.nes
