; Kalle Paint (NES, ASM6)

; --- Constants -----------------------------------------------------------------------------------

; Note: flag variables: $00-$7f = false, $80-$ff = true.
; Note: all address variables (2 bytes) are little endian (low byte, high byte).

; RAM
vram_offset     equ $00    ; 2 bytes (offset to name/attribute table 0 and vram_copy; 0...$3ff)
vram_copy_addr  equ $02    ; 2 bytes (address: vram_copy...vram_copy+$3ff)
mode            equ $04    ; 0 = paint, 1 = attribute editor, 2 = palette editor
run_main_loop   equ $05    ; flag (true = main loop allowed to run)
pad_status      equ $06    ; first joypad status (bits: A B select start up down left right)
prev_pad_status equ $07    ; first joypad status on previous frame
delay_left      equ $08    ; cursor move delay left (paint mode)
brush_size      equ $09    ; cursor type in paint mode (0=small, 1=big)
cursor_x        equ $0a    ; cursor X position (paint/attribute edit mode; 0-63)
cursor_y        equ $0b    ; cursor Y position (paint/attribute edit mode; 0-55)
paint_color     equ $0c    ; selected color (paint mode; 0-3)
paled_cursor    equ $0d    ; cursor position (palette edit mode; 0-3)
paled_subpal    equ $0e    ; selected subpalette (palette edit mode; 0-3)
blink_timer     equ $0f    ; cursor blink timer (attribute/palette edit mode)
vram_buf_pos    equ $10    ; offset of last byte written to vram_buf_adhi etc.
temp            equ $11    ; temporary
user_palette    equ $12    ; 16 bytes (each $00-$3f; offsets 4/8/12 are unused)
; what to update in VRAM on next VBlank (up to 64 bytes each):
vram_buf_adhi   equ $22    ; high bytes of addresses (0 = terminator)
vram_buf_adlo   equ $62    ; low bytes of addresses
vram_buf_val    equ $a2    ; values
spr_data        equ $0200  ; $100 bytes (see initial_spr_data for layout)
vram_copy       equ $0300  ; $400 bytes (copy of name/attribute table 0; must be at $xx00)

; memory-mapped registers; see https://wiki.nesdev.org/w/index.php/PPU_registers
ppu_ctrl   equ $2000
ppu_mask   equ $2001
ppu_status equ $2002
oam_addr   equ $2003
ppu_scroll equ $2005
ppu_addr   equ $2006
ppu_data   equ $2007
dmc_freq   equ $4010
oam_dma    equ $4014
snd_chn    equ $4015
joypad1    equ $4016
joypad2    equ $4017

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
defcol_bg equ $0f  ; background (all subpalettes)
defcol0a  equ $15
defcol0b  equ $25
defcol0c  equ $35
defcol1a  equ $18
defcol1b  equ $28
defcol1c  equ $38
defcol2a  equ $1b
defcol2b  equ $2b
defcol2c  equ $3b
defcol3a  equ $12
defcol3b  equ $22
defcol3c  equ $32

; sprite tile indexes (hexadecimal digits "0"..."F" must start at $00)
tile_smacur equ $10  ; cursor - small
tile_bigcur equ $11  ; cursor - large
tile_atrcur equ $12  ; cursor - corner of attribute cursor
tile_cover  equ $13  ; cover (palette editor)
tile_p      equ $14  ; "P"
tile_colind equ $15  ; color indicator (palette editor)

; other
editor_bg   equ $0f  ; palette editor background color / blinking cursor 1 (black)
editor_text equ $30  ; palette editor text color / blinking cursor 2 (white)
blink_rate  equ 4    ; attribute/palette editor cursor blink rate (0=fastest, 7=slowest)
delay       equ 10   ; paint cursor move repeat delay (frames)

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

macro wait_vblank_start
        bit ppu_status  ; wait until next VBlank starts
-       bit ppu_status
        bpl -
endm

reset   ; initialize the NES; see https://wiki.nesdev.org/w/index.php/Init_code
        sei           ; ignore IRQs
        cld           ; disable decimal mode
        ldx #$40
        stx joypad2   ; disable APU frame IRQ
        ldx #$ff
        txs           ; initialize stack pointer
        inx
        stx ppu_ctrl  ; disable NMI
        stx ppu_mask  ; disable rendering
        stx dmc_freq  ; disable DMC IRQs
        stx snd_chn   ; disable sound channels

        wait_vblank_start

        lda #$00              ; clear zero page and vram_copy
        tax
        ldx #0
