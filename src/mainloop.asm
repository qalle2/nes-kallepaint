; Kalle Paint - main loop

main_loop
    ; wait until NMI routine has run
    bit run_main_loop
    bpl main_loop

    ; prevent main loop from running again until after next NMI
    lsr run_main_loop

    ; store previous joypad status
    lda joypad_status
    sta prev_joypad_status

    ; initialize joypads; set LSB of variable to detect end of loop
    ldx #$01
    stx joypad_status
    stx joypad1
    dex
    stx joypad1

    ; read 1st joypad 8 times; for each button, compute OR of bits 1 and 0
    ; bits of joypad_status: A, B, select, start, up, down, left, right
-   clc
    lda joypad1
    and #%00000011
    beq +
    sec
+   rol joypad_status
    bcc -

    ; tell NMI routine to update blinking cursor (this is the first item in vram_buffer)
    ;
    lda #$3f
    sta vram_buffer + 0
    lda #$13
    sta vram_buffer + 1
    jsr get_blinking_cursor_color
    sta vram_buffer + 2
    ;
    ; store position of last byte written
    lda #2
    sta vram_buffer_pos

    inc blink_timer

    jsr jump_engine

    ; terminate VRAM buffer
    ldx vram_buffer_pos
    lda #$00
    sta vram_buffer + 1, x

    beq main_loop  ; unconditional

; --------------------------------------------------------------------------------------------------

jump_engine
    ; Run one subroutine depending on the mode we're in. Note: this routine must not be inlined.

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

paint_mode
    include "mainloop-paint.asm"
attribute_edit_mode
    include "mainloop-attr.asm"
palette_edit_mode
    include "mainloop-pal.asm"

; --- Misc subs ------------------------------------------------------------------------------------

get_blinking_cursor_color
    ; Get color for blinking cursor. Don't touch X. Out: A.

    ldy #editor_bg
    lda blink_timer
    and #(1 << blink_rate)
    beq +
    ldy #editor_text
+   tya
    rts

hide_sprites
    ; Hide sprites by setting their Y positions to $ff.
    ; X: first sprite, times four
    ; Y: number of sprites

    lda #$ff
-   sta sprite_data, x
    rept 4
        inx
    endr
    dey
    bne -
    rts

show_sprites
    ; Show sprites by copying their Y positions from initial data.
    ; X: first sprite, times four
    ; Y: number of sprites

-   lda initial_sprite_data, x
    sta sprite_data, x
    rept 4
        inx
    endr
    dey
    bne -
    rts

get_decimal_tens_tile
    ; A: unsigned integer -> tile index of decimal tens
    ldx #$ff
    sec
-   inx
    sbc #10
    bcs -
    txa
    adc #tile_digits  ; carry is always clear
    rts

get_decimal_ones_tile
    ; A: unsigned integer -> tile index of decimal ones
    sec
-   sbc #10
    bcs -
    adc #(10 + tile_digits)  ; carry is always clear
    rts

get_pos_in_attr_byte
    ; Get position within attribute byte. (Used in paint/attribute edit mode.)
    ; bits: cursor_y = 00ABCDEF, cursor_x = 00abcdef -> X = 00000Dd0
    ; 0 = top left, 2 = top right, 4 = bottom left, 6 = bottom right.

    lda cursor_y
    and #%00000100
    lsr
    tax             ; 000000D0

    lda cursor_x
    and #%00000100  ; 00000d00
    cmp #%00000100  ; d -> carry
    txa
    adc #0          ; 000000Dd
    asl
    tax

    rts

get_vram_offset_for_nt
    ; Compute vram_offset for a name table byte. (Used in paint mode.)
    ; Bits: cursor_y = 00ABCDEF, cursor_x = 00abcdef
    ;       -> vram_offset = 000000AB CDEabcde

    lda cursor_y
    lsr
    lsr
    lsr
    lsr
    sta vram_offset + 1

    lda cursor_y
    and #%00001110
    asl
    asl
    asl
    asl
    sta temp
    lda cursor_x
    lsr
    ora temp
    sta vram_offset + 0

    rts

get_vram_offset_for_at
    ; Compute vram_offset for an attribute table byte. (Used in paint/attribute edit mode.)
    ; Bits: cursor_y = 00ABCDEF, cursor_x = 00abcdef
    ;       -> vram_offset = $3c0 + 00ABCabc = 00000011 11ABCabc

    lda #%00000011
    sta vram_offset + 1

    lda cursor_y
    and #%00111000
    sta temp
    lda cursor_x
    lsr
    lsr
    lsr
    ora temp
    ora #%11000000
    sta vram_offset + 0

    rts

get_vram_copy_addr
    ; vram_copy + vram_offset -> vram_copy_addr (vram_copy must be at $xx00)
    ; (used in paint/attribute edit mode)

    lda vram_offset + 0
    sta vram_copy_addr + 0
    ;
    lda #>vram_copy
    add vram_offset + 1
    sta vram_copy_addr + 1

    rts

nt_at_update_to_vram_buffer
    ; Tell NMI routine to write A to VRAM $2000 + vram_offset.
    ; (Used in paint/attribute edit mode.)

    pha

    ldx vram_buffer_pos
    ;
    lda vram_offset + 1
    ora #$20
    sta vram_buffer + 1, x
    lda vram_offset + 0
    sta vram_buffer + 2, x
    pla
    sta vram_buffer + 3, x
    ;
    inx
    inx
    inx
    stx vram_buffer_pos

    rts

get_user_pal_offset
    ; Get offset to user_palette or VRAM $3f00-$3f0f.
    ; (Used in palette editor.)
    ;   if palette_cursor = 0: 0
    ;   else:                  palette_subpal * 4 + palette_cursor
    ; Out: A, X

    lda palette_cursor
    beq +
    lda palette_subpal
    asl
    asl
    ora palette_cursor
+   tax
    rts

