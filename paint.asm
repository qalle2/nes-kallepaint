; Kalle Paint (NES, ASM6)
; Note: indentation = 16 spaces, maximum length of identifiers = 15 characters.

; --- Constants -----------------------------------------------------------------------------------

; Note: "VRAM buffer" = what to update in VRAM on next VBlank.

; RAM
vrambufhi       equ $00    ; VRAM buffer - high bytes of addresses (16 bytes; 0 = terminator)
vrambuflo       equ $10    ; VRAM buffer - low bytes of addresses (16 bytes)
vrambufval      equ $20    ; VRAM buffer - values (16 bytes)
userpal         equ $30    ; user palette (16 bytes; each $00-$3f; offsets 4/8/12 are unused)
vramoffs        equ $40    ; offset to name/attr table 0 and vramcopy (2 bytes, low first; 0-$3ff)
vramcpyaddr     equ $42    ; address in vramcopy (2 bytes, low first; vramcopy...vramcopy+$3ff)
mode            equ $44    ; program mode: 0 = paint, 1 = attribute editor, 2 = palette editor
runmain         equ $45    ; run main loop? (flag; only MSB is important)
padstatus       equ $46    ; first joypad status (bits: A, B, select, start, up, down, left, right)
prevpadstat     equ $47    ; first joypad status on previous frame
vrambufpos      equ $48    ; position of last byte written to VRAM buffer
temp            equ $49    ; temporary
delayleft       equ $4a    ; cursor move delay left (paint mode)
brushsize       equ $4b    ; cursor type (paint mode; 0=small, 1=big)
paintcolor      equ $4c    ; paint color (paint mode; 0-3)
cursorx         equ $4d    ; cursor X position (paint/attribute edit mode; 0-63)
cursory         equ $4e    ; cursor Y position (paint/attribute edit mode; 0-55)
blinktimer      equ $4f    ; cursor blink timer (attribute/palette editor)
paledcurpos     equ $50    ; cursor position (palette editor; 0-3)
paledsubpal     equ $51    ; selected subpalette (palette editor; 0-3)
sprdata         equ $0200  ; $100 bytes (see initsprdata for layout)
vramcopy        equ $0300  ; $400 bytes (copy of name/attribute table 0; must be at $xx00)

; memory-mapped registers; see https://wiki.nesdev.org/w/index.php/PPU_registers
ppuctrl         equ $2000
ppumask         equ $2001
ppustatus       equ $2002
oamaddr         equ $2003
ppuscroll       equ $2005
ppuaddr         equ $2006
ppudata         equ $2007
dmcfreq         equ $4010
oamdma          equ $4014
sndchn          equ $4015
joypad1         equ $4016
joypad2         equ $4017

; joypad bitmasks
pad_a           equ 1<<7  ; A
pad_b           equ 1<<6  ; B
pad_sl          equ 1<<5  ; select
pad_st          equ 1<<4  ; start
pad_u           equ 1<<3  ; up
pad_d           equ 1<<2  ; down
pad_l           equ 1<<1  ; left
pad_r           equ 1<<0  ; right

; default user palette
defcolorbg      equ $0f  ; background (all subpalettes)
defcolor0a      equ $15  ; reds
defcolor0b      equ $25
defcolor0c      equ $35
defcolor1a      equ $18  ; yellows
defcolor1b      equ $28
defcolor1c      equ $38
defcolor2a      equ $1b  ; greens
defcolor2b      equ $2b
defcolor2c      equ $3b
defcolor3a      equ $12  ; blues
defcolor3b      equ $22
defcolor3c      equ $32

; user interface colors
paledbgcol      equ $0f  ; palette editor background (black)
paledtxtcol     equ $30  ; palette editor text (white)
blinkcol1       equ $0f  ; blinking cursor 1 (black)
blinkcol2       equ $30  ; blinking cursor 2 (white)

; sprite tile indexes (note: hexadecimal digits "0"-"F" must start at $00)
smalcurtile     equ $10  ; small paint cursor
bigcurtile      equ $11  ; large paint cursor
attrcurtile     equ $12  ; corner of attribute cursor
covertile       equ $13  ; cover (palette editor)
paltile1        equ $14  ; left  half of "Pal" (palette editor)
paltile2        equ $15  ; right half of "Pal" (palette editor)
colindtile      equ $16  ; color indicator (palette editor)

