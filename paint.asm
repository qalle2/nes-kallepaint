; Kalle Paint (NES, ASM6)

; --- Constants -----------------------------------------------------------------------------------

; Note: "VRAM buffer" = what to update in VRAM on next VBlank.

; RAM
vrbufhi equ $00    ; VRAM buffer - high bytes of addresses (16 bytes; 0 = terminator)
vrbuflo equ $10    ; VRAM buffer - low bytes of addresses (16 bytes)
vrbufva equ $20    ; VRAM buffer - values (16 bytes)
userpal equ $30    ; user palette (16 bytes; each $00-$3f; offsets 4/8/12 are unused)
vramofs equ $40    ; offset to name/attr table 0 and vramcpy (2 bytes, low first; 0-$3ff)
vrcpyad equ $42    ; address in vramcpy (2 bytes, low first; vramcpy...vramcpy+$3ff)
mode    equ $44    ; 0 = paint mode, 1 = attribute editor, 2 = palette editor
runmain equ $45    ; run main loop? (flag; only MSB is important)
padstat equ $46    ; first joypad status (bits: A, B, select, start, up, down, left, right)
prpadst equ $47    ; first joypad status on previous frame
vrbufpo equ $48    ; position of last byte written to VRAM buffer
temp    equ $49    ; temporary
delalft equ $4a    ; cursor move delay left (paint mode)
brushsz equ $4b    ; cursor type (paint mode; 0=small, 1=big)
paincol equ $4c    ; paint color (paint mode; 0-3)
cursorx equ $4d    ; cursor X position (paint/attribute edit mode; 0-63)
cursory equ $4e    ; cursor Y position (paint/attribute edit mode; 0-55)
blnktmr equ $4f    ; cursor blink timer (attribute/palette editor)
paedcrp equ $50    ; cursor position (palette editor; 0-3)
paedsbp equ $51    ; selected subpalette (palette editor; 0-3)
sprdata equ $0200  ; $100 bytes (see insprdt for layout)
vramcpy equ $0300  ; $400 bytes (copy of name/attribute table 0; must be at $xx00)

; memory-mapped registers; see https://wiki.nesdev.org/w/index.php/PPU_registers
ppuctrl equ $2000
ppumask equ $2001
ppustat equ $2002
oamaddr equ $2003
ppuscro equ $2005
ppuaddr equ $2006
ppudata equ $2007
dmcfreq equ $4010
oamdma  equ $4014
sndchn  equ $4015
joypad1 equ $4016
joypad2 equ $4017

; joypad bitmasks
pad_a  equ 1<<7  ; A
pad_b  equ 1<<6  ; B
pad_sl equ 1<<5  ; select
pad_st equ 1<<4  ; start
pad_u  equ 1<<3  ; up
pad_d  equ 1<<2  ; down
pad_l  equ 1<<1  ; left
pad_r  equ 1<<0  ; right

; default user palette
defcobg equ $0f  ; background (all subpalettes)
defco0a equ $15
defco0b equ $25
defco0c equ $35
defco1a equ $18
defco1b equ $28
defco1c equ $38
defco2a equ $1b
defco2b equ $2b
defco2c equ $3b
defco3a equ $12
defco3b equ $22
defco3c equ $32

; sprite tile indexes (hexadecimal digits "0"-"F" must start at $00)
smcurti equ $10  ; cursor - small
bgcurti equ $11  ; cursor - large
atcurti equ $12  ; cursor - corner of attribute cursor
coverti equ $13  ; cover (palette editor)
ptile   equ $14  ; "P"
colinti equ $15  ; color indicator (palette editor)

; other
paledbg equ $0f    ; palette editor background color / blinking cursor 1 (black)
paledfg equ $30    ; palette editor text color / blinking cursor 2 (white)
blnkrte equ 4      ; attribute/palette editor cursor blink rate (0=fastest, 7=slowest)
brshdel equ 10     ; paint cursor move repeat brshdel (frames)
vscroll equ 256-8  ; PPU vertical scroll value (VRAM $2000 is at the top of visible area)

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

macro waitvbl
        bit ppustat  ; wait until next VBlank starts
-       bit ppustat
        bpl -
endm

reset   ; initialize the NES; see https://wiki.nesdev.org/w/index.php/Init_code
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

        waitvbl

        lda #$00            ; clear zero page and vramcpy
        tax
