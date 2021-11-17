; Kalle Paint (NES, ASM6)
; Note: indentation = 12 spaces, maximum length of identifiers = 11 characters.

; --- Constants -----------------------------------------------------------------------------------

; Note: "VRAM buffer" = what to update in VRAM on next VBlank.

; RAM
vrambufhi   equ $00    ; VRAM buffer - high bytes of addresses (16 bytes; 0 = terminator)
vrambuflo   equ $10    ; VRAM buffer - low bytes of addresses (16 bytes)
vrambufval  equ $20    ; VRAM buffer - values (16 bytes)
userpal     equ $30    ; user palette (16 bytes; each $00-$3f; offsets 4/8/12 are unused)
vramoffs    equ $40    ; offset to name/attr table 0 and vramcopy (2 bytes, low first; 0-$3ff)
vramcpyaddr equ $42    ; address in vramcopy (2 bytes, low first; vramcopy...vramcopy+$3ff)
mode        equ $44    ; program mode: 0 = paint, 1 = attribute editor, 2 = palette editor
runmain     equ $45    ; run main loop? (flag; only MSB is important)
padstatus   equ $46    ; first joypad status (bits: A, B, select, start, up, down, left, right)
prevpadstat equ $47    ; first joypad status on previous frame
vrambufpos  equ $48    ; position of last byte written to VRAM buffer
temp        equ $49    ; temporary
delayleft   equ $4a    ; cursor move delay left (paint mode)
brushsize   equ $4b    ; cursor type (paint mode; 0=small, 1=big)
paintcolor  equ $4c    ; paint color (paint mode; 0-3)
cursorx     equ $4d    ; cursor X position (paint/attribute edit mode; 0-63)
cursory     equ $4e    ; cursor Y position (paint/attribute edit mode; 0-55)
blinktimer  equ $4f    ; cursor blink timer (attribute/palette editor)
paledcurpos equ $50    ; cursor position (palette editor; 0-3)
paledsubpal equ $51    ; selected subpalette (palette editor; 0-3)
sprdata     equ $0200  ; $100 bytes (see initsprdata for layout)
vramcopy    equ $0300  ; $400 bytes (copy of name/attribute table 0; must be at $xx00)

; memory-mapped registers; see https://wiki.nesdev.org/w/index.php/PPU_registers
ppuctrl     equ $2000
ppumask     equ $2001
ppustatus   equ $2002
oamaddr     equ $2003
ppuscroll   equ $2005
ppuaddr     equ $2006
ppudata     equ $2007
dmcfreq     equ $4010
oamdma      equ $4014
sndchn      equ $4015
joypad1     equ $4016
joypad2     equ $4017

; joypad bitmasks
pad_a       equ 1<<7                     ; A
pad_b       equ 1<<6                     ; B
pad_sl      equ 1<<5                     ; select
pad_st      equ 1<<4                     ; start
pad_u       equ 1<<3                     ; up
pad_d       equ 1<<2                     ; down
pad_l       equ 1<<1                     ; left
pad_r       equ 1<<0                     ; right
pad_bslst   equ pad_b|pad_sl|pad_st      ; B/select/start
pad_arrows  equ pad_u|pad_d|pad_l|pad_r  ; any arrow

; default user palette
defcolorbg  equ $0f  ; background (all subpalettes)
defcolor0a  equ $15
defcolor0b  equ $25
defcolor0c  equ $35
defcolor1a  equ $18
defcolor1b  equ $28
defcolor1c  equ $38
defcolor2a  equ $1b
defcolor2b  equ $2b
defcolor2c  equ $3b
defcolor3a  equ $12
defcolor3b  equ $22
defcolor3c  equ $32

; sprite tile indexes (hexadecimal digits "0"-"F" must start at $00)
smalcurtile equ $10  ; cursor - small
bigcurtile  equ $11  ; cursor - large
attrcurtile equ $12  ; cursor - corner of attribute cursor
covertile   equ $13  ; cover (palette editor)
ptile       equ $14  ; "P"
colindtile  equ $15  ; color indicator (palette editor)

