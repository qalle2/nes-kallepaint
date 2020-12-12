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
        adc #8  ; carry is always clear
        sta sprite_data + 2 * 4 + 3
        sta sprite_data + 4 * 4 + 3
        ;
        ; Y
        lda cursor_y
        asl
        asl
        adc #(8 - 1)  ; carry is always clear
        sta sprite_data + 4 + 0
        sta sprite_data + 2 * 4 + 0
        adc #8  ; carry is always clear
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

        lda #$ff            ; hide attribute editor sprites
        ldx #(1 * 4)
-       sta sprite_data, x
        inx
        inx
        inx
        inx
        cpx #(5 * 4)
        bne -

-       lda initial_sprite_data, x  ; show palette editor sprites
        sta sprite_data, x
        inx
        inx
        inx
        inx
        cpx #(24 * 4)
        bne -

        inc mode  ; switch mode

        rts

; --------------------------------------------------------------------------------------------------

prepare_attr_change
        ; Prepare to cycle attribute value (0 -> 1 -> 2 -> 3 -> 0) of selected 2*2-tile block.
        ; Note: we've scrolled screen vertically so that VRAM $2000 is at top left of visible area.

        jsr get_vram_offset_for_at
        jsr get_vram_copy_addr
        jsr get_pos_in_attr_byte  ; 0/2/4/6 to X

        ; increment a bit pair in byte
        ldy #0
        lda (vram_copy_addr), y
        jsr increment_bit_pair      ; modify A according to X
        ldy #0
        sta (vram_copy_addr), y

        jsr nt_at_update_to_vram_buffer  ; tell NMI to copy A to VRAM
        rts

increment_bit_pair
        ; Increment one bit pair in a byte (00 -> 01 -> 10 -> 11 -> 00) without modifying other bits.
        ; (Used by prepare_attr_change.)
        ;   A: byte to modify
        ;   X: which bit pair to modify (0/2/4/6; 0 = least significant)
        ; The algorithm: if LSB is clear, only flip it, otherwise flip MSB too.

        pha
        and bitpair_increment_masks, x  ; if LSB set, increment LUT index to flip both bits
        beq +
        inx
+       pla
        eor bitpair_increment_masks, x
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
        bcs att_r
        lsr
        bcs att_l
        lsr
        bcs att_d
        lsr
        bcs att_u
        rts

att_r   lda cursor_x    ; right
        adc #(4 - 1)    ; carry is always set
        bcc att_sh      ; unconditional
att_l   lda cursor_x    ; left
        sbc #4          ; carry is always set
att_sh  and #%00111111  ; store horizontal
        sta cursor_x
        rts

att_d   lda cursor_y   ; down
        adc #(4 - 1)   ; carry is always set
        cmp #56
        bne att_sv
        lda #0
        beq att_sv     ; unconditional
att_u   lda cursor_y
        sbc #4         ; carry is always set
        bpl att_sv
        lda #(56 - 4)
att_sv  sta cursor_y   ; store vertical
        rts

