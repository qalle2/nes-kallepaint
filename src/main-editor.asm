; Kalle Paint - main loop - palette edit mode

main_editor:
    ; get color at cursor
    ldx palette_cursor
    ldy user_palette, x

    ; ignore buttons if anything was pressed on previous frame
    lda prev_joypad_status
    bne editor_buttons_done

    lda joypad_status
    lsr
    bcs editor_plus1    ; right
    lsr
    bcs editor_minus1   ; left
    lsr
    bcs editor_down
    lsr
    bcs editor_up
    lsr
    lsr
    bcs exit_editor     ; select; ends with rts
    lsr
    bcs editor_minus16  ; B
    bne editor_plus16   ; A

editor_buttons_done:
    ldx palette_cursor

    ; update cursor Y position
    txa
    asl
    asl
    asl
    clc
    adc #(14 * 8 - 1)
    sta sprite_data + 0 + 0

    ; update tile of color number 16s
    lda user_palette, x
    lsr
    lsr
    lsr
    lsr
    sta sprite_data + 8 * 4 + 1

    ; update tile of color number ones
    lda user_palette, x
    and #$0f
    sta sprite_data + 9 * 4 + 1

    ; advance cursor blink timer
    inc blink_timer
    rts

; --------------------------------------------------------------------------------------------------

exit_editor:
    ; hide all sprites except first one
    lda #$ff
    ldx #(initial_sprite_data_end - initial_sprite_data - 2 * 4)
-   sta sprite_data + 4 + 0, x
    dex
    dex
    dex
    dex
    bpl -

    ; clear flag
    lsr in_palette_editor

    rts

; --------------------------------------------------------------------------------------------------

editor_up:
    dex
    dex
editor_down:
    inx
    txa
    and #$03
    sta palette_cursor
    tax
    bpl editor_buttons_done  ; unconditional

editor_minus1:
    dey
    dey
editor_plus1:
    iny
    tya
    and #$0f
    sta temp
    lda user_palette, x
    and #$f0
    ora temp
    sta user_palette, x
    bpl editor_buttons_done  ; unconditional

editor_minus16:
    tya
    sec
    sbc #$10
    jmp +
editor_plus16:
    tya
    clc
    adc #$10
+   and #%00111111
    sta user_palette, x
    bpl editor_buttons_done  ; unconditional