; misc
blinkrate       equ 4      ; attribute/palette editor cursor blink rate (0=fastest, 7=slowest)
brushdelay      equ 10     ; paint cursor move repeat delay (frames)
vscroll         equ 256-8  ; PPU vertical scroll value (VRAM $2000 is at the top of visible area)

; --- iNES header ---------------------------------------------------------------------------------

                ; see https://wiki.nesdev.org/w/index.php/INES
                base $0000
                db "NES", $1a            ; file id
                db 1, 1                  ; 16 KiB PRG ROM, 8 KiB CHR ROM
                db %00000001, %00000000  ; NROM mapper, vertical name table mirroring
                pad $0010, $00           ; unused

; --- Start of PRG ROM ----------------------------------------------------------------------------

                ; only use last 2 KiB of CPU address space
                base $c000
                pad $f800, $ff

; --- Initialization and main loop ----------------------------------------------------------------

reset           ; initialize the NES; see https://wiki.nesdev.org/w/index.php/Init_code
                sei             ; ignore IRQs
                cld             ; disable decimal mode
                ldx #%01000000
                stx joypad2     ; disable APU frame IRQ
                ldx #$ff
                txs             ; initialize stack pointer
                inx
                stx ppuctrl     ; disable NMI
                stx ppumask     ; disable rendering
                stx dmcfreq     ; disable DMC IRQs
                stx sndchn      ; disable sound channels

                bit ppustatus   ; wait until next VBlank starts
-               bit ppustatus
                bpl -

                lda #$00             ; clear zero page and vramcopy
                tax
-               sta $00,x
                sta vramcopy,x
                sta vramcopy+$100,x
                sta vramcopy+$200,x
                sta vramcopy+$300,x
                inx
                bne -

                ldx #(16-1)        ; init user palette
-               lda initpalette,x
                sta userpal,x
                dex
                bpl -

                ldx #(24*4-1)      ; init sprite data
-               lda initsprdata,x
                sta sprdata,x
                dex
                bpl -

                ldx #(1*4)       ; hide sprites except paint cursor (#0)
                ldy #63
                jsr hidesprites  ; X = first byte index, Y = count

                lda #30         ; init misc vars
                sta cursorx
                lda #26
                sta cursory
                inc paintcolor

                bit ppustatus      ; wait until next VBlank starts
-               bit ppustatus
                bpl -

                lda #$3f           ; init PPU palette
                sta ppuaddr
                ldx #$00
                stx ppuaddr
-               lda initpalette,x
                sta ppudata
                inx
                cpx #32
                bne -

                lda #$20     ; clear name/attribute table 0 ($400 bytes)
                sta ppuaddr
                lda #$00
                sta ppuaddr
                ldy #4
--              tax
-               sta ppudata
                inx
                bne -
                dey
                bne --

                bit ppustatus  ; reset ppuaddr/ppuscroll latch
                lda #$00       ; reset PPU address and set scroll
                sta ppuaddr
                sta ppuaddr
                sta ppuscroll
                lda #vscroll
                sta ppuscroll

                bit ppustatus   ; wait until next VBlank starts
-               bit ppustatus
                bpl -

                lda #%10001000  ; NMI, 8*8-px sprites, pattern table 0 for BG and 1 for sprites,
                sta ppuctrl     ; 1-byte VRAM address auto-increment, name table 0

                lda #%00011110  ; show BG & sprites on entire screen,
                sta ppumask     ; don't use R/G/B de-emphasis or grayscale mode

mainloop        bit runmain      ; the main loop
                bpl mainloop     ; wait until NMI routine has run
                lsr runmain      ; prevent main loop from running until after next NMI
                lda padstatus    ; store previous joypad status
                sta prevpadstat

                lda #$01        ; read first joypad or Famicom expansion port controller
                sta joypad1     ; see https://www.nesdev.org/wiki/Controller_reading_code
                sta padstatus   ; init joypads; set LSB of variable to detect end of loop
                lsr a
                sta joypad1
-               lda joypad1     ; read 8 buttons
                and #%00000011
                cmp #$01
                rol padstatus
                bcc -

                lda #$3f             ; tell NMI routine to update blinking cursor in VRAM
                sta vrambufhi+0
                lda #(4*4+3)
                sta vrambuflo+0
                ldx #blinkcol1
                lda blinktimer
                and #(1<<blinkrate)
                beq +
                ldx #blinkcol2
