# Note: this script will DELETE files. Use at your own risk.

rm -f *.cdl *.gz *.nes *.nl
asm6 paint.asm paint.nes
gzip --best -k *.nes
