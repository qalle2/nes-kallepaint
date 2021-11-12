; Kalle Paint (NES, ASM6)

; --- Constants -----------------------------------------------------------------------------------

; Note: flag variables: $00-$7f = false, $80-$ff = true.
; Note: all address variables (2 bytes) are little endian (low byte, high byte).

; RAM
vram_offset        equ $00    ; 2 bytes (offset to name/attribute table 0 and vram_copy; 0...$3ff)
vram_copy_addr     equ $02    ; 2 bytes (address: vram_copy...vram_copy+$3ff)
mode               equ $04    ; 0 = paint, 1 = attribute editor, 2 = palette editor
run_main_loop      equ $05    ; flag (true = main loop allowed to run)
joypad_status      equ $06    ; first joypad status (bits: A B select start up down left right)
prev_joypad_status equ $07    ; first joypad status on previous frame
delay_left         equ $08    ; cursor move delay left (paint mode)
paint_cursor_type  equ $09    ; cursor type (paint mode; 0=small, 1=big)
cursor_x           equ $0a    ; cursor X position (paint/attribute edit mode; 0-63)
cursor_y           equ $0b    ; cursor Y position (paint/attribute edit mode; 0-55)
paint_color        equ $0c    ; selected color (paint mode; 0-3)
palette_cursor     equ $0d    ; cursor position (palette edit mode; 0-3)
palette_subpal     equ $0e    ; selected subpalette (palette edit mode; 0-3)
blink_timer        equ $0f    ; cursor blink timer (attribute/palette edit mode)
vram_buffer_pos    equ $10    ; offset of last byte written to vram_buffer_addrhi etc.
temp               equ $11    ; temporary
user_palette       equ $12    ; 16 bytes (each $00-$3f; offsets 4/8/12 are unused)
;                               what to update in VRAM on next VBlank (up to 64 bytes each):
vram_buffer_addrhi equ $22    ; high bytes of addresses (0 = terminator)
vram_buffer_addrlo equ $62    ; low bytes of addresses
vram_buffer_value  equ $a2    ; values
sprite_data        equ $0200  ; $100 bytes (see initial_sprite_data for layout)
vram_copy          equ $0300  ; $400 bytes (copy of name/attribute table 0; must be at $xx00)

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
pad_a      equ 1 << 7
pad_b      equ 1 << 6
pad_select equ 1 << 5
pad_start  equ 1 << 4
pad_up     equ 1 << 3
pad_down   equ 1 << 2
pad_left   equ 1 << 1
pad_right  equ 1 << 0

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
tile_smallcur equ $10  ; cursor - small
tile_largecur equ $11  ; cursor - large
tile_attrcur  equ $12  ; cursor - corner of attribute cursor
tile_cover    equ $13  ; cover (palette editor)
tile_p        equ $14  ; "P"
tile_colorind equ $15  ; color indicator (palette editor)

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

        ; wait until next VBlank starts
        bit ppu_status
-       bit ppu_status
        bpl -

        ; clear zero page and vram_copy
        lda #$00
        tax
        ldx #0
-       sta $00, x
        sta vram_copy, x
        sta vram_copy + $100, x
        sta vram_copy + $200, x
        sta vram_copy + $300, x
        inx
        bne -

        ; initialize nonzero variables
        ;
        ldx #(16 - 1)
-       lda initial_palette, x
        sta user_palette, x
        dex
        bpl -
        ;
        ldx #(24*4 - 1)