+               stx vrambufval+0
                lda #0               ; store pos of last byte written
                sta vrambufpos

                inc blinktimer  ; advance timer
                jsr jumpengine  ; run code for the program mode we're in

                ldx vrambufpos      ; append terminator to VRAM buffer
                lda #$00
                sta vrambufhi+1,x

                beq mainloop  ; unconditional

initpalette     ; initial palette
                ; background (also the initial user palette)
                db defcolorbg, defcolor0a, defcolor0b, defcolor0c
                db defcolorbg, defcolor1a, defcolor1b, defcolor1c
                db defcolorbg, defcolor2a, defcolor2b, defcolor2c
                db defcolorbg, defcolor3a, defcolor3b, defcolor3c
                ; sprites
                ; 2nd color in all subpalettes: palette editor background
                ; 3rd color in all subpalettes: selected colors in palette editor
                ; 4th color in 1st subpalette : all cursors
                ; 4th color in 2nd subpalette : palette editor text
                db defcolorbg, paledbgcol, defcolorbg,  defcolor0a
                db defcolorbg, paledbgcol, defcolor0a, paledtxtcol
                db defcolorbg, paledbgcol, defcolor0b,         $00
                db defcolorbg, paledbgcol, defcolor0c,         $00

initsprdata     ; initial sprite data (Y, tile, attributes, X for each sprite)
                ; paint mode
                db    $ff, smalcurtile, %00000000,    0  ; #0:  cursor
                ; attribute editor
                db    $ff, attrcurtile, %00000000,    0  ; #1:  cursor top left
                db    $ff, attrcurtile, %01000000,    0  ; #2:  cursor top right
                db    $ff, attrcurtile, %10000000,    0  ; #3:  cursor bottom left
                db    $ff, attrcurtile, %11000000,    0  ; #4:  cursor bottom right
                ; palette editor
                db    $ff,  bigcurtile, %00000000, 29*8  ; #5:  cursor
                db 22*8-1,    paltile1, %00000001, 28*8  ; #6:  left  half of "Pal"
                db 22*8-1,    paltile2, %00000001, 29*8  ; #7:  right half of "Pal"
                db 22*8-1,         $00, %00000001, 30*8  ; #8:  subpalette number
                db 23*8-1,         $0c, %00000001, 28*8  ; #9:  "C"
                db 23*8-1,         $00, %00000001, 29*8  ; #10: color number - 16s
                db 23*8-1,         $00, %00000001, 30*8  ; #11: color number - ones
                db 24*8-1,  colindtile, %00000000, 29*8  ; #12: color 0
                db 25*8-1,  colindtile, %00000001, 29*8  ; #13: color 1
                db 26*8-1,  colindtile, %00000010, 29*8  ; #14: color 2
                db 27*8-1,  colindtile, %00000011, 29*8  ; #15: color 3
                db 24*8-1,   covertile, %00000001, 28*8  ; #16: cover (to left  of color 0)
                db 24*8-1,   covertile, %00000001, 30*8  ; #17: cover (to right of color 0)
                db 25*8-1,   covertile, %00000001, 28*8  ; #18: cover (to left  of color 1)
                db 25*8-1,   covertile, %00000001, 30*8  ; #19: cover (to right of color 1)
                db 26*8-1,   covertile, %00000001, 28*8  ; #20: cover (to left  of color 2)
                db 26*8-1,   covertile, %00000001, 30*8  ; #21: cover (to right of color 2)
                db 27*8-1,   covertile, %00000001, 28*8  ; #22: cover (to left  of color 3)
                db 27*8-1,   covertile, %00000001, 30*8  ; #23: cover (to right of color 3)

jumpengine      ldx mode           ; jump engine (run one sub depending on program mode)
                lda jumptablehi,x  ; note: don't inline this sub
                pha                ; push target address minus one, high byte first
                lda jumptablelo,x
                pha
                rts                ; pull address, low byte first; jump to that address plus one

jumptablehi     dh paintmode-1, attreditor-1, paleditor-1  ; jump table - high bytes
jumptablelo     dl paintmode-1, attreditor-1, paleditor-1  ; jump table - low bytes

; --- Paint mode (code label prefix "pm") ---------------------------------------------------------

