# Note: this script will DELETE files. Use at your own risk.
rm -f chr-pt0.bin
python3 chr-pt0-gen.py chr-pt0.bin
python3 png2fm2.py convtest1.png > convtest1.fm2
python3 png2fm2.py convtest2.png > convtest2.fm2
asm6 paint.asm paint.nes
gzip -9fk *.bin *.fm2 *.nes