-       sta $00,x
        sta vram_copy,x
        sta vram_copy+$100,x
        sta vram_copy+$200,x
        sta vram_copy+$300,x
        inx
        bne -

        ldx #(16-1)             ; init user palette
-       lda initial_palette,x
        sta user_palette,x
        dex
        bpl -

        ldx #(24*4-1)           ; init sprite data
-       lda initial_spr_data,x
        sta spr_data,x
        dex
        bpl -

        ldx #(1*4)        ; hide sprites except paint cursor (#0)
        ldy #63
        jsr hide_sprites  ; X = first byte index, Y = count

        lda #30           ; init misc vars
        sta cursor_x
        lda #26
        sta cursor_y
        inc paint_color

        wait_vblank_start

        lda #$3f               ; init PPU palette
        sta ppu_addr
        ldx #$00
        stx ppu_addr
-       lda initial_palette,x
        sta ppu_data
        inx
        cpx #32
        bne -

        lda #$20      ; clear name/attribute table 0 ($400 bytes)
        sta ppu_addr
        lda #$00
        sta ppu_addr
        ldy #4
--      tax
-       sta ppu_data
        inx
        bne -
        dey
        bne --

        bit ppu_status  ; reset ppu_addr/ppu_scroll latch
        lda #$00        ; reset PPU address and set scroll
        sta ppu_addr
        sta ppu_addr
        sta ppu_scroll
        lda #(256-8)
        sta ppu_scroll

        wait_vblank_start

        ; enable NMI,
        ; use 8*8-pixel sprites,
        ; use pattern table 0 for background and 1 for sprites,
        ; use 1-byte VRAM address auto-increment,
        ; use name table 0
        lda #%10001000
        sta ppu_ctrl

        ; show background and sprites on entire screen,
        ; don't use R/G/B de-emphasis or grayscale mode
        lda #%00011110
        sta ppu_mask

main_loop
        bit run_main_loop  ; wait until NMI routine has run
        bpl main_loop

        lsr run_main_loop  ; clear flag to prevent main loop from running before next NMI

        lda pad_status       ; store previous joypad status
        sta prev_pad_status

        ldx #$01         ; read first joypad
        stx pad_status   ; initialize; set LSB of variable to detect end of loop
        stx joypad1
        dex
        stx joypad1
-       clc              ; read 8 buttons; each one = OR of two LSBs
        lda joypad1
        and #%00000011
        beq +
        sec
+       rol pad_status
        bcc -

        lda #$3f              ; tell NMI to update blinking cursor in VRAM (first item in vram_buf)
        sta vram_buf_adhi+0
        lda #$13
        sta vram_buf_adlo+0
        ldx #editor_bg
        lda blink_timer
        and #(1<<blink_rate)
        beq +
        ldx #editor_text
+       stx vram_buf_val+0
        lda #0                ; store pos of last byte written
        sta vram_buf_pos

        inc blink_timer

        jsr jump_engine  ; run code for the mode we're in

        ldx vram_buf_pos       ; append terminator to VRAM buffer
        lda #$00
        sta vram_buf_adhi+1,x

        beq main_loop          ; unconditional

initial_palette
        ; background (also the initial user palette)
        db defcol_bg, defcol0a, defcol0b, defcol0c
        db defcol_bg, defcol1a, defcol1b, defcol1c
        db defcol_bg, defcol2a, defcol2b, defcol2c
        db defcol_bg, defcol3a, defcol3b, defcol3c
        ; sprites
        ; all subpalettes used for selected colors in palette editor (TODO: elaborate)
        ; 1st one also used for all cursors         (4th color = foreground)
        ; 2nd one also used for palette editor text (4th color = foreground)
        db defcol_bg, editor_bg, defcol_bg,    defcol0a
        db defcol_bg, editor_bg,  defcol0a, editor_text
        db defcol_bg, editor_bg,  defcol0b,   defcol_bg
        db defcol_bg, editor_bg,  defcol0c,   defcol_bg