-       sta $00,x
        sta vramcpy,x
        sta vramcpy+$100,x
        sta vramcpy+$200,x
        sta vramcpy+$300,x
        inx
        bne -

        ldx #(16-1)    ; init user palette
-       lda initpal,x
        sta userpal,x
        dex
        bpl -

        ldx #(24*4-1)  ; init sprite data
-       lda insprdt,x
        sta sprdata,x
        dex
        bpl -

        ldx #(1*4)   ; hide sprites except paint cursor (#0)
        ldy #63      ; X = first byte index, Y = count
        jsr hidespr

        lda #30      ; init misc vars
        sta cursorx
        lda #26
        sta cursory
        inc paincol

        waitvbl

        lda #$3f       ; init PPU palette
        sta ppuaddr
        ldx #$00
        stx ppuaddr
-       lda initpal,x
        sta ppudata
        inx
        cpx #32
        bne -

        lda #$20     ; clear name/attribute table 0 ($400 bytes)
        sta ppuaddr
        lda #$00
        sta ppuaddr
        ldy #4
--      tax
-       sta ppudata
        inx
        bne -
        dey
        bne --

        bit ppustat   ; reset ppuaddr/ppuscro latch
        lda #$00      ; reset PPU address and set scroll
        sta ppuaddr
        sta ppuaddr
        sta ppuscro
        lda #vscroll
        sta ppuscro

        waitvbl

        ; NMI, 8*8-px sprites, pattern table 0 for BG and 1 for sprites,
        ; 1-byte VRAM address auto-increment, name table 0
        lda #%10001000
        sta ppuctrl

        ; show BG & sprites on entire screen, don't use R/G/B de-emphasis or grayscale mode
        lda #%00011110
        sta ppumask

mainloo bit runmain  ; main loop
        bpl mainloo  ; wait until NMI routine has run

        lsr runmain  ; clear flag to prevent main loop from running before next NMI

        lda padstat  ; store previous joypad status
        sta prpadst

        ldx #$01        ; read first joypad
        stx padstat     ; initialize; set LSB of variable to detect end of loop
        stx joypad1
        dex
        stx joypad1
-       clc             ; read 8 buttons; each one = OR of two LSBs
        lda joypad1
        and #%00000011
        beq +
        sec
+       rol padstat
        bcc -

        lda #$3f           ; tell NMI to update blinking cursor in VRAM (first item in VRAM buffer)
        sta vrbufhi+0
        lda #$13
        sta vrbuflo+0
        ldx #paledbg
        lda blnktmr
        and #(1<<blnkrte)
        beq +
        ldx #paledfg
+       stx vrbufva+0
        lda #0             ; store pos of last byte written
        sta vrbufpo

        inc blnktmr

        jsr jumpeng  ; run code for the mode we're in

        ldx vrbufpo      ; append terminator to VRAM buffer
        lda #$00
        sta vrbufhi+1,x

        beq mainloo  ; unconditional

initpal ; initial palette
        ; background (also the initial user palette)
        db defcobg, defco0a, defco0b, defco0c
        db defcobg, defco1a, defco1b, defco1c
        db defcobg, defco2a, defco2b, defco2c
        db defcobg, defco3a, defco3b, defco3c
        ; sprites
        ; all subpalettes used for selected colors in palette editor (TODO: elaborate)
        ; 1st one also used for all cursors         (4th color = foreground)
        ; 2nd one also used for palette editor text (4th color = foreground)
        db defcobg, paledbg, defcobg, defco0a
        db defcobg, paledbg, defco0a, paledfg
        db defcobg, paledbg, defco0b, defcobg
        db defcobg, paledbg, defco0c, defcobg