; other
paledbgcol  equ $0f    ; palette editor background color / blinking cursor 1 (black)
paledfgcol  equ $30    ; palette editor text color / blinking cursor 2 (white)
blinkrate   equ 4      ; attribute/palette editor cursor blink rate (0=fastest, 7=slowest)
brushdelay  equ 10     ; paint cursor move repeat delay (frames)
vscroll     equ 256-8  ; PPU vertical scroll value (VRAM $2000 is at the top of visible area)

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

macro waitvblank
            bit ppustatus  ; wait until next VBlank starts
-           bit ppustatus
            bpl -
endm

reset       ; initialize the NES; see https://wiki.nesdev.org/w/index.php/Init_code
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

            waitvblank

            lda #$00             ; clear zero page and vramcopy
            tax
-           sta $00,x
            sta vramcopy,x
            sta vramcopy+$100,x
            sta vramcopy+$200,x
            sta vramcopy+$300,x
            inx
            bne -

            ldx #(16-1)        ; init user palette
-           lda initpalette,x
            sta userpal,x
            dex
            bpl -

            ldx #(24*4-1)      ; init sprite data
-           lda initsprdata,x
            sta sprdata,x
            dex
            bpl -

            ldx #(1*4)       ; hide sprites except paint cursor (#0)
            ldy #63          ; X = first byte index, Y = count
            jsr hidesprites

            lda #30         ; init misc vars
            sta cursorx
            lda #26
            sta cursory
            inc paintcolor

            waitvblank

            lda #$3f           ; init PPU palette
            sta ppuaddr
            ldx #$00
            stx ppuaddr
-           lda initpalette,x
            sta ppudata
            inx
            cpx #32
            bne -

            lda #$20     ; clear name/attribute table 0 ($400 bytes)
            sta ppuaddr
            lda #$00
            sta ppuaddr
            ldy #4
--          tax
-           sta ppudata
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

            waitvblank

            lda #%10001000  ; NMI, 8*8-px sprites, pattern table 0 for BG and 1 for sprites,
            sta ppuctrl     ; 1-byte VRAM address auto-increment, name table 0

            lda #%00011110  ; show BG & sprites on entire screen,
            sta ppumask     ; don't use R/G/B de-emphasis or grayscale mode

mainloop    bit runmain      ; the main loop
            bpl mainloop     ; wait until NMI routine has run
            lsr runmain      ; clear flag to prevent main loop from running until after next NMI
            lda padstatus    ; store previous joypad status
            sta prevpadstat

            ldx #$01        ; read first joypad
            stx padstatus   ; initialize; set LSB of variable to detect end of loop
            stx joypad1
            dex
            stx joypad1
-           clc             ; read 8 buttons; each one = OR of two LSBs
            lda joypad1
            and #%00000011
            beq +
            sec
+           rol padstatus
            bcc -

            lda #$3f             ; tell NMI routine to update blinking cursor in VRAM
            sta vrambufhi+0
            lda #$13
            sta vrambuflo+0
            ldx #paledbgcol
            lda blinktimer
            and #(1<<blinkrate)
            beq +
            ldx #paledfgcol
+           stx vrambufval+0
            lda #0               ; store pos of last byte written
            sta vrambufpos

            inc blinktimer  ; advance timer
            jsr jumpengine  ; run code for the program mode we're in

            ldx vrambufpos      ; append terminator to VRAM buffer
            lda #$00
            sta vrambufhi+1,x

            beq mainloop  ; unconditional

initpalette ; initial palette
            ; background (also the initial user palette)
            db defcolorbg, defcolor0a, defcolor0b, defcolor0c
            db defcolorbg, defcolor1a, defcolor1b, defcolor1c
            db defcolorbg, defcolor2a, defcolor2b, defcolor2c
            db defcolorbg, defcolor3a, defcolor3b, defcolor3c
            ; sprites
            ; all subpalettes used for selected colors in palette editor (TODO: elaborate)
            ; 1st one also used for all cursors         (4th color = foreground)
            ; 2nd one also used for palette editor text (4th color = foreground)
            db defcolorbg, paledbgcol, defcolorbg, defcolor0a
            db defcolorbg, paledbgcol, defcolor0a, paledfgcol
            db defcolorbg, paledbgcol, defcolor0b, defcolorbg
            db defcolorbg, paledbgcol, defcolor0c, defcolorbg

