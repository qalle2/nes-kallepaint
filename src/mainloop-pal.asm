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
    lda #0
    sta mode

    rts

; --------------------------------------------------------------------------------------------------

pal_cycle_subpal:
    ; Cycle between subpalettes (0 -> 1 -> 2 -> 3 -> 0).

    lda palette_subpal
    clc
    adc #1
    and #%00000011
    sta palette_subpal
    bpl palette_edit_mode_part2  ; unconditional

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
    bpl palette_edit_mode_part2  ; unconditional

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
+   tya
    and #%00001111
    sta bitop_temp
    lda user_palette, x
    and #%00110000
    ora bitop_temp
    sta user_palette, x
    bpl palette_edit_mode_part2  ; unconditional

pal_minus16:
    jsr get_user_pal_offset  ; A, X
    ldy user_palette, x
    tya
    sec
    sbc #$10
    jmp +
pal_plus16:
    jsr get_user_pal_offset  ; A, X
    ldy user_palette, x
    tya
    clc
    adc #$10
+   and #%00111111
    sta user_palette, x
    ; fall through

; --------------------------------------------------------------------------------------------------

palette_edit_mode_part2:
    ; update tile of selected subpalette
    lda palette_subpal
    sta sprite_data + 13 * 4 + 1

    ; update cursor Y position
    ldx palette_cursor
    txa
    asl
    asl
    asl
    clc
    adc #(15 * 8 - 1)
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
    sta sprite_data + 15 * 4 + 1
    ;
    lda user_palette, x
    and #%00001111
    sta sprite_data + 16 * 4 + 1

    ; tell NMI to update VRAM
    ;
    ldy vram_buffer_pos
    ;
    ; selected color in selected subpal -> background palette
    lda #$3f
    a_to_vram_buffer
    jsr get_user_pal_offset  ; A, X
    a_to_vram_buffer
    lda user_palette, x
    a_to_vram_buffer
    ;
    ; 1st color of all user subpals -> 3rd color of 1st sprite subpal
    lda #$3f
    a_to_vram_buffer
    lda #$12
    a_to_vram_buffer
    lda user_palette + 0
    a_to_vram_buffer
    ;
    ; offset of selected subpalette in user_palette -> X
    lda palette_subpal
    asl
    asl
    tax
    ;
    ; 2nd color of selected user subpal -> 3rd color of 2nd sprite subpal
    lda #$3f
    a_to_vram_buffer
    lda #$16
    a_to_vram_buffer
    lda user_palette + 1, x
    a_to_vram_buffer
    ;
    ; 3rd color of selected user subpal -> 3rd color of 3rd sprite subpal
    lda #$3f
    a_to_vram_buffer
    lda #$1a
    a_to_vram_buffer
    lda user_palette + 2, x
    a_to_vram_buffer
    ;
    ; 4th color of selected user subpal -> 3rd color of 4th sprite subpal
    lda #$3f
    a_to_vram_buffer
    lda #$1e
    a_to_vram_buffer
    lda user_palette + 3, x
    a_to_vram_buffer
    ;
    sty vram_buffer_pos

    rts

