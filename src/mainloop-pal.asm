; Kalle Paint - main loop - palette edit mode

    ; ignore buttons if anything was pressed on previous frame
    lda prev_joypad_status
    beq +
    bne palette_edit_mode_part2  ; unconditional

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

    beq palette_edit_mode_part2  ; unconditional

; --------------------------------------------------------------------------------------------------

enter_paint_mode
    ; Switch to paint mode.

    ; hide palette editor sprites
    ldx #(5 * 4)
    ldy #25
    jsr hide_sprites  ; X=first*4, Y=count

    ; switch mode
    copy_via_a #0, mode

    rts

; --------------------------------------------------------------------------------------------------

pal_cycle_subpal
    ; Cycle between subpalettes (0 -> 1 -> 2 -> 3 -> 0).

    lda palette_subpal
    adc #0  ; carry is always set
    and #%00000011
    sta palette_subpal
    bpl palette_edit_mode_part2  ; unconditional

; --------------------------------------------------------------------------------------------------

pal_down
    ldx palette_cursor
    inx
    bpl pal_store  ; unconditional
pal_up
    ldx palette_cursor
    dex
pal_store
    txa
    and #%00000011
    sta palette_cursor
    tax
    bpl palette_edit_mode_part2  ; unconditional

; --------------------------------------------------------------------------------------------------

pal_plus1
    jsr get_user_pal_offset  ; A, X
    ldy user_palette, x
    iny
    bpl pal_storesmall  ; unconditional
pal_minus1
    jsr get_user_pal_offset  ; A, X
    ldy user_palette, x
    dey
pal_storesmall
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

pal_plus16
    jsr get_user_pal_offset  ; A, X
    lda user_palette, x
    add #$10
    bpl pal_storelarge  ; unconditional
pal_minus16
    jsr get_user_pal_offset  ; A, X
    lda user_palette, x
    sub #$10
pal_storelarge
    and #%00111111
    sta user_palette, x
    ;
    bpl palette_edit_mode_part2  ; unconditional

; --------------------------------------------------------------------------------------------------

palette_edit_mode_part2
    ; update tile of selected subpalette
    lda #tile_digits
    add palette_subpal
    sta sprite_data + 13 * 4 + 1

    ; update cursor Y position
    lda palette_cursor
    asl
    asl
    asl
    adc #(15 * 8 - 1)  ; carry is always clear
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

    ; tell NMI to update 5 bytes in VRAM
    ;
    jsr get_user_pal_offset  ; A, X
    pha
    ;
    ldx vram_buffer_pos
    ;
    ; selected color in selected subpal -> background palette
    ;
    lda #$3f
    sta vram_buffer_addrhi + 1, x
    pla
    sta vram_buffer_addrlo + 1, x
    tay
    lda user_palette, y
    sta vram_buffer_value + 1, x
    ;
    ; 1st color of all subpalettes
    ;
    lda #$3f
    sta vram_buffer_addrhi + 2, x
    lda #$12
    sta vram_buffer_addrlo + 2, x
    lda user_palette + 0
    sta vram_buffer_value + 2, x
    ;
    ; offset of selected subpalette in user_palette -> Y
    lda palette_subpal
    asl
    asl
    tay
    ;
    ; 2nd color of selected subpalette
    ;
    lda #$3f
    sta vram_buffer_addrhi + 3, x
    lda #$16
    sta vram_buffer_addrlo + 3, x
    lda user_palette + 1, y
    sta vram_buffer_value + 3, x
    ;
    ; 3rd color of selected subpalette
    ;
    lda #$3f
    sta vram_buffer_addrhi + 4, x
    lda #$1a
    sta vram_buffer_addrlo + 4, x
    lda user_palette + 2, y
    sta vram_buffer_value + 4, x
    ;
    ; 4th color of selected subpalette
    ;
    lda #$3f
    sta vram_buffer_addrhi + 5, x
    lda #$1e
    sta vram_buffer_addrlo + 5, x
    lda user_palette + 3, y
    sta vram_buffer_value + 5, x
    ;
    txa
    add #5
    sta vram_buffer_pos

    rts

