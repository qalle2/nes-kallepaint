; Kalle Paint - main loop - palette edit mode

palette_edit_mode:
    ; ignore buttons if anything was pressed on previous frame
    lda prev_joypad_status
    beq +
    jmp palette_edit_mode_part2

+   lda joypad_status
    lsr
    bcs pal_plus1         ; right
    lsr
    bcs pal_minus1        ; left
    lsr
    bcs pal_down
    lsr
    bcs pal_up
    lsr
    bcs pal_cycle_subpal  ; start
    lsr
    bcs enter_paint_mode  ; select; ends with rts
    lsr
    bcs pal_minus16       ; B
    bne pal_plus16        ; A

    jmp palette_edit_mode_part2

; --------------------------------------------------------------------------------------------------

enter_paint_mode:
    ; Switch to paint mode.

    ; hide palette editor sprites
    ldx #(5 * 4)
    ldy #25
    jsr hide_sprites  ; X=first*4, Y=count

    ; switch mode
    copy #0, mode

    rts

; --------------------------------------------------------------------------------------------------

pal_cycle_subpal:
    ; Cycle between subpalettes (0 -> 1 -> 2 -> 3 -> 0).

    lda palette_subpal
    add #1
    and #%00000011
    sta palette_subpal
    jmp palette_edit_mode_part2

; --------------------------------------------------------------------------------------------------

pal_up:
    ldx palette_cursor
    dex
    jmp +
pal_down:
    ldx palette_cursor
    inx
+   txa
    and #%00000011
    sta palette_cursor
    tax
    jmp palette_edit_mode_part2

; --------------------------------------------------------------------------------------------------

pal_minus1:
    jsr get_user_pal_offset  ; A, X
    ldy user_palette, x
    dey
    jmp +
pal_plus1:
    jsr get_user_pal_offset  ; A, X
    ldy user_palette, x
    iny
    ;
+   tya
    and #%00001111
    tay
    ;
    lda user_palette, x
    and #%00110000
    ora identity_table, y
    sta user_palette, x
    ;
    jmp palette_edit_mode_part2

pal_minus16:
    jsr get_user_pal_offset  ; A, X
    lda user_palette, x
    sub #$10
    jmp +
pal_plus16:
    jsr get_user_pal_offset  ; A, X
    lda user_palette, x
    add #$10
    ;
+   and #%00111111
    sta user_palette, x
    ;
    jmp palette_edit_mode_part2

; --------------------------------------------------------------------------------------------------

palette_edit_mode_part2:
    ; update tile of selected subpalette
    lda #tile_digits
    add palette_subpal
    sta sprite_data + 13 * 4 + 1

    ; update cursor Y position
    lda palette_cursor
    asl
    asl
    asl
    add #(15 * 8 - 1)
    sta sprite_data + 5 * 4 + 0

    ; update tiles of color number 16s and ones
    ;
    jsr get_user_pal_offset  ; A, X
    ;
    lda user_palette, x
    lsr
    lsr
    lsr
    lsr
    add #tile_digits
    sta sprite_data + 15 * 4 + 1
    ;
    lda user_palette, x
    and #%00001111
    add #tile_digits
    sta sprite_data + 16 * 4 + 1

    ; tell NMI to update VRAM
    ;
    jsr get_user_pal_offset  ; A, X
    pha
    ;
    ldx vram_buffer_pos
    ;
    ; selected color in selected subpal -> background palette
    lda #$3f
    write_vram_buffer
    pla
    write_vram_buffer
    tay
    lda user_palette, y
    write_vram_buffer
    ;
    ; 1st color of all subpalettes
    write_vram_buffer_addr $3f00 + 4 * 4 + 2
    lda user_palette + 0
    write_vram_buffer
    ;
    ; offset of selected subpalette in user_palette -> Y
    lda palette_subpal
    asl
    asl
    tay
    ;
    ; 2nd color of selected subpalette
    write_vram_buffer_addr $3f00 + 5 * 4 + 2
    lda user_palette + 1, y
    write_vram_buffer
    ;
    ; 3rd color of selected subpalette
    write_vram_buffer_addr $3f00 + 6 * 4 + 2
    lda user_palette + 2, y
    write_vram_buffer
    ;
    ; 4th color of selected subpalette
    write_vram_buffer_addr $3f00 + 7 * 4 + 2
    lda user_palette + 3, y
    write_vram_buffer
    ;
    stx vram_buffer_pos

    rts