paintmode       lda prevpadstat  ; select/B/start logic
                and #(pad_sl|pad_b|pad_st)
                bne pmarrows     ; if any pressed on previous frame, ignore them all

                lda padstatus    ; if select pressed, switch to attribute editor
                and #pad_sl
                beq +
                lda #$ff         ; hide paint cursor sprite
                sta sprdata+0+0
                lda #%00111100   ; make cursor coordinates a multiple of four
                and cursorx
                sta cursorx
                lda #%00111100
                and cursory
                sta cursory
                inc mode         ; change program mode
                rts              ; return to main loop

+               lda padstatus    ; if B pressed, increment paint color (0-3)
                and #pad_b
                beq +
                ldx paintcolor
                inx
                txa
                and #%00000011
                sta paintcolor

+               lda padstatus    ; if start pressed, toggle brush size
                and #pad_st
                beq pmarrows
                lda brushsize
                eor #%00000001
                sta brushsize
                beq pmarrows
                lsr cursorx      ; if large brush, make coordinates even
                asl cursorx      ; note: not allowing the cursor to span multiple tiles makes
                lsr cursory      ; the paint logic a lot simpler
                asl cursory

pmarrows        lda padstatus    ; arrow logic
                and #(pad_u|pad_d|pad_l|pad_r)
                bne +
                sta delayleft    ; if none pressed, clear cursor move delay
                beq paintmode2   ; unconditional; ends with rts
+               lda delayleft    ; else if delay > 0, decrement it and exit
                beq +
                dec delayleft
                bpl paintmode2   ; unconditional; ends with rts

+               lda padstatus    ; check horizontal arrows
                lsr a
                bcs +
                lsr a
                bcs ++
                bcc pmcheckvert  ; unconditional
+               lda cursorx      ; right
                sec
                adc brushsize
                bpl +++          ; unconditional
++              lda cursorx      ; left
                clc
                sbc brushsize
+++             and #%00111111   ; store horizontal position
                sta cursorx

pmcheckvert     lda padstatus    ; check vertical arrows
                lsr a
                lsr a
                lsr a
                bcs +
                lsr a
                bcs ++
                bcc pmarrowend   ; unconditional
+               lda cursory      ; down
                sec
                adc brushsize
                cmp #56
                bne +++
                lda #0
                beq +++          ; unconditional
++              lda cursory      ; up
                clc
                sbc brushsize
                bpl +++
                lda #56
                clc
                sbc brushsize
+++             sta cursory      ; store vertical position

pmarrowend      lda #brushdelay  ; reinit cursor move delay
                sta delayleft

paintmode2      ; paint mode, part 2

                ; update cursor sprite
                lda cursorx        ; X pos
                asl a
                asl a
                sta sprdata+0+3
                lda cursory        ; Y pos
                asl a
                asl a
                adc #(8-1)         ; carry is always clear
                sta sprdata+0+0
                ldx brushsize      ; tile
                lda cursortiles,x
                sta sprdata+0+1

                ; tell NMI routine to update cursor color
                ldx paintcolor       ; color 0 is common to all subpalettes
                beq ++
                jsr attrvramofs      ; get vramoffs and vramcpyaddr
                jsr attrbitpos       ; 0/2/4/6 -> X
                ldy #0               ; read attribute byte
                lda (vramcpyaddr),y
                cpx #0               ; shift relevant bit pair to positions 1-0
                beq +
-               lsr a
                dex
                bne -
+               and #%00000011       ; clear other bits
                asl a                ; index to userpal -> X
                asl a
                ora paintcolor
                tax
++              lda userpal,x        ; cursor color -> A
                pha                  ; append to VRAM buffer
                inc vrambufpos
                ldx vrambufpos
                lda #$3f
                sta vrambufhi,x
                lda #(4*4+3)
                sta vrambuflo,x
                pla
                sta vrambufval,x

                lda padstatus  ; if A not pressed, we are done
                and #pad_a
                beq rtslabel

                ; edit one byte (tile) in vramcopy and tell NMI routine to update it to VRAM

                lda cursory     ; compute offset to vramcopy and VRAM $2000;
                lsr a           ; bits: cursory = 00ABCDEF, cursorx = 00abcdef,
                pha             ; -> vramoffs = 000000AB CDEabcde
                lsr a
                lsr a
                lsr a
                sta vramoffs+1
                pla
                and #%00000111
                lsr a
                ror a
                ror a
                ora cursorx
                ror a
                sta vramoffs+0

                jsr getvramcpad  ; get vramcpyaddr
                lda brushsize
                beq +

                ldx paintcolor    ; large brush -> replace entire byte (tile) with a solid color
                lda solidtiles,x
                jmp updatetile

