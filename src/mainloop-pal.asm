; Kalle Paint - main loop - palette edit mode

main_loop_palette_editor:
    ; ignore buttons if anything was pressed on previous frame
    lda prev_joypad_status
    beq +
    jmp main_loop_palette_editor_part2

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

    jmp main_loop_palette_editor_part2

; --------------------------------------------------------------------------------------------------

enter_paint_mode:
    ; Switch to paint mode.

    ; hide sprites from #5 on (#1-#4 are already hidden)
    lda #$ff
    ldx #(initial_sprite_data_end - initial_sprite_data - 6 * 4)
-   sta sprite_data + 5 * 4 + 0, x
    dex
    dex
    dex
    dex
    bpl -

    lda #0
    sta mode
    rts

; --------------------------------------------------------------------------------------------------

pal_cycle_subpal:
    ; Cycle between subpalettes (0 -> 1 -> 2 -> 3 -> 0) and update tile of number sprite.

    lda palette_subpal
    clc
    adc #1
    and #%00000011
    sta palette_subpal
    sta sprite_data + 13 * 4 + 1
    jmp main_loop_palette_editor_part2

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
    bpl main_loop_palette_editor_part2  ; unconditional

; --------------------------------------------------------------------------------------------------

pal_minus1:
    jsr get_user_pal_offset  ; to X
    ldy user_palette, x
    dey
    jmp +
pal_plus1:
    jsr get_user_pal_offset  ; to X
    ldy user_palette, x
    iny
+   tya
    and #%00001111
    sta bitop_temp
    lda user_palette, x
    and #%00110000
    ora bitop_temp
    sta user_palette, x
    bpl main_loop_palette_editor_part2  ; unconditional

pal_minus16:
    jsr get_user_pal_offset  ; to X
    ldy user_palette, x
    tya
    sec
    sbc #$10
    jmp +
pal_plus16:
    jsr get_user_pal_offset  ; to X
    ldy user_palette, x
    tya
    clc
    adc #$10
+   and #%00111111
    sta user_palette, x
    ; fall through

; --------------------------------------------------------------------------------------------------

main_loop_palette_editor_part2:
    ldx palette_cursor

    ; update cursor Y position
    txa
    asl
    asl
    asl
    clc
    adc #(15 * 8 - 1)
    sta sprite_data + 5 * 4 + 0

    ; update tiles of color number 16s and ones
    ;
    jsr get_user_pal_offset
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
    ;
    lda #$3f
    sta vram_buffer, y
    iny
    ;
    lda palette_cursor
    beq +
    lda palette_subpal
    asl
    asl
    ora palette_cursor
+   sta vram_buffer, y
    iny
    ;
    tax
    lda user_palette_offsets, x
    tax
    lda user_palette, x
    sta vram_buffer, y
    iny
    ;
    ; 1st color of all user subpals -> 3rd color of 1st sprite subpal
    ;
    lda #$3f
    sta vram_buffer, y
    iny
    ;
    lda #$12
    sta vram_buffer, y
    iny
    ;
    lda user_palette + 0
    sta vram_buffer, y
    iny
    ;
    ; 2nd color of selected user subpal -> 3rd color of 2nd sprite subpal
    ;
    lda palette_subpal
    asl
    adc palette_subpal  ; carry is always clear
    tax
    ;
    lda #$3f
    sta vram_buffer, y
    iny
    ;
    lda #$16
    sta vram_buffer, y
    iny
    ;
    lda user_palette + 1, x
    sta vram_buffer, y
    iny
    ;
    ; 3rd color of selected user subpal -> 3rd color of 3rd sprite subpal (use X from before)
    ;
    lda #$3f
    sta vram_buffer, y
    iny
    ;
    lda #$1a
    sta vram_buffer, y
    iny
    ;
    lda user_palette + 2, x
    sta vram_buffer, y
    iny
    ;
    ; 4th color of selected user subpal -> 3rd color of 4th sprite subpal (use X from before)
    ;
    lda #$3f
    sta vram_buffer, y
    iny
    ;
    lda #$1e
    sta vram_buffer, y
    iny
    ;
    lda user_palette + 3, x
    sta vram_buffer, y
    iny
    ;
    sty vram_buffer_pos

    rts

; --------------------------------------------------------------------------------------------------

get_user_pal_offset:
    ; get offset to user_palette:
    ; user_palette_offsets[palette_subpal * 4 + palette_cursor] -> X

    lda palette_subpal
    asl
    asl
    ora palette_cursor
    tax
    lda user_palette_offsets, x
    tax
    rts

user_palette_offsets:
    ; offset to VRAM $3f00-$3f0f -> offset to user_palette (1 + 4 * 3 bytes)
    db 0,  1,  2,  3
    db 0,  4,  5,  6
    db 0,  7,  8,  9
    db 0, 10, 11, 12

