# Note: this script will DELETE files. Use at your own risk.
asm6 paint.asm paint.nes
rm -f *.gz
gzip -k9 *.nes