+               ; small brush -> replace a bit pair (pixel) within the original byte
                ldy #0               ; original byte -> stack
                lda (vramcpyaddr),y
                pha
                lda cursorx          ; pixel position within tile (0-3) -> X
                lsr a
                lda cursory
                rol a
                and #%00000011
                tax
                lda pixelmasks,x     ; AND mask for clearing a bit pair -> temp
                eor #%11111111
                sta temp
                ldy paintcolor       ; OR mask for changing a cleared bit pair -> X
                lda solidtiles,y
                and pixelmasks,x
                tax
                pla                  ; pull original byte, clear bit pair and change it
                and temp
                stx temp
                ora temp

updatetile      ldy #0               ; update byte in vramcopy
                sta (vramcpyaddr),y
                jsr tovrambuf        ; tell NMI routine to update A to VRAM
rtslabel        rts                  ; return to main loop

cursortiles     db smalcurtile, bigcurtile                     ; brush size -> cursor tile
solidtiles      db %00000000, %01010101, %10101010, %11111111  ; tiles of solid color 0-3
pixelmasks      db %11000000, %00110000, %00001100, %00000011  ; bitmasks for pxls within tile ind

; --- Attribute editor (code label prefix "ae") ---------------------------------------------------

attreditor      lda prevpadstat    ; if any button pressed on previous frame, ignore all
                beq +
                jmp attreditor2    ; TODO: code golf to get label within branch range

+               lda padstatus      ; if select pressed, switch to palette editor
                and #pad_sl
                beq +
                ldx #(1*4)         ; hide attribute editor sprites (#1-#4)
                ldy #4
                jsr hidesprites    ; X = first byte index, Y = count
