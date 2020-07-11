; Kalle Paint - main loop - palette edit mode

main_loop_palette_edit_mode:
    ; get color at cursor
    ldx palette_cursor
    ldy user_palette, x

    ; ignore all buttons if anything was pressed on previous frame
    lda prev_joypad_status
    bne update_palette_editor_sprite_data  ; ends with rts

    lda joypad_status
    lsr
    bcs small_color_increment  ; right
    lsr
    bcs small_color_decrement  ; left
    lsr
    bcs palette_cursor_down    ; down
    lsr
    bcs palette_cursor_up      ; up
    lsr
    lsr
    bcs exit_palette_editor    ; select; ends with rts
    lsr
    bcs large_color_decrement  ; B
    bne large_color_increment  ; A

    ; nothing pressed
    jmp update_palette_editor_sprite_data  ; ends with rts

; --------------------------------------------------------------------------------------------------

palette_cursor_up:
    dex
    dex
palette_cursor_down:
    inx
    txa
    and #%00000011
    sta palette_cursor
    tax
    jmp update_palette_editor_sprite_data  ; ends with rts

small_color_decrement:
    dey
    dey
small_color_increment:
    iny
    tya
    and #$0f
    sta temp
    lda user_palette, x
    and #$f0
    ora temp
    sta user_palette, x
    jmp update_palette_editor_sprite_data  ; ends with rts

large_color_decrement:
    tya
    sec
    sbc #$10
    jmp +
large_color_increment:
    tya
    clc
    adc #$10
+   and #%00111111
    sta user_palette, x
    jmp update_palette_editor_sprite_data  ; ends with rts

; --------------------------------------------------------------------------------------------------

exit_palette_editor:
    ; show paint cursor
    lda initial_sprite_data + 0 * 4 + 0
    sta sprite_data + 0 * 4 + 0

    ; hide all palette editor sprites
    lda #$ff
    ldx #((palette_editor_sprite_count - 1) * 4)
-   sta sprite_data + paint_mode_sprite_count * 4, x
    dex
    dex
    dex
    dex
    bpl -

    lsr in_palette_editor  ; clear flag
    rts

; --------------------------------------------------------------------------------------------------

update_palette_editor_sprite_data:
    ; Update palette editor sprite data.
    ; Reads: palette_cursor, user_palette
    ; Writes: sprite_data

    ldx palette_cursor

    ; cursor sprite Y position
    txa
    asl
    asl
    asl
    clc
    adc #(22 * 8 - 1)
    sta sprite_data + paint_mode_sprite_count * 4 + 0

    ; 16s of color number (sprite tile)
    lda user_palette, x
    lsr
    lsr
    lsr
    lsr
    sta sprite_data + (paint_mode_sprite_count + 5) * 4 + 1

    ; ones of color number (sprite tile)
    lda user_palette, x
    and #$0f
    sta sprite_data + (paint_mode_sprite_count + 6) * 4 + 1

    rts

