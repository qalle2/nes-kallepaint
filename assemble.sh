# Note: this script will DELETE files. Use at your own risk.

rm -f *.bin *.gz *.nes
python3 chr-background-generate.py chr-background.bin
python3 ../nes-util/nes_chr_encode.py chr-sprites.png chr-sprites.bin
asm6 paint.asm paint.nes
gzip --best -k *.bin *.nes
