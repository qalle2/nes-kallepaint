; Kalle Paint - main loop - palette editor

palette_edit_mode
        ; ignore buttons if anything was pressed on previous frame
        lda prev_joypad_status
        beq +
        bne palette_edit_mode_part2  ; unconditional

+       lda joypad_status
        lsr
        bcs pal_i1         ; right
        lsr
        bcs pal_d1         ; left
        lsr
        bcs pal_d          ; down
        lsr
        bcs pal_u          ; up
        lsr
        bcs pal_cyc        ; start
        lsr
        bcs pal_mod        ; select; ends with rts
        lsr
        bcs pal_d16        ; B
        bne pal_i16        ; A

        beq palette_edit_mode_part2  ; unconditional

; --------------------------------------------------------------------------------------------------

pal_mod lda #$ff            ; switch to paint mode
        ldx #(5 * 4)        ; hide palette editor sprites
-       sta sprite_data, x
        inx
        inx
        inx
        inx
        cpx #(24 * 4)
        bne -
        lda #0              ; switch mode
        sta mode
        rts

; --------------------------------------------------------------------------------------------------

pal_cyc lda palette_subpal           ; cycle subpalette (0 -> 1 -> 2 -> 3 -> 0)
        adc #0                       ; carry is always set
        and #%00000011
        sta palette_subpal
        bpl palette_edit_mode_part2  ; unconditional

pal_d   ldx palette_cursor           ; move down
        inx
        bpl pal_sv                   ; unconditional
pal_u   ldx palette_cursor           ; move up
        dex
pal_sv  txa                          ; store vertical
        and #%00000011
        sta palette_cursor
        tax
        bpl palette_edit_mode_part2  ; unconditional

pal_i1  jsr get_user_pal_offset      ; increment ones; offset to A, X
        ldy user_palette, x
        iny
        bpl pal_s1                   ; unconditional
pal_d1  jsr get_user_pal_offset      ; decrement ones; offset to A, X
        ldy user_palette, x
        dey
pal_s1  tya                          ; store change of ones
        and #%00001111
        sta temp
        ;
        lda user_palette, x
        and #%00110000
        ora temp
        sta user_palette, x
        ;
        bpl palette_edit_mode_part2  ; unconditional

pal_i16 jsr get_user_pal_offset      ; increment sixteens; offset to A, X
        lda user_palette, x
        clc
        adc #$10
        bpl pal_s16                  ; unconditional
pal_d16 jsr get_user_pal_offset      ; decrement sixteens; offset to A, X
        lda user_palette, x
        sec
        sbc #$10
pal_s16 and #%00111111               ; store change of sixteens
        sta user_palette, x
        ;
        bpl palette_edit_mode_part2  ; unconditional

; -------------------------------------------------------------------------------------------------

palette_edit_mode_part2
        ; update tile of selected subpalette
        lda palette_subpal
        sta sprite_data + 7 * 4 + 1

        ; update cursor Y position
        lda palette_cursor
        asl
        asl
        asl
        adc #(14 * 8 - 1)  ; carry is always clear
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
        sta sprite_data + 9 * 4 + 1
        ;
        lda user_palette, x
        and #%00001111
        sta sprite_data + 10 * 4 + 1

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
        clc
        adc #5
        sta vram_buffer_pos

        rts

; -------------------------------------------------------------------------------------------------

get_user_pal_offset
        ; Get offset to user_palette or VRAM $3f00-$3f0f.
        ;     if palette_cursor = 0: 0
        ;     else:                  palette_subpal * 4 + palette_cursor
        ; Out: A, X

        lda palette_cursor
        beq +
        lda palette_subpal
        asl
        asl
        ora palette_cursor
+       tax
        rts