-       lda initial_sprite_data, x
        sta sprite_data, x
        dex
        bpl -
        ;
        ; hide sprites except paint cursor (#0)
        ldx #(1*4)
        ldy #63
        jsr hide_sprites  ; X = first byte index, Y = count
        ;
        ; misc
        lda #30
        sta cursor_x
        lda #26
        sta cursor_y
        inc paint_color

        ; wait until next VBlank starts
        bit ppu_status
-       bit ppu_status
        bpl -

        ; set palette
        lda #$3f
        sta ppu_addr
        ldx #$00
        stx ppu_addr
-       lda initial_palette, x
        sta ppu_data
        inx
        cpx #32
        bne -

        ; clear name/attribute table 0 ($400 bytes)
        lda #$20
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

        ; reset PPU address and scroll
        bit ppu_status  ; reset ppu_addr/ppu_scroll latch
        lda #$00
        sta ppu_addr
        sta ppu_addr
        sta ppu_scroll
        lda #(256 - 8)
        sta ppu_scroll

        ; wait until next VBlank starts
        bit ppu_status
-       bit ppu_status
        bpl -

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
        ; wait until NMI routine has run
        bit run_main_loop
        bpl main_loop

        ; clear flag to prevent main loop from running again until after next NMI
        lsr run_main_loop

        ; store previous joypad status
        lda joypad_status
        sta prev_joypad_status

        ; read first joypad
        ;
        ; initialize; set LSB of variable to detect end of loop
        ldx #$01
        stx joypad_status
        stx joypad1
        dex
        stx joypad1
        ; read 1st joypad 8 times; for each button, compute OR of two LSBs
        ; bits of joypad_status: A, B, select, start, up, down, left, right
-       clc
        lda joypad1
        and #%00000011
        beq +
        sec
+       rol joypad_status
        bcc -

        ; tell NMI routine to update blinking cursor (this is the first item in vram_buffer)
        ;
        lda #$3f
        sta vram_buffer_addrhi + 0
        lda #$13
        sta vram_buffer_addrlo + 0
        ;
        ldx #editor_bg
        lda blink_timer
        and #(1 << blink_rate)
        beq +
        ldx #editor_text
+       stx vram_buffer_value + 0
        ;
        lda #0               ; store position of last byte written
        sta vram_buffer_pos

        inc blink_timer

        jsr jump_engine

        ; terminate VRAM buffer (append terminator)
        ldx vram_buffer_pos
        lda #$00
        sta vram_buffer_addrhi + 1, x

        beq main_loop  ; unconditional

initial_palette
        ; background (also the initial user palette)
        db defcol_bg, defcol0a, defcol0b, defcol0c
        db defcol_bg, defcol1a, defcol1b, defcol1c
        db defcol_bg, defcol2a, defcol2b, defcol2c
        db defcol_bg, defcol3a, defcol3b, defcol3c
        ;
        ; sprites
        ; all subpalettes used for selected colors in palette editor
        ; 1st one also used for all cursors         (4th color = foreground)
        ; 2nd one also used for palette editor text (4th color = foreground)
        db defcol_bg, editor_bg, defcol_bg, defcol0a
        db defcol_bg, editor_bg, defcol0a,  editor_text
        db defcol_bg, editor_bg, defcol0b,  defcol_bg
        db defcol_bg, editor_bg, defcol0c,  defcol_bg

initial_sprite_data
        ; Y, tile, attributes, X

        ; paint mode
        db $ff, tile_smallcur, %00000000, 0  ; #0: cursor

        ; attribute editor
        db $ff, tile_attrcur, %00000000, 0  ; #1: cursor top left
        db $ff, tile_attrcur, %01000000, 0  ; #2: cursor top right
        db $ff, tile_attrcur, %10000000, 0  ; #3: cursor bottom left
        db $ff, tile_attrcur, %11000000, 0  ; #4: cursor bottom right

        ; palette editor
        db      $ff, tile_largecur, %00000000, 29*8  ; #5:  cursor
        db 22*8 - 1, tile_p,        %00000001, 28*8  ; #6:  "P"
        db 22*8 - 1, $00,           %00000001, 30*8  ; #7:  subpalette number
        db 23*8 - 1, $0c,           %00000001, 28*8  ; #8:  "C"
        db 23*8 - 1, $00,           %00000001, 29*8  ; #9:  color number - 16s
        db 23*8 - 1, $00,           %00000001, 30*8  ; #10: color number - ones
        db 24*8 - 1, tile_colorind, %00000000, 29*8  ; #11: color 0
        db 25*8 - 1, tile_colorind, %00000001, 29*8  ; #12: color 1
        db 26*8 - 1, tile_colorind, %00000010, 29*8  ; #13: color 2
        db 27*8 - 1, tile_colorind, %00000011, 29*8  ; #14: color 3
        db 22*8 - 1, tile_cover,    %00000001, 29*8  ; #15: cover (to left  of subpal number)
        db 24*8 - 1, tile_cover,    %00000001, 28*8  ; #16: cover (to left  of color 0)
        db 24*8 - 1, tile_cover,    %00000001, 30*8  ; #17: cover (to right of color 0)
        db 25*8 - 1, tile_cover,    %00000001, 28*8  ; #18: cover (to left  of color 1)
        db 25*8 - 1, tile_cover,    %00000001, 30*8  ; #19: cover (to right of color 1)
        db 26*8 - 1, tile_cover,    %00000001, 28*8  ; #20: cover (to left  of color 2)
        db 26*8 - 1, tile_cover,    %00000001, 30*8  ; #21: cover (to right of color 2)
        db 27*8 - 1, tile_cover,    %00000001, 28*8  ; #22: cover (to left  of color 3)
        db 27*8 - 1, tile_cover,    %00000001, 30*8  ; #23: cover (to right of color 3)

jump_engine
        ; Run one subroutine depending on the mode we're in. Note: don't inline this sub.

        ; push target address minus one, high byte first
        ldx mode
        lda jump_table_hi, x
        pha
        lda jump_table_lo, x
        pha
        ;
        ; pull address, low byte first; jump to that address plus one
        rts

jump_table_hi
        dh paint_mode - 1, attribute_edit_mode - 1, palette_edit_mode - 1
jump_table_lo
        dl paint_mode - 1, attribute_edit_mode - 1, palette_edit_mode - 1

; --- Paint mode ----------------------------------------------------------------------------------

paint_mode
        ; ignore select, B and start if any of them was pressed on previous frame
        lda prev_joypad_status
        and #(pad_select | pad_b | pad_start)
        bne paint_arrowlogic

        ; if select pressed, enter attribute editor (and ignore other buttons)
        lda joypad_status
        and #pad_select
        beq +
        bne paint_exit  ; unconditional; ends with rts

        ; if B pressed, cycle between 4 colors (0 -> 1 -> 2 -> 3 -> 0)
+       lda joypad_status
        and #pad_b
        beq +
        ldx paint_color
        inx
        txa
        and #%00000011
        sta paint_color

        ; if start pressed, toggle between small and big cursor; if big, make coordinates even
+       lda joypad_status
        and #pad_start
        beq +
        lda paint_cursor_type
        eor #%00000001
        sta paint_cursor_type
        beq +
        lsr cursor_x
        asl cursor_x
        lsr cursor_y
        asl cursor_y
+

paint_arrowlogic
        ; if no arrow pressed, clear cursor movement delay
        lda joypad_status
        and #(pad_up | pad_down | pad_left | pad_right)
        bne +
        sta delay_left
        beq paint_mode_part2  ; unconditional; ends with rts
        ;
        ; else if delay > 0, decrement it
+       lda delay_left
        beq +
        dec delay_left
        bpl paint_mode_part2  ; unconditional; ends with rts
        ;
        ; else react to arrows and reinitialize delay
+       jsr paint_check_arrows
        lda #delay
        sta delay_left
        bne paint_mode_part2  ; unconditional; ends with rts

paint_exit
        ; Switch to attribute edit mode.

        ; hide paint cursor sprite
        lda #$ff
        sta sprite_data + 0 + 0

        ; make cursor coordinates a multiple of four
        lda cursor_x
        and #%00111100
        sta cursor_x
        lda cursor_y
        and #%00111100
        sta cursor_y

        ; switch mode
        inc mode

        rts

paint_check_arrows
        ; React to arrows (including diagonal directions).
        ; Changes: cursor_x, cursor_y

        ; check horizontal
        lda joypad_status
        lsr a
        bcs paint_right
        lsr a
        bcs paint_left
        bcc paint_check_vert   ; unconditional
paint_right
        lda cursor_x
        sec
        adc paint_cursor_type
        bpl paint_store_horz   ; unconditional
paint_left
        lda cursor_x
        clc
        sbc paint_cursor_type
paint_store_horz               ; store horizontal
        and #%00111111
        sta cursor_x

paint_check_vert               ; check vertical
        lda joypad_status
        lsr a
        lsr a
        lsr a
        bcs paint_down
        lsr a
        bcs paint_up
        rts
paint_down
        lda cursor_y
        sec
        adc paint_cursor_type
        cmp #56
        bne paint_store_vert
        lda #0
        beq paint_store_vert   ; unconditional
paint_up
        lda cursor_y
        clc
        sbc paint_cursor_type
        bpl paint_store_vert
        lda #56
        clc
        sbc paint_cursor_type
paint_store_vert               ; store vertical
        sta cursor_y
        rts

paint_mode_part2
        ; if A pressed, tell NMI routine to paint
        lda joypad_status
        and #pad_a
        beq +
        jsr prepare_paint

+       ; update cursor sprite
        ;
        ; X
        lda cursor_x
        asl a
        asl a
        sta sprite_data + 0 + 3
        ;
        ; Y
        lda cursor_y
        asl a
        asl a
        adc #(8 - 1)             ; carry is always clear
        sta sprite_data + 0 + 0
        ;
        ; tile
        ldx paint_cursor_type
        lda cursor_tiles, x
        sta sprite_data + 0 + 1

        jsr get_cursor_color  ; to A
        pha

        ; tell NMI to update paint color to cursor
        ;
        inc vram_buffer_pos
        ldx vram_buffer_pos
        ;
        lda #$3f
        sta vram_buffer_addrhi, x
        lda #$13
        sta vram_buffer_addrlo, x
        pla
        sta vram_buffer_value, x

        rts

cursor_tiles
        db tile_smallcur, tile_largecur  ; paint_cursor_type -> paint cursor tile

prepare_paint
        ; Prepare a paint operation to be done by NMI routine. (Used by paint_mode_part2.)
        ; Note: we've scrolled screen vertically so that VRAM $2000 is at top left of visible area.

        ; compute vram_offset for a name table byte; bits:
        ; cursor_y = 00ABCDEF, cursor_x = 00abcdef -> vram_offset = 000000AB CDEabcde
        ;
        lda cursor_y         ; 00ABCDEF
        lsr a
        pha                  ; 000ABCDE
        lsr a
        lsr a
        lsr a
        sta vram_offset + 1  ; 000000AB
        ;
        pla                  ; 000ABCDE
        and #%00000111       ; 00000CDE
        lsr a                ; 000000CD, carry=E
        ror a                ; E000000C, carry=D
        ror a                ; DE000000, carry=C
        ora cursor_x         ; DEabcdef, carry=C
        ror a
        sta vram_offset + 0  ; CDEabcde

        jsr get_vram_copy_addr

        ; get byte to write:
        ; - if cursor is small, replace a bit pair (pixel) in old byte (tile)
        ; - if cursor is big, just replace entire byte (four pixels)
        lda paint_cursor_type
        beq +
        ldx paint_color
        lda solids, x
        jmp overwrite_byte

solids  db %00000000, %01010101, %10101010, %11111111

+       ; read old byte and replace a bit pair
        ;
        ldy #0
        lda (vram_copy_addr), y
        pha
        ;
        ; position within tile (0/2/4/6) -> X
        lda cursor_x
        lsr a           ; LSB to carry
        lda cursor_y
        rol a
        and #%00000011
        eor #%00000011
        asl a
        tax
        ;
        ; shifted AND mask    for clearing bit pair -> temp
        ; shifted paint_color for setting  bit pair -> A
        lda #%11111100
        sta temp
        lda paint_color
        cpx #0
        beq +
-       sec
        rol temp
        asl a
        dex
        bne -
        ;
+       ; pull byte to modify, clear bit pair, insert new bit pair
        tay
        pla
        and temp
        sty temp
        ora temp

        ; overwrite byte and tell NMI to copy A to VRAM
overwrite_byte
        ldy #0
        sta (vram_copy_addr), y
        jsr nt_at_update_to_vram_buffer
        rts

get_cursor_color
        ; Get correct color for cursor. (Used by paint_mode_part2.)
        ; In: cursor_x, cursor_y, vram_buffer, user_palette
        ; Out: A

        ; if color 0 of any subpal, no need to read vram_copy
        ldx paint_color
        beq ++

        jsr get_vram_offset_for_at
        jsr get_vram_copy_addr
        jsr get_pos_in_attr_byte  ; 0/2/4/6 to X

        ; read attribute byte, shift relevant bits to positions 1-0, clear other bits
        ldy #0
        lda (vram_copy_addr), y
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

++      lda user_palette, x
        rts

; --- Attribute editor ----------------------------------------------------------------------------

attribute_edit_mode
        ; ignore buttons if anything was pressed on previous frame
        lda prev_joypad_status
        bne attr_buttons_done

        ; if select pressed, enter palette editor
        lda joypad_status
        and #pad_select
        bne attr_exit      ; ends with rts

        ; otherwise if A pressed, tell NMI to update attribute byte
        lda joypad_status
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
        sta sprite_data + 4 + 3
        sta sprite_data + 3*4 + 3
        adc #8                     ; carry is always clear
        sta sprite_data + 2*4 + 3
        sta sprite_data + 4*4 + 3
        ;
        ; Y
        lda cursor_y
        asl a
        asl a
        adc #(8 - 1)               ; carry is always clear
        sta sprite_data + 4 + 0
        sta sprite_data + 2*4 + 0
        adc #8                     ; carry is always clear
        sta sprite_data + 3*4 + 0
        sta sprite_data + 4*4 + 0

        rts

attr_exit
        ; Switch to palette edit mode.

        ; reset palette cursor position and selected subpalette
        lda #0
        sta palette_cursor
        sta palette_subpal

        ; hide attribute editor sprites (#1-#4)
        ldx #(1*4)
        ldy #4
        jsr hide_sprites  ; X = first byte index, Y = count

        ; show palette editor sprites (#5-#23)
-       lda initial_sprite_data, x
        sta sprite_data, x
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

        jsr get_vram_offset_for_at
        jsr get_vram_copy_addr
        jsr get_pos_in_attr_byte  ; 0/2/4/6 to X

        ; get byte to modify
        ldy #0
        lda (vram_copy_addr), y

        ; increment one bit pair in a byte without modifying other bits
        ; (algorithm: if LSB clear, only flip it, otherwise flip MSB too)
        pha
        and bitpair_increment_masks, x
        beq +
        inx                             ; LSB was set; increment LUT index to flip both bits
+       pla
        eor bitpair_increment_masks, x

        ; store modified byte
        ldy #0
        sta (vram_copy_addr), y

        jsr nt_at_update_to_vram_buffer  ; tell NMI to copy A to VRAM
        rts

bitpair_increment_masks
        ; LSB or both LSB and MSB of each bit pair
        db %00000001, %00000011
        db %00000100, %00001100
        db %00010000, %00110000
        db %01000000, %11000000

attr_check_arrows
        ; React to arrows (excluding diagonal directions).
        ; Reads: joypad_status, cursor_x, cursor_y
        ; Changes: cursor_x, cursor_y

        lda joypad_status
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
        adc #(4 - 1)         ; carry is always set
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
        adc #(4 - 1)         ; carry is always set
        cmp #56
        bne attr_store_vert
        lda #0
        beq attr_store_vert  ; unconditional
attr_up
        lda cursor_y
        sbc #4               ; carry is always set
        bpl attr_store_vert
        lda #(56 - 4)
attr_store_vert              ; store vertical
        sta cursor_y
        rts

; --- Subroutines used by both paint mode and attribute editor ------------------------------------

get_pos_in_attr_byte
        ; Get position within attribute byte.
        ; Used by: paint mode, attribute editor.
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

get_vram_offset_for_at
        ; Compute vram_offset for an attribute table byte.
        ; Used by: paint mode, attribute editor.
        ; Bits: cursor_y = 00ABCDEF, cursor_x = 00abcdef
        ;       -> vram_offset = $3c0 + 00ABCabc = 00000011 11ABCabc

        lda #%00000011
        sta vram_offset + 1

        lda cursor_y
        and #%00111000       ; 00ABC000
        sta temp
        lda cursor_x
        lsr a
        lsr a
        lsr a                ; 00000abc
        ora temp             ; 00ABCabc
        ora #%11000000       ; 11ABCabc
        sta vram_offset + 0

        rts

get_vram_copy_addr
        ; vram_copy + vram_offset -> vram_copy_addr (vram_copy must be at $xx00)
        ; Used by: paint mode, attribute editor.

        lda vram_offset + 0
        sta vram_copy_addr + 0
        ;
        lda #>vram_copy
        clc
        adc vram_offset + 1
        sta vram_copy_addr + 1

        rts

nt_at_update_to_vram_buffer
        ; Tell NMI routine to write A to VRAM $2000 + vram_offset.
        ; Used by: paint mode, attribute editor.

        pha
        inc vram_buffer_pos
        ldx vram_buffer_pos
        ;
        lda #$20
        ora vram_offset + 1
        sta vram_buffer_addrhi, x
        lda vram_offset + 0
        sta vram_buffer_addrlo, x
        pla
        sta vram_buffer_value, x

        rts

; --- Palette editor ------------------------------------------------------------------------------

palette_edit_mode
        ; ignore buttons if anything was pressed on previous frame
        lda prev_joypad_status
        beq +
        bne palette_edit_mode_part2  ; unconditional

+       lda joypad_status
        lsr a
        bcs paled_inc1     ; right
        lsr a
        bcs paled_dec1     ; left
        lsr a
        bcs paled_down     ; down
        lsr a
        bcs paled_up       ; up
        lsr a
        bcs paled_cycle    ; start
        lsr a
        bcs paled_exit     ; select; ends with rts
        lsr a
        bcs paled_dec16    ; B
        bne paled_inc16    ; A

        beq palette_edit_mode_part2  ; unconditional

paled_exit
        ; switch to paint mode

        ; hide palette editor sprites (#5-#23)
        ldx #(5*4)
        ldy #19
        jsr hide_sprites  ; X = first byte index, Y = count

        lda #0    ; switch mode
        sta mode

        rts

paled_cycle                          ; cycle subpalette (0 -> 1 -> 2 -> 3 -> 0)
        lda palette_subpal
        adc #0                       ; carry is always set
        and #%00000011
        sta palette_subpal
        bpl palette_edit_mode_part2  ; unconditional

paled_down                           ; move down
        ldx palette_cursor
        inx
        bpl paled_sto_vert           ; unconditional
paled_up                             ; move up
        ldx palette_cursor
        dex
paled_sto_vert                       ; store vertical
        txa
        and #%00000011
        sta palette_cursor
        tax
        bpl palette_edit_mode_part2  ; unconditional

paled_inc1                           ; increment ones
        jsr get_user_pal_offset      ; to A, X
        ldy user_palette, x
        iny
        bpl paled_store1             ; unconditional
paled_dec1                           ; decrement ones
        jsr get_user_pal_offset      ; to A, X
        ldy user_palette, x
        dey
paled_store1                         ; store ones
        tya
        and #%00001111
        sta temp
        ;
        lda user_palette, x
        and #%00110000
        ora temp
        sta user_palette, x
        ;
        bpl palette_edit_mode_part2  ; unconditional

paled_inc16                          ; increment sixteens
        jsr get_user_pal_offset      ; to A, X
        lda user_palette, x
        clc
        adc #$10
        bpl paled_store16            ; unconditional
paled_dec16                          ; decrement sixteens
        jsr get_user_pal_offset      ; to A, X
        lda user_palette, x
        sec
        sbc #$10
paled_store16                        ; store sixteens
        and #%00111111
        sta user_palette, x
        bpl palette_edit_mode_part2  ; unconditional

palette_edit_mode_part2
        ; update tile of selected subpalette
        lda palette_subpal
        sta sprite_data + 7*4 + 1

        ; update cursor Y position
        lda palette_cursor
        asl a
        asl a
        asl a
        adc #(24*8 - 1)            ; carry is always clear
        sta sprite_data + 5*4 + 0

        ; update tiles of color number 16s and ones
        ;
        jsr get_user_pal_offset  ; to A, X
        ;
        lda user_palette, x
        lsr a
        lsr a
        lsr a
        lsr a
        sta sprite_data + 9*4 + 1
        ;
        lda user_palette, x
        and #%00001111
        sta sprite_data + 10*4 + 1

        ; tell NMI to update 5 bytes in VRAM
        ;
        jsr get_user_pal_offset  ; to A, X
        pha
        ;
        ldx vram_buffer_pos
        ;
        ; selected color in selected subpal -> background palette
        lda #$3f
        sta vram_buffer_addrhi + 1, x
        pla
        sta vram_buffer_addrlo + 1, x
        tay
        lda user_palette, y
        sta vram_buffer_value + 1, x
        ;
        ; 1st color of all subpalettes
        lda #$3f
        sta vram_buffer_addrhi + 2, x
        lda #$12
        sta vram_buffer_addrlo + 2, x
        lda user_palette + 0
        sta vram_buffer_value + 2, x
        ;
        ; offset of selected subpalette in user_palette -> Y
        lda palette_subpal
        asl a
        asl a
        tay
        ;
        ; 2nd color of selected subpalette
        lda #$3f
        sta vram_buffer_addrhi + 3, x
        lda #$16
        sta vram_buffer_addrlo + 3, x
        lda user_palette + 1, y
        sta vram_buffer_value + 3, x
        ;
        ; 3rd color of selected subpalette
        lda #$3f
        sta vram_buffer_addrhi + 4, x
        lda #$1a
        sta vram_buffer_addrlo + 4, x
        lda user_palette + 2, y
        sta vram_buffer_value + 4, x
        ;
        ; 4th color of selected subpalette
        lda #$3f
        sta vram_buffer_addrhi + 5, x
        lda #$1e
        sta vram_buffer_addrlo + 5, x
        lda user_palette + 3, y
        sta vram_buffer_value + 5, x
        ;
        txa
        clc
        adc #5
        sta vram_buffer_pos

        rts

get_user_pal_offset
        ; Get offset to user_palette or VRAM $3f00-$3f0f.
        ;     if palette_cursor = 0: 0
        ;     else:                  palette_subpal*4 + palette_cursor
        ; Out: A, X

        lda palette_cursor
        beq +
        lda palette_subpal
        asl a
        asl a
        ora palette_cursor
+       tax
        rts

; --- Subroutines used by many parts of the program -----------------------------------------------

hide_sprites
        ; X = first index on sprite page, Y = count

        lda #$ff
-       sta sprite_data, x
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
        lda #>sprite_data
        sta oam_dma

        ; update VRAM from buffer
        ldx #0
-       lda vram_buffer_addrhi, x   ; high byte of address
        beq +                       ; 0 = terminator
        sta ppu_addr
        lda vram_buffer_addrlo, x   ; low byte of address
        sta ppu_addr
        lda vram_buffer_value, x    ; data byte
        sta ppu_data
        inx
        jmp -

+       lda #$00
        sta vram_buffer_addrhi + 0  ; clear buffer (put terminator at beginning)
        sta ppu_addr                ; reset PPU address
        sta ppu_addr
        sta ppu_scroll              ; set PPU scroll
        lda #(256 - 8)
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