initial_spr_data  ; initial sprite data (Y, tile, attributes, X for each sprite)
        ; paint mode
        db    $ff, tile_smacur, %00000000,    0  ; #0:  cursor
        ; attribute editor
        db    $ff, tile_atrcur, %00000000,    0  ; #1:  cursor top left
        db    $ff, tile_atrcur, %01000000,    0  ; #2:  cursor top right
        db    $ff, tile_atrcur, %10000000,    0  ; #3:  cursor bottom left
        db    $ff, tile_atrcur, %11000000,    0  ; #4:  cursor bottom right
        ; palette editor
        db    $ff, tile_bigcur, %00000000, 29*8  ; #5:  cursor
        db 22*8-1,      tile_p, %00000001, 28*8  ; #6:  "P"
        db 22*8-1,         $00, %00000001, 30*8  ; #7:  subpalette number
        db 23*8-1,         $0c, %00000001, 28*8  ; #8:  "C"
        db 23*8-1,         $00, %00000001, 29*8  ; #9:  color number - 16s
        db 23*8-1,         $00, %00000001, 30*8  ; #10: color number - ones
        db 24*8-1, tile_colind, %00000000, 29*8  ; #11: color 0
        db 25*8-1, tile_colind, %00000001, 29*8  ; #12: color 1
        db 26*8-1, tile_colind, %00000010, 29*8  ; #13: color 2
        db 27*8-1, tile_colind, %00000011, 29*8  ; #14: color 3
        db 22*8-1,  tile_cover, %00000001, 29*8  ; #15: cover (to left  of subpal number)
        db 24*8-1,  tile_cover, %00000001, 28*8  ; #16: cover (to left  of color 0)
        db 24*8-1,  tile_cover, %00000001, 30*8  ; #17: cover (to right of color 0)
        db 25*8-1,  tile_cover, %00000001, 28*8  ; #18: cover (to left  of color 1)
        db 25*8-1,  tile_cover, %00000001, 30*8  ; #19: cover (to right of color 1)
        db 26*8-1,  tile_cover, %00000001, 28*8  ; #20: cover (to left  of color 2)
        db 26*8-1,  tile_cover, %00000001, 30*8  ; #21: cover (to right of color 2)
        db 27*8-1,  tile_cover, %00000001, 28*8  ; #22: cover (to left  of color 3)
        db 27*8-1,  tile_cover, %00000001, 30*8  ; #23: cover (to right of color 3)

jump_engine            ; run one subroutine depending on the mode we're in; don't inline this sub
        ldx mode       ; push target address minus one, high byte first
        lda jmptblh,x
        pha
        lda jmptbll,x
        pha
        rts            ; pull address, low byte first; jump to that address plus one

jmptblh dh paintmd-1, attribute_edit_mode-1, paledit-1  ; jump table high
jmptbll dl paintmd-1, attribute_edit_mode-1, paledit-1  ; jump table low

; --- Paint mode ----------------------------------------------------------------------------------

paintmd lda prev_pad_status         ; ignore select, B, start if any pressed on prev frame
        and #(pad_sl|pad_b|pad_st)
        bne paarrow
        lda pad_status              ; if select pressed, switch to attribute editor
        and #pad_sl
        bne paexit                  ; ends with rts
        lda pad_status              ; if B pressed, cycle paint color (0->1->2->3->0)
        and #pad_b
        beq +
        ldx paint_color
        inx
        txa
        and #%00000011
        sta paint_color
+       lda pad_status              ; if start pressed, toggle cursor size
        and #pad_st
        beq +
        lda brush_size
        eor #%00000001
        sta brush_size
        beq +
        lsr cursor_x                ; make coordinates even
        asl cursor_x
        lsr cursor_y
        asl cursor_y
+

paarrow lda pad_status                  ; arrow logic
        and #(pad_u|pad_d|pad_l|pad_r)  ; if none pressed, clear cursor move delay
        bne +
        sta delay_left
        beq paintm2                     ; unconditional; ends with rts
+       lda delay_left                  ; else if delay > 0, decrement it
        beq +
        dec delay_left
        bpl paintm2                     ; unconditional; ends with rts
+       jsr pachekh                     ; else react to arrows, reinit cursor move delay
        lda #delay
        sta delay_left
        bne paintm2                     ; unconditional; ends with rts