insprdt ; initial sprite data (Y, tile, attributes, X for each sprite)
        ; paint mode
        db    $ff, smcurti, %00000000,    0  ; #0:  cursor
        ; attribute editor
        db    $ff, atcurti, %00000000,    0  ; #1:  cursor top left
        db    $ff, atcurti, %01000000,    0  ; #2:  cursor top right
        db    $ff, atcurti, %10000000,    0  ; #3:  cursor bottom left
        db    $ff, atcurti, %11000000,    0  ; #4:  cursor bottom right
        ; palette editor
        db    $ff, bgcurti, %00000000, 29*8  ; #5:  cursor
        db 22*8-1,   ptile, %00000001, 28*8  ; #6:  "P"
        db 22*8-1,     $00, %00000001, 30*8  ; #7:  subpalette number
        db 23*8-1,     $0c, %00000001, 28*8  ; #8:  "C"
        db 23*8-1,     $00, %00000001, 29*8  ; #9:  color number - 16s
        db 23*8-1,     $00, %00000001, 30*8  ; #10: color number - ones
        db 24*8-1, colinti, %00000000, 29*8  ; #11: color 0
        db 25*8-1, colinti, %00000001, 29*8  ; #12: color 1
        db 26*8-1, colinti, %00000010, 29*8  ; #13: color 2
        db 27*8-1, colinti, %00000011, 29*8  ; #14: color 3
        db 22*8-1, coverti, %00000001, 29*8  ; #15: cover (to left  of subpal number)
        db 24*8-1, coverti, %00000001, 28*8  ; #16: cover (to left  of color 0)
        db 24*8-1, coverti, %00000001, 30*8  ; #17: cover (to right of color 0)
        db 25*8-1, coverti, %00000001, 28*8  ; #18: cover (to left  of color 1)
        db 25*8-1, coverti, %00000001, 30*8  ; #19: cover (to right of color 1)
        db 26*8-1, coverti, %00000001, 28*8  ; #20: cover (to left  of color 2)
        db 26*8-1, coverti, %00000001, 30*8  ; #21: cover (to right of color 2)
        db 27*8-1, coverti, %00000001, 28*8  ; #22: cover (to left  of color 3)
        db 27*8-1, coverti, %00000001, 30*8  ; #23: cover (to right of color 3)