-               lda initsprdata,x  ; show palette editor sprites (#5-#23)
                sta sprdata,x
                inx
                inx
                inx
                inx
                cpx #(24*4)
                bne -
                inc mode           ; change program mode
                rts                ; return to main loop

+               lda padstatus        ; if A/B pressed, change attribute block subpalette (bit pair)
                and #(pad_a|pad_b)
                beq aearrows
                jsr attrvramofs      ; get vramoffs and vramcpyaddr
                jsr attrbitpos       ; 0/2/4/6 -> X
                ldy #0               ; attribute byte to modify -> stack
                lda (vramcpyaddr),y
                pha
                and bpchgmasks,x     ; attr byte with bits other than LSB of bit pair cleared -> A
                bit padstatus        ; if A pressed, increment subpalette, else decrement
                bpl +
                asl a                ; increment subpalette (ASL is only used to update zero flag)
                beq ++               ; if LSB of bit pair is CLEAR, only flip it,
                inx                  ; else INX to flip MSB too
                bpl ++               ; unconditional
+               asl a                ; decrement subpalette (ASL is only used to update zero flag)
                bne ++               ; if LSB of bit pair is SET, only flip it,
                inx                  ; else INX to flip MSB too
++              pla                  ; pull original attribute byte
                eor bpchgmasks,x     ; flip LSB only or MSB too
                sta (vramcpyaddr),y  ; store to vramcopy (Y is still 0)
                jsr tovrambuf        ; tell NMI routine to update A to VRAM

aearrows        lda padstatus    ; check horizontal arrows
                lsr a
                bcs +
                lsr a
                bcs ++
                bcc aecheckvert  ; unconditional
+               lda cursorx      ; right
                adc #(4-1)       ; carry is always set
                bcc +++          ; unconditional
++              lda cursorx      ; left
                sbc #4           ; carry is always set
+++             and #%00111111   ; store horizontal position
                sta cursorx
aecheckvert     lda padstatus    ; check vertical arrows
                lsr a
                lsr a
                lsr a
                bcs +
                lsr a
                bcs ++
                bcc attreditor2  ; unconditional
+               lda cursory      ; down
                adc #(4-1)       ; carry is always set
                cmp #56
                bne +++
                lda #0
                beq +++          ; unconditional
++              lda cursory      ; up
                sbc #4           ; carry is always set
                bpl +++
                lda #(56-4)
+++             sta cursory      ; store vertical position

attreditor2     lda cursorx        ; update cursor sprite X
                asl a
                asl a
                sta sprdata+4+3
                sta sprdata+3*4+3
                adc #8             ; carry is always clear
                sta sprdata+2*4+3
                sta sprdata+4*4+3
                lda cursory        ; update cursor sprite Y
                asl a
                asl a
                adc #(8-1)         ; carry is always clear
                sta sprdata+4+0
                sta sprdata+2*4+0
                adc #8             ; carry is always clear
                sta sprdata+3*4+0
                sta sprdata+4*4+0
                rts                ; return to main loop

bpchgmasks      db %00000001, %00000011  ; AND/XOR masks for changing bit pairs
                db %00000100, %00001100  ; (LSB or both LSB and MSB of each)
                db %00010000, %00110000
                db %01000000, %11000000

; --- Subroutines used by both paint mode and attribute editor ------------------------------------

attrbitpos      lda cursory     ; position within attribute byte -> X (0/2/4/6)
                and #%00000100  ; bits: cursory = 00ABCDEF, cursorx = 00abcdef -> X = 00000Dd0
                lsr a
                tax
                lda cursorx
                and #%00000100
                cmp #%00000100  ; bit -> carry
                txa
                adc #0
                asl a
                tax
                rts

attrvramofs     lda #%00000011  ; get VRAM offset for attribute byte, fall through to next sub
                sta vramoffs+1  ; bits: cursory = 00ABCDEF, cursorx = 00abcdef
                lda cursory     ; -> vramoffs = $3c0 + 00ABCabc = 00000011 11ABCabc
                and #%00111000
                sta temp
                lda cursorx
                lsr a
                lsr a
                lsr a
                ora temp
                ora #%11000000
                sta vramoffs+0  ; fall through to next sub

getvramcpad     lda vramoffs+0     ; get address within vramcopy
                sta vramcpyaddr+0  ; vramcopy + vramoffs -> vramcpyaddr (vramcopy must be at $xx00)
                lda #>vramcopy
                clc
                adc vramoffs+1
                sta vramcpyaddr+1
                rts

tovrambuf       pha               ; tell NMI routine to write A to VRAM $2000 + vramoffs
                inc vrambufpos
                ldx vrambufpos
                lda #$20
                ora vramoffs+1
                sta vrambufhi,x
                lda vramoffs+0
                sta vrambuflo,x
                pla
                sta vrambufval,x
                rts

; --- Palette editor (code label prefix "pe") -----------------------------------------------------

paleditor       lda prevpadstat  ; if any button pressed on previous frame, ignore all
                bne paleditor2

                lda padstatus
                lsr a
                bcs peinc1s      ; right
                lsr a
                bcs pedec1s      ; left
                lsr a
                bcs pedown       ; down
                lsr a
                bcs peup         ; up
                lsr a
                bcs peincsubpal  ; start
                lsr a
                bcs peexit       ; select; ends with rts
                lsr a
                bcs pedec16s     ; B
                bne peinc16s     ; A
                beq paleditor2   ; unconditional

peexit          ldx #(5*4)       ; exit palette editor (switch to paint mode)
                ldy #19          ; hide palette editor sprites (#5-#23)
                jsr hidesprites  ; X = first byte index, Y = count
                lda #0
                sta mode         ; change program mode
                rts              ; return to main loop

peincsubpal     lda paledsubpal  ; increment subpalette (0 -> 1 -> 2 -> 3 -> 0)
                adc #0           ; carry is always set
                and #%00000011
                sta paledsubpal
                bpl paleditor2   ; unconditional

pedown          ldx paledcurpos  ; move down
                inx
                bpl pestorepos   ; unconditional
peup            ldx paledcurpos  ; move up
                dex
pestorepos      txa              ; store cursor pos
                and #%00000011
                sta paledcurpos
                tax
                bpl paleditor2   ; unconditional

peinc1s         jsr userpaloffs  ; increment ones
                ldy userpal,x
                iny
                bpl pestore1s    ; unconditional
pedec1s         jsr userpaloffs  ; decrement ones
                ldy userpal,x
                dey
pestore1s       tya              ; store ones
                and #%00001111
                sta temp
                lda userpal,x
                and #%00110000
                ora temp
                sta userpal,x
                bpl paleditor2   ; unconditional

peinc16s        jsr userpaloffs  ; increment sixteens
                lda userpal,x
                clc
                adc #$10
                bpl pestore16s   ; unconditional
pedec16s        jsr userpaloffs  ; decrement sixteens
                lda userpal,x
                sec
                sbc #$10
pestore16s      and #%00111111   ; store sixteens
                sta userpal,x
                bpl paleditor2   ; unconditional

paleditor2      lda paledsubpal    ; palette editor, part 2
                sta sprdata+8*4+1  ; update tile of selected subpalette
                lda paledcurpos    ; update cursor Y position
                asl a
                asl a
                asl a
                adc #(24*8-1)      ; carry is always clear
                sta sprdata+5*4+0
                jsr userpaloffs    ; update sixteens tile of color number
                lda userpal,x
                lsr a
                lsr a
                lsr a
                lsr a
                sta sprdata+10*4+1
                lda userpal,x       ; update ones tile of color number
                and #%00001111
                sta sprdata+11*4+1

                ; tell NMI routine to update 5 VRAM bytes
                jsr userpaloffs
                pha
                ldx vrambufpos
                lda #$3f            ; selected color -> background palette
                sta vrambufhi+1,x
                pla
                sta vrambuflo+1,x
                tay
                lda userpal,y
                sta vrambufval+1,x
                lda #$3f            ; 1st color of all subpalettes
                sta vrambufhi+2,x
                lda #(4*4+2)
                sta vrambuflo+2,x
                lda userpal+0
                sta vrambufval+2,x
                lda paledsubpal     ; subpalette offset in user palette -> Y
                asl a
                asl a
                tay
                lda #$3f            ; 2nd color of selected subpalette
                sta vrambufhi+3,x
                lda #(5*4+2)
                sta vrambuflo+3,x
                lda userpal+1,y
                sta vrambufval+3,x
                lda #$3f            ; 3rd color of selected subpalette
                sta vrambufhi+4,x
                lda #(6*4+2)
                sta vrambuflo+4,x
                lda userpal+2,y
                sta vrambufval+4,x
                lda #$3f            ; 4th color of selected subpalette
                sta vrambufhi+5,x
                lda #(7*4+2)
                sta vrambuflo+5,x
                lda userpal+3,y
                sta vrambufval+5,x
                txa                 ; update buffer pointer
                clc
                adc #5
                sta vrambufpos

                rts                 ; return to main loop

userpaloffs     lda paledcurpos  ; offset to user palette (userpal or VRAM $3f00-$3f0f) -> A, X
                beq +            ; if 1st color of any subpal, zero
                lda paledsubpal  ; else, subpalette * 4 + cursor pos
                asl a
                asl a
                ora paledcurpos
+               tax
                rts

; --- Subroutines used by many parts of the program -----------------------------------------------

hidesprites     lda #$ff       ; hide some sprites (X = first index on sprite page, Y = count)
-               sta sprdata,x
                inx
                inx
                inx
                inx
                dey
                bne -
                rts

; --- Interrupt routines --------------------------------------------------------------------------

nmi             pha            ; push A, X (note: not Y)
                txa
                pha
                bit ppustatus  ; reset ppuaddr/ppuscroll latch
                lda #$00       ; do OAM DMA
                sta oamaddr
                lda #>sprdata
                sta oamdma

                ldx #0            ; update VRAM from buffer
-               lda vrambufhi,x   ; high byte of address (0 = terminator)
                beq +
                sta ppuaddr
                lda vrambuflo,x   ; low byte of address
                sta ppuaddr
                lda vrambufval,x  ; value
                sta ppudata
                inx
                jmp -

+               lda #$00         ; clear VRAM buffer (put terminator at beginning)
                sta vrambufhi+0
                sta ppuaddr      ; reset PPU address
                sta ppuaddr
                sta ppuscroll    ; set PPU scroll
                lda #vscroll
                sta ppuscroll
                sec              ; set flag to let main loop run once
                ror runmain
                pla              ; pull X, A
                tax
                pla

irq             rti

; --- Interrupt vectors ---------------------------------------------------------------------------

                pad $fffa, $ff
                dw nmi, reset, irq  ; note: IRQ unused
                pad $10000, $ff

; --- CHR ROM -------------------------------------------------------------------------------------

                base $0000
                incbin "chr-bg.bin"   ; background (256 tiles, 4 KiB)
                pad $1000, $ff
                incbin "chr-spr.bin"  ; sprites (256 tiles, 4 KiB)
                pad $2000, $ff