initsprdata ; initial sprite data (Y, tile, attributes, X for each sprite)
            ; paint mode
            db    $ff, smalcurtile, %00000000,    0  ; #0:  cursor
            ; attribute editor
            db    $ff, attrcurtile, %00000000,    0  ; #1:  cursor top left
            db    $ff, attrcurtile, %01000000,    0  ; #2:  cursor top right
            db    $ff, attrcurtile, %10000000,    0  ; #3:  cursor bottom left
            db    $ff, attrcurtile, %11000000,    0  ; #4:  cursor bottom right
            ; palette editor
            db    $ff,  bigcurtile, %00000000, 29*8  ; #5:  cursor
            db 22*8-1,       ptile, %00000001, 28*8  ; #6:  "P"
            db 22*8-1,         $00, %00000001, 30*8  ; #7:  subpalette number
            db 23*8-1,         $0c, %00000001, 28*8  ; #8:  "C"
            db 23*8-1,         $00, %00000001, 29*8  ; #9:  color number - 16s
            db 23*8-1,         $00, %00000001, 30*8  ; #10: color number - ones
            db 24*8-1,  colindtile, %00000000, 29*8  ; #11: color 0
            db 25*8-1,  colindtile, %00000001, 29*8  ; #12: color 1
            db 26*8-1,  colindtile, %00000010, 29*8  ; #13: color 2
            db 27*8-1,  colindtile, %00000011, 29*8  ; #14: color 3
            db 22*8-1,   covertile, %00000001, 29*8  ; #15: cover (to left  of subpal number)
            db 24*8-1,   covertile, %00000001, 28*8  ; #16: cover (to left  of color 0)
            db 24*8-1,   covertile, %00000001, 30*8  ; #17: cover (to right of color 0)
            db 25*8-1,   covertile, %00000001, 28*8  ; #18: cover (to left  of color 1)
            db 25*8-1,   covertile, %00000001, 30*8  ; #19: cover (to right of color 1)
            db 26*8-1,   covertile, %00000001, 28*8  ; #20: cover (to left  of color 2)
            db 26*8-1,   covertile, %00000001, 30*8  ; #21: cover (to right of color 2)
            db 27*8-1,   covertile, %00000001, 28*8  ; #22: cover (to left  of color 3)
            db 27*8-1,   covertile, %00000001, 30*8  ; #23: cover (to right of color 3)

jumpengine  ldx mode           ; jump engine (run one sub depending on program mode)
            lda jumptablehi,x  ; note: don't inline this sub
            pha                ; push target address minus one, high byte first
            lda jumptablelo,x
            pha
            rts                ; pull address, low byte first; jump to that address plus one

jumptablehi dh paintmode-1, attreditor-1, paleditor-1  ; jump table - high bytes
jumptablelo dl paintmode-1, attreditor-1, paleditor-1  ; jump table - low bytes

; --- Paint mode (code label prefix "pm") ---------------------------------------------------------

paintmode   lda prevpadstat  ; if B/select/start pressed on previous frame, ignore them
            and #pad_bslst
            bne pmarrows
            lda padstatus    ; else if select pressed, switch to attribute editor
            and #pad_sl
            bne pmexit       ; ends with rts

            lda padstatus    ; else if B pressed, increment paint color (0-3)
            and #pad_b
            beq +
            ldx paintcolor
            inx
            txa
            and #%00000011
            sta paintcolor
+           lda padstatus    ; if start pressed, toggle brush size
            and #pad_st
            beq pmarrows
            lda brushsize
            eor #%00000001
            sta brushsize
            beq pmarrows
            lsr cursorx      ; if large brush, make coordinates even
            asl cursorx
            lsr cursory
            asl cursory