jumpeng ldx mode       ; jump engine (run one sub depending on mode; don't inline this)
        lda jmptblh,x  ; push target address minus one, high byte first
        pha
        lda jmptbll,x
        pha
        rts            ; pull address, low byte first; jump to that address plus one

jmptblh dh paintmd-1, atedit-1, paledit-1  ; jump table high
jmptbll dl paintmd-1, atedit-1, paledit-1  ; jump table low

; --- Paint mode ----------------------------------------------------------------------------------

paintmd lda prpadst                 ; ignore select, B, start if any pressed on prev frame
        and #(pad_sl|pad_b|pad_st)
        bne paarrow
        lda padstat                 ; if select pressed, switch to attribute editor
        and #pad_sl
        bne paexit                  ; ends with rts
        lda padstat                 ; if B pressed, cycle paint color (0->1->2->3->0)
        and #pad_b
        beq +
        ldx paincol
        inx
        txa
        and #%00000011
        sta paincol
+       lda padstat                 ; if start pressed, toggle cursor size
        and #pad_st
        beq +
        lda brushsz
        eor #%00000001
        sta brushsz
        beq +
        lsr cursorx                 ; make coordinates even
        asl cursorx
        lsr cursory
        asl cursory
+

paarrow lda padstat                     ; arrow logic
        and #(pad_u|pad_d|pad_l|pad_r)  ; if none pressed, clear cursor move delay
        bne +
        sta delalft
        beq paintm2                     ; unconditional; ends with rts
+       lda delalft                     ; else if delay > 0, decrement it
        beq +
        dec delalft
        bpl paintm2                     ; unconditional; ends with rts
+       jsr pachekh                     ; else react to arrows, reinit cursor move delay
        lda #brshdel
        sta delalft
        bne paintm2                     ; unconditional; ends with rts

paexit  lda #$ff         ; switch to attribute edit mode
        sta sprdata+0+0  ; hide paint cursor sprite
        lda cursorx      ; make cursor coordinates a multiple of four
        and #%00111100
        sta cursorx
        lda cursory
        and #%00111100
        sta cursory
        inc mode
        rts

pachekh lda padstat     ; react to horizontal arrows, change cursorx
        lsr a
        bcs +
        lsr a
        bcs ++
        bcc pachekv     ; unconditional
+       lda cursorx     ; right arrow
        sec
        adc brushsz
        bpl +++         ; unconditional
++      lda cursorx     ; left arrow
        clc
        sbc brushsz
+++     and #%00111111  ; store horizontal pos
        sta cursorx

pachekv lda padstat  ; react to vertical arrows, change cursory
        lsr a
        lsr a
        lsr a
        bcs +
        lsr a
        bcs ++
        rts
+       lda cursory  ; down arrow
        sec
        adc brushsz
        cmp #56
        bne +++
        lda #0
        beq +++      ; unconditional
++      lda cursory  ; up arrow
        clc
        sbc brushsz
        bpl +++
        lda #56
        clc
        sbc brushsz
+++     sta cursory  ; store vertical pos
        rts

paintm2 lda padstat  ; paint mode, part 2
        and #pad_a   ; if A pressed, tell NMI routine to paint
        beq +
        jsr dopaint

+       lda cursorx      ; update cursor sprite (X pos, Y pos, tile)
        asl a
        asl a
        sta sprdata+0+3
        lda cursory
        asl a
        asl a
        adc #(8-1)       ; carry is always clear
        sta sprdata+0+0
        ldx brushsz
        lda curstil,x
        sta sprdata+0+1

        ldx paincol      ; tell NMI to update cursor color
        beq ++           ; color 0 is common to all subpals
        jsr atrvrof
        jsr atrbypo      ; 0/2/4/6 -> X
        ldy #0           ; read attribute byte
        lda (vrcpyad),y
        cpx #0           ; shift relevant bit pair to positions 1-0
        beq +
-       lsr a
        dex
        bne -
+       and #%00000011   ; clear other bits
        asl a            ; index to userpal -> X
        asl a
        ora paincol
        tax
++      lda userpal,x    ; cursor color -> A
        pha              ; append to VRAM buffer
        inc vrbufpo
        ldx vrbufpo
        lda #$3f
        sta vrbufhi,x
        lda #$13
        sta vrbuflo,x
        pla
        sta vrbufva,x

        rts

curstil db smcurti, bgcurti  ; brush size -> paint cursor tile

dopaint ; edit one tile in VRAM copy & buffer
        lda cursory     ; compute VRAM offset for a name table byte;
        lsr a           ; bits: cursory = 00ABCDEF, cursorx = 00abcdef,
        pha             ; -> vramofs = 000000AB CDEabcde
        lsr a
        lsr a
        lsr a
        sta vramofs+1
        pla
        and #%00000111
        lsr a
        ror a
        ror a
        ora cursorx
        ror a
        sta vramofs+0

        jsr gevrcpa

        lda brushsz  ; get byte to write
        beq +        ; small cursor -> replace a bit pair

        ldx paincol    ; big cursor -> replace entire byte
        lda solidti,x  ; get tile of solid color X
        jmp tileupd

+       ldy #0           ; push the original byte in which a bit pair will be replaced
        lda (vrcpyad),y
        pha
        lda cursorx      ; pixel position within tile (0-3) -> X
        lsr a
        lda cursory
        rol a
        and #%00000011
        tax
        lda pxmasks,x    ; AND mask for clearing a bit pair -> temp
        eor #%11111111
        sta temp
        ldy paincol      ; OR mask for setting a bit pair -> X
        lda solidti,y
        and pxmasks,x
        tax
        pla              ; restore original byte, clear bit pair, insert new bit pair
        and temp
        stx temp
        ora temp

tileupd ldy #0           ; update byte and tell NMI to copy A to VRAM
        sta (vrcpyad),y
        jsr tovrbuf
        rts

solidti db %00000000, %01010101, %10101010, %11111111  ; tiles of solid color 0-3
pxmasks db %11000000, %00110000, %00001100, %00000011  ; bitmasks for pixels within tile index

; --- Attribute editor ----------------------------------------------------------------------------

atedit  lda prpadst        ; if any button pressed on prev frame, ignore all
        bne atsprup
        lda padstat        ; else if select pressed, switch to palette editor
        and #pad_sl
        bne atexit         ; ends with rts
        lda padstat        ; else if A pressed, tell NMI to update attribute byte
        and #pad_a
        beq +
        jsr atincsb
        jmp atsprup
+       jsr atchekh        ; else check arrows
atsprup lda cursorx        ; update cursor sprite X
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

atexit  lda #0         ; switch to palette editor
        sta paedcrp    ; reset palette cursor position and selected subpalette
        sta paedsbp
        ldx #(1*4)     ; hide attribute editor sprites (#1-#4)
        ldy #4         ; X = first byte index, Y = count
        jsr hidespr
-       lda insprdt,x  ; show palette editor sprites (#5-#23)
        sta sprdata,x
        inx
        inx
        inx
        inx
        cpx #(24*4)
        bne -
        inc mode       ; switch mode
        rts

atincsb jsr atrvrof      ; increment attribute block subpalette (bitpair within byte)
        jsr atrbypo      ; 0/2/4/6 -> X
        ldy #0           ; get byte to modify
        lda (vrcpyad),y
        pha
        and bpincms,x    ; check LSB of bitpair
        beq +            ; if clear, only flip it
        inx              ; if set, increment index to flip MSB too
+       pla
        eor bpincms,x    ; flip bits
        ldy #0           ; store modified byte
        sta (vrcpyad),y
        jsr tovrbuf      ; tell NMI routine to copy A to VRAM
        rts

bpincms db %00000001, %00000011  ; bitpair increment masks (LSB or both LSB and MSB of each)
        db %00000100, %00001100
        db %00010000, %00110000
        db %01000000, %11000000

atchekh lda padstat     ; check horizontal arrows
        lsr a
        bcs +
        lsr a
        bcs ++
        bcc atchekv     ; unconditional
+       lda cursorx     ; right
        adc #(4-1)      ; carry is always set
        bcc +++         ; unconditional
++      lda cursorx     ; left
        sbc #4          ; carry is always set
+++     and #%00111111  ; store horizontal pos
        sta cursorx

atchekv lda padstat  ; check vertical arrows
        lsr a
        lsr a
        lsr a
        bcs +
        lsr a
        bcs ++
        rts
+       lda cursory  ; down
        adc #(4-1)   ; carry is always set
        cmp #56
        bne +++
        lda #0
        beq +++      ; unconditional
++      lda cursory  ; up
        sbc #4       ; carry is always set
        bpl +++
        lda #(56-4)
+++     sta cursory  ; store vertical pos
        rts

; --- Subroutines used by both paint mode and attribute editor ------------------------------------

atrbypo lda cursory     ; position within attribute byte -> X (0/2/4/6)
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

atrvrof lda #%00000011  ; get VRAM offset for attribute byte, fall through to next sub
        sta vramofs+1   ; bits: cursory = 00ABCDEF, cursorx = 00abcdef
        lda cursory     ; -> vramofs = $3c0 + 00ABCabc = 00000011 11ABCabc
        and #%00111000
        sta temp
        lda cursorx
        lsr a
        lsr a
        lsr a
        ora temp
        ora #%11000000
        sta vramofs+0   ; fall through

gevrcpa lda vramofs+0  ; get address within vramcpy
        sta vrcpyad+0  ; vramcpy + vramofs -> vrcpyad (vramcpy must be at $xx00)
        lda #>vramcpy
        clc
        adc vramofs+1
        sta vrcpyad+1
        rts

tovrbuf pha            ; tell NMI routine to write A to VRAM $2000 + vramofs
        inc vrbufpo
        ldx vrbufpo
        lda #$20
        ora vramofs+1
        sta vrbufhi,x
        lda vramofs+0
        sta vrbuflo,x
        pla
        sta vrbufva,x
        rts

; --- Palette editor ------------------------------------------------------------------------------

paledit lda prpadst  ; if any button pressed on prev frame, ignore all
        bne paledi2

        lda padstat
        lsr a
        bcs peinc1   ; right
        lsr a
        bcs pedec1   ; left
        lsr a
        bcs pedn     ; down
        lsr a
        bcs peup     ; up
        lsr a
        bcs pesubp   ; start
        lsr a
        bcs peexit   ; select; ends with rts
        lsr a
        bcs pedec16  ; B
        bne peinc16  ; A
        beq paledi2  ; unconditional

peexit  ldx #(5*4)   ; exit palette editor (switch to paint mode)
        ldy #19      ; hide palette editor sprites (#5-#23)
        jsr hidespr  ; X = first byte index, Y = count
        lda #0
        sta mode
        rts

pesubp  lda paedsbp     ; cycle subpalette (0 -> 1 -> 2 -> 3 -> 0)
        adc #0          ; carry is always set
        and #%00000011
        sta paedsbp
        bpl paledi2     ; unconditional

pedn    ldx paedcrp     ; move down
        inx
        bpl pestov      ; unconditional
peup    ldx paedcrp     ; move up
        dex
pestov  txa             ; store vertical
        and #%00000011
        sta paedcrp
        tax
        bpl paledi2     ; unconditional

peinc1  jsr usplofs     ; increment ones
        ldy userpal,x
        iny
        bpl pesto1      ; unconditional
pedec1  jsr usplofs     ; decrement ones
        ldy userpal,x
        dey
pesto1  tya             ; store ones
        and #%00001111
        sta temp
        lda userpal,x
        and #%00110000
        ora temp
        sta userpal,x
        bpl paledi2     ; unconditional

peinc16 jsr usplofs     ; increment sixteens
        lda userpal,x
        clc
        adc #$10
        bpl pesto16     ; unconditional
pedec16 jsr usplofs     ; decrement sixteens
        lda userpal,x
        sec
        sbc #$10
pesto16 and #%00111111  ; store sixteens
        sta userpal,x
        bpl paledi2     ; unconditional

paledi2 lda paedsbp         ; palette editor, part 2
        sta sprdata+7*4+1   ; update tile of selected subpalette
        lda paedcrp         ; update cursor Y position
        asl a
        asl a
        asl a
        adc #(24*8-1)       ; carry is always clear
        sta sprdata+5*4+0
        jsr usplofs         ; update sixteens tile of color number
        lda userpal,x
        lsr a
        lsr a
        lsr a
        lsr a
        sta sprdata+9*4+1
        lda userpal,x       ; update ones tile of color number
        and #%00001111
        sta sprdata+10*4+1

        jsr usplofs      ; tell NMI routine to update 5 VRAM bytes
        pha
        ldx vrbufpo
        lda #$3f         ; selected color -> background palette
        sta vrbufhi+1,x
        pla
        sta vrbuflo+1,x
        tay
        lda userpal,y
        sta vrbufva+1,x
        lda #$3f         ; 1st color of all subpalettes
        sta vrbufhi+2,x
        lda #$12
        sta vrbuflo+2,x
        lda userpal+0
        sta vrbufva+2,x
        lda paedsbp      ; subpal offset in user palette -> Y
        asl a
        asl a
        tay
        lda #$3f         ; 2nd color of selected subpalette
        sta vrbufhi+3,x
        lda #$16
        sta vrbuflo+3,x
        lda userpal+1,y
        sta vrbufva+3,x
        lda #$3f         ; 3rd color of selected subpalette
        sta vrbufhi+4,x
        lda #$1a
        sta vrbuflo+4,x
        lda userpal+2,y
        sta vrbufva+4,x
        lda #$3f         ; 4th color of selected subpalette
        sta vrbufhi+5,x
        lda #$1e
        sta vrbuflo+5,x
        lda userpal+3,y
        sta vrbufva+5,x
        txa              ; update buffer pointer
        clc
        adc #5
        sta vrbufpo

        rts

usplofs lda paedcrp  ; offset to user palette (userpal or VRAM $3f00-$3f0f) -> A, X
        beq +        ; if 1st color of any subpal, zero
        lda paedsbp  ; else, subpalette * 4 + cursor pos
        asl a
        asl a
        ora paedcrp
+       tax
        rts

; --- Subroutines used by many parts of the program -----------------------------------------------

hidespr lda #$ff       ; hide some sprites (X = first index on sprite page, Y = count)
-       sta sprdata,x
        inx
        inx
        inx
        inx
        dey
        bne -
        rts

; --- Interrupt routines --------------------------------------------------------------------------

nmi     pha            ; push A, X (note: not Y)
        txa
        pha
        bit ppustat    ; reset ppuaddr/ppuscro latch
        lda #$00       ; do OAM DMA
        sta oamaddr
        lda #>sprdata
        sta oamdma

        ldx #0         ; update VRAM from buffer
-       lda vrbufhi,x  ; high byte of address (0 = terminator)
        beq +
        sta ppuaddr
        lda vrbuflo,x  ; low byte of address
        sta ppuaddr
        lda vrbufva,x  ; value
        sta ppudata
        inx
        jmp -

+       lda #$00       ; clear VRAM buffer (put terminator at beginning)
        sta vrbufhi+0
        sta ppuaddr    ; reset PPU address
        sta ppuaddr
        sta ppuscro    ; set PPU scroll
        lda #vscroll
        sta ppuscro
        sec            ; set flag to let main loop run once
        ror runmain
        pla            ; pull X, A
        tax
        pla

irq     rti

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
