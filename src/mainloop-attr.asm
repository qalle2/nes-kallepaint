; Kalle Paint - main loop - attribute editor

attribute_edit_mode
        ; ignore buttons if anything was pressed on previous frame
        lda prev_joypad_status
        bne attr_buttons_done

        ; if select pressed, enter palette editor
        lda joypad_status
        and #button_select
        beq +
        bne enter_palette_editor  ; unconditional; ends with rts

        ; otherwise if A pressed, tell NMI to update attribute byte
+       lda joypad_status
        and #button_a
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
        asl
        asl
        sta sprite_data + 4 + 3
        sta sprite_data + 3 * 4 + 3
        adc #8                       ; carry is always clear
        sta sprite_data + 2 * 4 + 3
        sta sprite_data + 4 * 4 + 3
        ;
        ; Y
        lda cursor_y
        asl
        asl
        adc #(8 - 1)                 ; carry is always clear
        sta sprite_data + 4 + 0
        sta sprite_data + 2 * 4 + 0
        adc #8                       ; carry is always clear
        sta sprite_data + 3 * 4 + 0
        sta sprite_data + 4 * 4 + 0

        rts

; --------------------------------------------------------------------------------------------------

enter_palette_editor
        ; Switch to palette edit mode.

        ; reset palette cursor position and selected subpalette
        lda #0
        sta palette_cursor
        sta palette_subpal

        ; hide attribute editor sprites (#1-#4)
        lda #$ff
        ldx #(1 * 4)
-       sta sprite_data, x
        inx
        inx
        inx
        inx
        cpx #(5 * 4)
        bne -

        ; show palette editor sprites (#5-#23)
-       lda initial_sprite_data, x
        sta sprite_data, x
        inx
        inx
        inx
        inx
        cpx #(24 * 4)
        bne -

        ; switch mode
        inc mode

        rts

; --------------------------------------------------------------------------------------------------

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

; --------------------------------------------------------------------------------------------------

attr_check_arrows
        ; React to arrows (excluding diagonal directions).
        ; Reads: joypad_status, cursor_x, cursor_y
        ; Changes: cursor_x, cursor_y

        lda joypad_status
        lsr
        bcs attr_right
        lsr
        bcs attr_left
        lsr
        bcs attr_down
        lsr
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