pmarrows    lda padstatus    ; arrow logic
            and #pad_arrows  ; if none pressed, clear cursor move delay
            bne +
            sta delayleft
            beq paintmode2   ; unconditional; ends with rts
+           lda delayleft    ; else if delay > 0, decrement it
            beq +
            dec delayleft
            bpl paintmode2   ; unconditional; ends with rts
+           jsr pmcheckhorz  ; else react to arrows, reinit cursor move delay
            lda #brushdelay
            sta delayleft
            bne paintmode2   ; unconditional; ends with rts

pmexit      lda #$ff         ; switch to attribute edit mode
            sta sprdata+0+0  ; hide paint cursor sprite
            lda cursorx      ; make cursor coordinates a multiple of four
            and #%00111100
            sta cursorx
            lda cursory
            and #%00111100
            sta cursory
            inc mode         ; change program mode
            rts

pmcheckhorz lda padstatus    ; react to horizontal arrows
            lsr a
            bcs pmright
            lsr a
            bcs pmleft
            bcc pmcheckvert  ; unconditional
pmright     lda cursorx      ; right arrow
            sec
            adc brushsize
            bpl pmstorehorz  ; unconditional
pmleft      lda cursorx      ; left arrow
            clc
            sbc brushsize
pmstorehorz and #%00111111   ; store horizontal pos
            sta cursorx

pmcheckvert lda padstatus    ; react to vertical arrows
            lsr a
            lsr a
            lsr a
            bcs pmdown
            lsr a
            bcs pmup
            rts
pmdown      lda cursory      ; down arrow
            sec
            adc brushsize
            cmp #56
            bne pmstorevert
            lda #0
            beq pmstorevert  ; unconditional
pmup        lda cursory      ; up arrow
            clc
            sbc brushsize
            bpl pmstorevert
            lda #56
            clc
            sbc brushsize
pmstorevert sta cursory      ; store vertical pos
            rts

paintmode2  ; paint mode, part 2

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
-           lsr a
            dex
            bne -
+           and #%00000011       ; clear other bits
            asl a                ; index to userpal -> X
            asl a
            ora paintcolor
            tax
++          lda userpal,x        ; cursor color -> A
            pha                  ; append to VRAM buffer
            inc vrambufpos
            ldx vrambufpos
            lda #$3f
            sta vrambufhi,x
            lda #$13
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

            jsr getvramcpad  ; get vramcpyaddr from vramoffs
            lda brushsize    ; small or large brush?
            beq +

            ldx paintcolor    ; large -> replace entire byte (tile) with a solid color
            lda solidtiles,x
            jmp updatetile

+           ; small -> replace a bitpair (pixel) within the original byte
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
            ldy paintcolor       ; OR mask for setting a bit pair -> X
            lda solidtiles,y
            and pixelmasks,x
            tax
            pla                  ; pull original byte, clear bit pair, insert new bit pair
            and temp
            stx temp
            ora temp

updatetile  ldy #0               ; update byte in vramcopy
            sta (vramcpyaddr),y
            jsr tovrambuf        ; tell NMI routine to copy A to VRAM according to vramoffs
rtslabel    rts

cursortiles db smalcurtile, bigcurtile                     ; brush size -> cursor tile
solidtiles  db %00000000, %01010101, %10101010, %11111111  ; tiles of solid color 0-3
pixelmasks  db %11000000, %00110000, %00001100, %00000011  ; bitmasks for pixels within tile index

; --- Attribute editor (code label prefix "ae"); TODO: tidy up ------------------------------------

attreditor  lda prevpadstat    ; if any button pressed on previous frame, ignore all
            bne aespriteupd
            lda padstatus      ; else if select pressed, switch to palette editor
            and #pad_sl
            beq +
            jmp aeexit         ; ends with rts