paexit  lda #$ff          ; switch to attribute edit mode
        sta spr_data+0+0  ; hide paint cursor sprite
        lda cursor_x      ; make cursor coordinates a multiple of four
        and #%00111100
        sta cursor_x
        lda cursor_y
        and #%00111100
        sta cursor_y
        inc mode
        rts

pachekh lda pad_status  ; react to horizontal arrows, change cursor_x
        lsr a
        bcs +
        lsr a
        bcs ++
        bcc pachekv     ; unconditional
+       lda cursor_x    ; right arrow
        sec
        adc brush_size
        bpl +++         ; unconditional
++      lda cursor_x    ; left arrow
        clc
        sbc brush_size
+++     and #%00111111  ; store horizontal pos
        sta cursor_x

pachekv lda pad_status  ; react to vertical arrows, change cursor_y
        lsr a
        lsr a
        lsr a
        bcs +
        lsr a
        bcs ++
        rts
+       lda cursor_y    ; down arrow
        sec
        adc brush_size
        cmp #56
        bne +++
        lda #0
        beq +++         ; unconditional
++      lda cursor_y    ; up arrow
        clc
        sbc brush_size
        bpl +++
        lda #56
        clc
        sbc brush_size
+++     sta cursor_y    ; store vertical pos
        rts

paintm2 lda pad_status     ; paint mode, part 2
        and #pad_a         ; if A pressed, tell NMI routine to paint
        beq +
        jsr prepare_paint

+       lda cursor_x        ; update cursor sprite (X pos, Y pos, tile)
        asl a
        asl a
        sta spr_data+0+3
        lda cursor_y
        asl a
        asl a
        adc #(8-1)          ; carry is always clear
        sta spr_data+0+0
        ldx brush_size
        lda cursor_tiles,x
        sta spr_data+0+1

        jsr get_cursor_color  ; tell NMI to update paint color to cursor
        pha
        inc vram_buf_pos
        ldx vram_buf_pos
        lda #$3f
        sta vram_buf_adhi,x
        lda #$13
        sta vram_buf_adlo,x
        pla
        sta vram_buf_val,x

        rts

cursor_tiles
        db tile_smacur, tile_bigcur  ; brush_size -> paint cursor tile

prepare_paint
        ; Prepare a paint operation to be done by NMI routine. (Used by paint_mode_part2.)
        ; Note: we've scrolled screen vertically so that VRAM $2000 is at top left of visible area.

        ; compute vram_offset for a name table byte; bits:
        ; cursor_y = 00ABCDEF, cursor_x = 00abcdef -> vram_offset = 000000AB CDEabcde
        ;
        lda cursor_y       ; 00ABCDEF
        lsr a
        pha                ; 000ABCDE
        lsr a
        lsr a
        lsr a
        sta vram_offset+1  ; 000000AB
        ;
        pla                ; 000ABCDE
        and #%00000111     ; 00000CDE
        lsr a
        ror a
        ror a              ; DE000000, carry=C
        ora cursor_x       ; DEabcdef, carry=C
        ror a
        sta vram_offset+0  ; CDEabcde

        jsr get_vram_copy_addr

        lda brush_size      ; get byte to write
        beq +               ; small cursor -> replace a bit pair

        ldx paint_color     ; big cursor -> replace entire byte
        lda solid_tiles,x   ; get tile of solid color X
        jmp tileupd

+       ldy #0                  ; push the original byte in which a bit pair will be replaced
        lda (vram_copy_addr),y
        pha
        lda cursor_x            ; pixel position within tile (0-3) -> X
        lsr a
        lda cursor_y
        rol a
        and #%00000011
        tax
        lda pixel_masks,x       ; AND mask for clearing a bit pair -> temp
        eor #%11111111
        sta temp
        ldy paint_color         ; OR mask for setting a bit pair -> X
        lda solid_tiles,y
        and pixel_masks,x
        tax
        pla                     ; restore original byte, clear bit pair, insert new bit pair
        and temp
        stx temp
        ora temp

tileupd ldy #0                     ; update byte and tell NMI to copy A to VRAM
        sta (vram_copy_addr),y
        jsr vram_update_to_buffer
        rts

solid_tiles
        db %00000000, %01010101, %10101010, %11111111  ; tiles of solid color 0-3
