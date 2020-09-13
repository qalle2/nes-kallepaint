; Kalle Paint - main loop

main_loop:
    branch_if_flag_clear run_main_loop, main_loop

    clear_flag run_main_loop
    copy_via_a joypad_status, prev_joypad_status
    jsr read_joypad

    ; start writing VRAM buffer (write_vram_buffer preincrements)
    copy_via_a #$ff, vram_buffer_pos

    ; tell NMI routine to update blinking cursor
    ldx vram_buffer_pos
    write_vram_buffer_addr $3f00 + 4 * 4 + 3
    jsr get_blinking_cursor_color             ; A
    write_vram_buffer
    stx vram_buffer_pos

    inc blink_timer

    jsr jump_engine

    ; terminate VRAM buffer
    ldx vram_buffer_pos
    lda #$00
    write_vram_buffer
    stx vram_buffer_pos

    jmp main_loop

; --------------------------------------------------------------------------------------------------

jump_engine:
    ; Run one subroutine depending on the mode we're in. Note: this routine must not be inlined.

    ldx mode
    lda jump_table_hi, x
    pha
    lda jump_table_lo, x
    pha
    rts  ; pull address, low byte first; jump to address + 1

jump_table_hi:
    dh paint_mode - 1, attribute_edit_mode - 1, palette_edit_mode - 1
jump_table_lo:
    dl paint_mode - 1, attribute_edit_mode - 1, palette_edit_mode - 1

    include "mainloop-paint.asm"
    include "mainloop-attr.asm"
    include "mainloop-pal.asm"

; --- Misc subs ------------------------------------------------------------------------------------

read_joypad:
    ; Read the first joypad.
    ; Out: joypad_status (bits: A, B, select, start, up, down, left, right).

    ; initialize joypads; set LSB of variable to detect end of loop
    ldx #$01
    stx joypad_status
    stx joypad1
    dex
    stx joypad1

    ; read the first joypad eight times; each button is the OR of bits 1 and 0
-   clc
    lda joypad1
    and #%00000011
    beq +
    sec
+   rol joypad_status
    bcc -

    rts

get_blinking_cursor_color:
    ; Get color for blinking cursor. Don't touch X. Out: A.

    ldy #editor_bg
    lda blink_timer
    and #(1 << blink_rate)
    beq +
    ldy #editor_text
+   tya
    rts

hide_sprites:
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

show_sprites:
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

get_decimal_tens_tile:
    ; A: unsigned integer -> tile index of decimal tens
    ldx #$ff
-   inx
    sub #10
    bcs -
    txa
    add #tile_digits
    rts

get_decimal_ones_tile:
    ; A: unsigned integer -> tile index of decimal ones
-   sub #10
    bcs -
    add #(10 + tile_digits)
    rts

get_pos_in_attr_byte:
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

get_nt_at_offset_for_nt:
    ; Compute nt_at_offset for a *name table* byte. (Used in paint mode.)
    ; Bits: cursor_y = 00ABCDEF, cursor_x = 00abcdef
    ;       -> nt_at_offset = 000000AB CDEabcde

    lda cursor_y
    lsr
    lsr
    lsr
    lsr
    sta nt_at_offset + 1   ; 000000AB

    lda cursor_y
    and #%00001110
    asl
    asl
    asl
    asl
    tax                    ; CDE00000
    lda cursor_x
    lsr                    ; 000abcde
    ora identity_table, x
    sta nt_at_offset + 0   ; CDEabcde

    rts

get_nt_at_offset_for_at:
    ; Compute nt_at_offset for an *attribute* byte. (Used in paint/attribute edit mode.)
    ; Bits: cursor_y = 00ABCDEF, cursor_x = 00abcdef
    ;       -> nt_at_offset = $3c0 + 00ABCabc = 00000011 11ABCabc

    copy_via_a #%00000011, nt_at_offset + 1

    lda cursor_y
    and #%00111000
    tax                    ; 00ABC000
    lda cursor_x
    lsr
    lsr
    lsr                    ; 00000abc
    ora identity_table, x  ; 00ABCabc
    ora #%11000000         ; 11ABCabc
    sta nt_at_offset + 0

    rts

get_nt_at_buffer_addr:
    ; Get nt_at_buffer_addr from nt_at_offset. (nt_at_buffer must start at $xx00.)
    ; (Used in paint/attribute edit mode.)

    copy_via_a nt_at_offset + 0, nt_at_buffer_addr + 0
    lda #>nt_at_buffer
    add nt_at_offset + 1
    sta nt_at_buffer_addr + 1

    rts

nt_at_update_to_vram_buffer:
    ; Tell NMI routine to write A to VRAM $2000 + nt_at_offset.
    ; (Used in paint/attribute edit mode.)

    pha

    ldx vram_buffer_pos
    ;
    lda nt_at_offset + 1
    ora #$20
    write_vram_buffer
    lda nt_at_offset + 0
    write_vram_buffer
    pla
    write_vram_buffer
    ;
    stx vram_buffer_pos

    rts

get_user_pal_offset:
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