+           lda padstatus       ; skip following code if not A or B pressed
            and #(pad_a|pad_b)
            beq aecheckhorz

            ; change attribute block subpalette (bitpair within byte): A=increment, B=decrement
            jsr attrvramofs      ; get vramoffs and vramcpyaddr
            jsr attrbitpos       ; 0/2/4/6 -> X
            ldy #0               ; attribute byte to modify -> A, stack
            lda (vramcpyaddr),y
            pha
            bit padstatus        ; MSB = A pressed
            bpl +
            and bpchgmasks,x     ; increment subpalette:
            beq ++               ; if LSB of bitpair CLEAR, only flip it, else INX to flip MSB too
            inx
            bpl ++               ; unconditional
+           and bpchgmasks,x     ; decrement subpalette:
            bne ++               ; if LSB of bitpair SET, only flip it, else INX to flip MSB too
            inx
++          pla                  ; pull original attribute byte and change it
            eor bpchgmasks,x
            ldy #0               ; store to vramcopy
            sta (vramcpyaddr),y
            jsr tovrambuf        ; tell NMI routine to update A to VRAM

aecheckhorz lda padstatus    ; check horizontal arrows
            lsr a
            bcs +
            lsr a
            bcs ++
            bcc aecheckvert  ; unconditional
+           lda cursorx      ; right
            adc #(4-1)       ; carry is always set
            bcc +++          ; unconditional
++          lda cursorx      ; left
            sbc #4           ; carry is always set
+++         and #%00111111   ; store horizontal pos
            sta cursorx
aecheckvert lda padstatus    ; check vertical arrows
            lsr a
            lsr a
            lsr a
            bcs +
            lsr a
            bcs ++
            rts
+           lda cursory      ; down
            adc #(4-1)       ; carry is always set
            cmp #56
            bne +++
            lda #0
            beq +++          ; unconditional
++          lda cursory      ; up
            sbc #4           ; carry is always set
            bpl +++
            lda #(56-4)
+++         sta cursory      ; store vertical pos

aespriteupd lda cursorx        ; update cursor sprite X
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
            rts

aeexit      lda #0             ; switch to palette editor
            sta paledcurpos    ; reset palette cursor position and selected subpalette
            sta paledsubpal
            ldx #(1*4)         ; hide attribute editor sprites (#1-#4)
            ldy #4             ; X = first byte index, Y = count
            jsr hidesprites