pixel_masks
        db %11000000, %00110000, %00001100, %00000011  ; bitmasks for pixels within tile index

; TODO: reformat rest of code as above.

get_cursor_color
        ; Get color for cursor. Used by paintm2.
        ; In: cursor_x, cursor_y, vram_buf, user_palette; out: A.

        ; if color 0 of any subpal, no need to read vram_copy
        ldx paint_color
        beq ++

        jsr get_attr_vram_offset
        jsr get_pos_in_attr_byte  ; 0/2/4/6 to X

        ; read attribute byte, shift relevant bits to positions 1-0, clear other bits
        ; TODO: do this as above, without a loop?
        ldy #0
        lda (vram_copy_addr),y
        cpx #0
        beq +
-       lsr a
        dex
        bne -
+       and #%00000011

        ; get user_palette index
        asl a
        asl a
        ora paint_color
        tax

++      lda user_palette,x
        rts

; --- Attribute editor ----------------------------------------------------------------------------

attribute_edit_mode
        ; ignore buttons if anything was pressed on previous frame
        lda prev_pad_status
        bne attr_buttons_done

        ; if select pressed, enter palette editor
        lda pad_status
        and #pad_sl
        bne attr_exit      ; ends with rts

        ; otherwise if A pressed, tell NMI to update attribute byte
        lda pad_status
        and #pad_a
        beq +
        jsr prepare_attr_change
        jmp attr_buttons_done

        ; otherwise, check arrows
+       jsr attr_check_arrows

attr_buttons_done
        ; update cursor sprite
        ;
        ; X
        lda cursor_x
        asl a
        asl a
        sta spr_data+4+3
        sta spr_data+3*4+3
        adc #8                     ; carry is always clear
        sta spr_data+2*4+3
        sta spr_data+4*4+3
        ;
        ; Y
        lda cursor_y
        asl a
        asl a
        adc #(8-1)               ; carry is always clear
        sta spr_data+4+0
        sta spr_data+2*4+0
        adc #8                     ; carry is always clear
        sta spr_data+3*4+0
        sta spr_data+4*4+0

        rts

attr_exit
        ; Switch to palette edit mode.

        ; reset palette cursor position and selected subpalette
        lda #0
        sta paled_cursor
        sta paled_subpal

        ; hide attribute editor sprites (#1-#4)
        ldx #(1*4)
        ldy #4
        jsr hide_sprites  ; X = first byte index, Y = count

        ; show palette editor sprites (#5-#23)
-       lda initial_spr_data,x
        sta spr_data,x
        inx
        inx
        inx
        inx
        cpx #(24*4)
        bne -

        ; switch mode
        inc mode

        rts

prepare_attr_change
        ; Prepare to cycle attribute value (0 -> 1 -> 2 -> 3 -> 0) of selected 2*2-tile block.
        ; Note: we've scrolled screen vertically so that VRAM $2000 is at top left of visible area.

        jsr get_attr_vram_offset
        jsr get_pos_in_attr_byte  ; 0/2/4/6 to X

        ; get byte to modify
        ldy #0
        lda (vram_copy_addr),y

        ; increment one bit pair in a byte without modifying other bits
        ; (algorithm: if LSB clear, only flip it, otherwise flip MSB too)
        pha
        and bitpair_increment_masks,x
        beq +
        inx                             ; LSB was set; increment LUT index to flip both bits
+       pla
        eor bitpair_increment_masks,x

        ; store modified byte
        ldy #0
        sta (vram_copy_addr),y

        jsr vram_update_to_buffer  ; tell NMI to copy A to VRAM
        rts

bitpair_increment_masks
        ; LSB or both LSB and MSB of each bit pair
        db %00000001, %00000011
        db %00000100, %00001100
        db %00010000, %00110000
        db %01000000, %11000000

attr_check_arrows
        ; React to arrows (excluding diagonal directions).
        ; Reads: pad_status, cursor_x, cursor_y
        ; Changes: cursor_x, cursor_y

        lda pad_status
        lsr a
        bcs attr_right
        lsr a
        bcs attr_left
        lsr a
        bcs attr_down
        lsr a
        bcs attr_up
        rts

attr_right
        lda cursor_x
        adc #(4-1)         ; carry is always set
        bcc attr_store_horz  ; unconditional
attr_left
        lda cursor_x
        sbc #4               ; carry is always set
attr_store_horz              ; store horizontal
        and #%00111111
        sta cursor_x
        rts

attr_down
        lda cursor_y
        adc #(4-1)         ; carry is always set
        cmp #56
        bne attr_store_vert
        lda #0
        beq attr_store_vert  ; unconditional
attr_up
        lda cursor_y
        sbc #4               ; carry is always set
        bpl attr_store_vert
        lda #(56-4)
attr_store_vert              ; store vertical
        sta cursor_y
        rts

; --- Subroutines used by both paint mode and attribute editor ------------------------------------

get_pos_in_attr_byte
        ; Get position within attribute byte.
        ; bits: cursor_y = 00ABCDEF, cursor_x = 00abcdef -> X = 00000Dd0
        ; 0 = top left, 2 = top right, 4 = bottom left, 6 = bottom right.

        lda cursor_y
        and #%00000100  ; 00000D00
        lsr a           ; 000000D0
        tax

        lda cursor_x
        and #%00000100  ; 00000d00
        cmp #%00000100  ; d -> carry
        txa
        adc #0          ; 000000Dd
        asl a           ; 00000Dd0
        tax

        rts

get_attr_vram_offset
        ; Compute vram_offset for an attribute table byte and fall through to get_vram_copy_addr.
        ; Bits: cursor_y = 00ABCDEF, cursor_x = 00abcdef
        ;       -> vram_offset = $3c0 + 00ABCabc = 00000011 11ABCabc

        lda #%00000011
        sta vram_offset+1

        lda cursor_y
        and #%00111000       ; 00ABC000
        sta temp
        lda cursor_x
        lsr a
        lsr a
        lsr a                ; 00000abc
        ora temp             ; 00ABCabc
        ora #%11000000       ; 11ABCabc
        sta vram_offset+0

get_vram_copy_addr
        ; vram_copy + vram_offset -> vram_copy_addr (vram_copy must be at $xx00)

        lda vram_offset+0
        sta vram_copy_addr+0
        ;
        lda #>vram_copy
        clc
        adc vram_offset+1
        sta vram_copy_addr+1

        rts

vram_update_to_buffer
        ; Tell NMI routine to write A to VRAM $2000 + vram_offset.

        pha
        inc vram_buf_pos
        ldx vram_buf_pos
        ;
        lda #$20
        ora vram_offset+1
        sta vram_buf_adhi,x
        lda vram_offset+0
        sta vram_buf_adlo,x
        pla
        sta vram_buf_val,x

        rts

; --- Palette editor ------------------------------------------------------------------------------

paledit ; ignore buttons if anything was pressed on previous frame
        lda prev_pad_status
        bne paledi2

        lda pad_status
        lsr a
        bcs peinc1      ; right
        lsr a
        bcs pedec1      ; left
        lsr a
        bcs pedn        ; down
        lsr a
        bcs peup        ; up
        lsr a
        bcs pesubp      ; start
        lsr a
        bcs peexit      ; select; ends with rts
        lsr a
        bcs pedec16     ; B
        bne peinc16     ; A

        beq paledi2     ; unconditional

peexit  ldx #(5*4)        ; exit palette editor (switch to paint mode)
        ldy #19           ; hide palette editor sprites (#5-#23)
        jsr hide_sprites  ; X = first byte index, Y = count
        lda #0
        sta mode
        rts

pesubp  lda paled_subpal  ; cycle subpalette (0 -> 1 -> 2 -> 3 -> 0)
        adc #0            ; carry is always set
        and #%00000011
        sta paled_subpal
        bpl paledi2       ; unconditional

pedn    ldx paled_cursor  ; move down
        inx
        bpl pestov        ; unconditional
peup    ldx paled_cursor  ; move up
        dex
pestov  txa               ; store vertical
        and #%00000011
        sta paled_cursor
        tax
        bpl paledi2       ; unconditional

peinc1  jsr get_usr_pal_offs  ; increment ones
        ldy user_palette,x
        iny
        bpl pesto1            ; unconditional
pedec1  jsr get_usr_pal_offs  ; decrement ones
        ldy user_palette,x
        dey
pesto1  tya                   ; store ones
        and #%00001111
        sta temp
        lda user_palette,x
        and #%00110000
        ora temp
        sta user_palette,x
        bpl paledi2           ; unconditional

peinc16 jsr get_usr_pal_offs  ; increment sixteens
        lda user_palette,x
        clc
        adc #$10
        bpl pesto16           ; unconditional
pedec16 jsr get_usr_pal_offs  ; decrement sixteens
        lda user_palette,x
        sec
        sbc #$10
pesto16 and #%00111111        ; store sixteens
        sta user_palette,x
        bpl paledi2           ; unconditional

paledi2 lda paled_subpal      ; palette editor, part 2
        sta spr_data+7*4+1    ; update tile of selected subpalette
        lda paled_cursor      ; update cursor Y position
        asl a
        asl a
        asl a
        adc #(24*8-1)       ; carry is always clear
        sta spr_data+5*4+0
        jsr get_usr_pal_offs  ; update tiles of color number
        lda user_palette,x   ; sixteens
        lsr a
        lsr a
        lsr a
        lsr a
        sta spr_data+9*4+1
        lda user_palette,x   ; ones
        and #%00001111
        sta spr_data+10*4+1

        jsr get_usr_pal_offs  ; tell NMI to update 5 VRAM bytes
        pha
        ldx vram_buf_pos
        lda #$3f                    ; selected color -> background palette
        sta vram_buf_adhi+1,x
        pla
        sta vram_buf_adlo+1,x
        tay
        lda user_palette,y
        sta vram_buf_val+1,x
        ;
        ; 1st color of all subpalettes
        lda #$3f
        sta vram_buf_adhi+2,x
        lda #$12
        sta vram_buf_adlo+2,x
        lda user_palette+0
        sta vram_buf_val+2,x
        ;
        ; offset of selected subpalette in user_palette -> Y
        lda paled_subpal
        asl a
        asl a
        tay
        ;
        ; 2nd color of selected subpalette
        lda #$3f
        sta vram_buf_adhi+3,x
        lda #$16
        sta vram_buf_adlo+3,x
        lda user_palette+1,y
        sta vram_buf_val+3,x
        ;
        ; 3rd color of selected subpalette
        lda #$3f
        sta vram_buf_adhi+4,x
        lda #$1a
        sta vram_buf_adlo+4,x
        lda user_palette+2,y
        sta vram_buf_val+4,x
        ;
        ; 4th color of selected subpalette
        lda #$3f
        sta vram_buf_adhi+5,x
        lda #$1e
        sta vram_buf_adlo+5,x
        lda user_palette+3,y
        sta vram_buf_val+5,x
        ;
        txa
        clc
        adc #5
        sta vram_buf_pos

        rts

get_usr_pal_offs
        ; Get offset to user_palette or VRAM $3f00-$3f0f.
        ;     if paled_cursor = 0: 0
        ;     else:                paled_subpal*4 + paled_cursor
        ; Out: A, X

        lda paled_cursor
        beq +
        lda paled_subpal
        asl a
        asl a
        ora paled_cursor
+       tax
        rts

; --- Subroutines used by many parts of the program -----------------------------------------------

hide_sprites
        ; X = first index on sprite page, Y = count

        lda #$ff
-       sta spr_data,x
        inx
        inx
        inx
        inx
        dey
        bne -

        rts

; --- Interrupt routines --------------------------------------------------------------------------

nmi     pha  ; push A, X (note: not Y)
        txa
        pha

        bit ppu_status     ; reset ppu_addr/ppu_scroll latch

        lda #$00           ; do OAM DMA
        sta oam_addr
        lda #>spr_data
        sta oam_dma

        ; update VRAM from buffer
        ldx #0
-       lda vram_buf_adhi,x   ; high byte of address
        beq +                       ; 0 = terminator
        sta ppu_addr
        lda vram_buf_adlo,x   ; low byte of address
        sta ppu_addr
        lda vram_buf_val,x    ; data byte
        sta ppu_data
        inx
        jmp -

+       lda #$00
        sta vram_buf_adhi+0  ; clear buffer (put terminator at beginning)
        sta ppu_addr                ; reset PPU address
        sta ppu_addr
        sta ppu_scroll              ; set PPU scroll
        lda #(256-8)
        sta ppu_scroll

        sec                ; set flag to let main loop run once
        ror run_main_loop

        pla  ; pull X, A
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