-           lda initsprdata,x  ; show palette editor sprites (#5-#23)
            sta sprdata,x
            inx
            inx
            inx
            inx
            cpx #(24*4)
            bne -
            inc mode           ; change program mode
            rts

bpchgmasks  db %00000001, %00000011  ; bitpair change masks (LSB or both LSB and MSB of each)
            db %00000100, %00001100
            db %00010000, %00110000
            db %01000000, %11000000

; --- Subroutines used by both paint mode and attribute editor ------------------------------------

attrbitpos  lda cursory     ; position within attribute byte -> X (0/2/4/6)
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

attrvramofs lda #%00000011  ; get VRAM offset for attribute byte, fall through to next sub
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
            sta vramoffs+0  ; fall through

getvramcpad lda vramoffs+0     ; get address within vramcopy
            sta vramcpyaddr+0  ; vramcopy + vramoffs -> vramcpyaddr (vramcopy must be at $xx00)
            lda #>vramcopy
            clc
            adc vramoffs+1
            sta vramcpyaddr+1
            rts

tovrambuf   pha               ; tell NMI routine to write A to VRAM $2000 + vramoffs
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

paleditor   lda prevpadstat  ; if any button pressed on prev frame, ignore all
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

peexit      ldx #(5*4)       ; exit palette editor (switch to paint mode)
            ldy #19          ; hide palette editor sprites (#5-#23)
            jsr hidesprites  ; X = first byte index, Y = count
            lda #0
            sta mode         ; change program mode
            rts

peincsubpal lda paledsubpal  ; increment subpalette (0 -> 1 -> 2 -> 3 -> 0)
            adc #0           ; carry is always set
            and #%00000011
            sta paledsubpal
            bpl paleditor2   ; unconditional

pedown      ldx paledcurpos  ; move down
            inx
            bpl pestorevert  ; unconditional
peup        ldx paledcurpos  ; move up
            dex
pestorevert txa              ; store vertical
            and #%00000011
            sta paledcurpos
            tax
            bpl paleditor2   ; unconditional

peinc1s     jsr userpaloffs  ; increment ones
            ldy userpal,x
            iny
            bpl pestore1s    ; unconditional
pedec1s     jsr userpaloffs  ; decrement ones
            ldy userpal,x
            dey
pestore1s   tya              ; store ones
            and #%00001111
            sta temp
            lda userpal,x
            and #%00110000
            ora temp
            sta userpal,x
            bpl paleditor2   ; unconditional

peinc16s    jsr userpaloffs  ; increment sixteens
            lda userpal,x
            clc
            adc #$10
            bpl pestore16s   ; unconditional
pedec16s    jsr userpaloffs  ; decrement sixteens
            lda userpal,x
            sec
            sbc #$10
pestore16s  and #%00111111   ; store sixteens
            sta userpal,x
            bpl paleditor2   ; unconditional

paleditor2  lda paledsubpal    ; palette editor, part 2
            sta sprdata+7*4+1  ; update tile of selected subpalette
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
            sta sprdata+9*4+1
            lda userpal,x       ; update ones tile of color number
            and #%00001111
            sta sprdata+10*4+1

            jsr userpaloffs     ; tell NMI routine to update 5 VRAM bytes
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
            lda #$12
            sta vrambuflo+2,x
            lda userpal+0
            sta vrambufval+2,x
            lda paledsubpal     ; subpal offset in user palette -> Y
            asl a
            asl a
            tay
            lda #$3f            ; 2nd color of selected subpalette
            sta vrambufhi+3,x
            lda #$16
            sta vrambuflo+3,x
            lda userpal+1,y
            sta vrambufval+3,x
            lda #$3f            ; 3rd color of selected subpalette
            sta vrambufhi+4,x
            lda #$1a
            sta vrambuflo+4,x
            lda userpal+2,y
            sta vrambufval+4,x
            lda #$3f            ; 4th color of selected subpalette
            sta vrambufhi+5,x
            lda #$1e
            sta vrambuflo+5,x
            lda userpal+3,y
            sta vrambufval+5,x
            txa                 ; update buffer pointer
            clc
            adc #5
            sta vrambufpos

            rts

userpaloffs lda paledcurpos  ; offset to user palette (userpal or VRAM $3f00-$3f0f) -> A, X
            beq +            ; if 1st color of any subpal, zero
            lda paledsubpal  ; else, subpalette * 4 + cursor pos
            asl a
            asl a
            ora paledcurpos
+           tax
            rts

; --- Subroutines used by many parts of the program -----------------------------------------------

hidesprites lda #$ff       ; hide some sprites (X = first index on sprite page, Y = count)
-           sta sprdata,x
            inx
            inx
            inx
            inx
            dey
            bne -
            rts

; --- Interrupt routines --------------------------------------------------------------------------

nmi         pha            ; push A, X (note: not Y)
            txa
            pha
            bit ppustatus  ; reset ppuaddr/ppuscroll latch
            lda #$00       ; do OAM DMA
            sta oamaddr
            lda #>sprdata
            sta oamdma

            ldx #0            ; update VRAM from buffer
-           lda vrambufhi,x   ; high byte of address (0 = terminator)
            beq +
            sta ppuaddr
            lda vrambuflo,x   ; low byte of address
            sta ppuaddr
            lda vrambufval,x  ; value
            sta ppudata
            inx
            jmp -

+           lda #$00         ; clear VRAM buffer (put terminator at beginning)
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

irq         rti

; --- Interrupt vectors ---------------------------------------------------------------------------

            pad $fffa, $ff
            dw nmi, reset, irq  ; note: IRQ unused
            pad $10000, $ff

; --- CHR ROM -------------------------------------------------------------------------------------

            base $0000
            incbin "chr-background.bin"  ; 256 tiles (4 KiB)
            pad $1000, $ff
            incbin "chr-sprites.bin"     ; 256 tiles (4 KiB)
            pad $2000, $ff
