; Kalle Paint - main loop - palette editor

palette_edit_mode
        ; ignore buttons if anything was pressed on previous frame
        lda prev_joypad_status
        beq +
        bne palette_edit_mode_part2  ; unconditional

+       lda joypad_status
        lsr
        bcs pal_ed_inc1    ; right
        lsr
        bcs pal_ed_dec1    ; left
        lsr
        bcs pal_ed_down    ; down
        lsr
        bcs pal_ed_up      ; up
        lsr
        bcs pal_ed_cycle   ; start
        lsr
        bcs to_paint_mode  ; select; ends with rts
        lsr
        bcs pal_ed_dec16   ; B
        bne pal_ed_inc16   ; A

        beq palette_edit_mode_part2  ; unconditional

; --------------------------------------------------------------------------------------------------

to_paint_mode
        ; switch to paint mode

        ; hide palette editor sprites (#5-#23)
        lda #$ff
        ldx #(5 * 4)
-       sta sprite_data, x
        inx
        inx
        inx
        inx
        cpx #(24 * 4)
        bne -

        ; switch mode
        lda #0
        sta mode

        rts

; --------------------------------------------------------------------------------------------------

pal_ed_cycle                         ; cycle subpalette (0 -> 1 -> 2 -> 3 -> 0)
        lda palette_subpal
        adc #0                       ; carry is always set
        and #%00000011
        sta palette_subpal
        bpl palette_edit_mode_part2  ; unconditional

pal_ed_down                          ; move down
        ldx palette_cursor
        inx
        bpl pal_ed_sto_vert          ; unconditional
pal_ed_up                            ; move up
        ldx palette_cursor
        dex
pal_ed_sto_vert                      ; store vertical
        txa
        and #%00000011
        sta palette_cursor
        tax
        bpl palette_edit_mode_part2  ; unconditional

pal_ed_inc1                          ; increment ones
        jsr get_user_pal_offset      ; to A, X
        ldy user_palette, x
        iny
        bpl pal_ed_store1            ; unconditional
pal_ed_dec1                          ; decrement ones
        jsr get_user_pal_offset      ; to A, X
        ldy user_palette, x
        dey
pal_ed_store1                        ; store ones
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

pal_ed_inc16                         ; increment sixteens
        jsr get_user_pal_offset      ; to A, X
        lda user_palette, x
        clc
        adc #$10
        bpl pal_ed_store16           ; unconditional
pal_ed_dec16                         ; decrement sixteens
        jsr get_user_pal_offset      ; to A, X
        lda user_palette, x
        sec
        sbc #$10
pal_ed_store16                       ; store sixteens
        and #%00111111
        sta user_palette, x
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
        adc #(24 * 8 - 1)  ; carry is always clear
        sta sprite_data + 5 * 4 + 0

        ; update tiles of color number 16s and ones
        ;
        jsr get_user_pal_offset  ; to A, X
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
        jsr get_user_pal_offset  ; to A, X
        pha
        ;
        ldx vram_buffer_pos
        ;
        ; selected color in selected subpal -> background palette
        lda #$3f
        sta vram_buffer_addrhi + 1, x
        pla
        sta vram_buffer_addrlo + 1, x
        tay
        lda user_palette, y
        sta vram_buffer_value + 1, x
        ;
        ; 1st color of all subpalettes
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
        lda #$3f
        sta vram_buffer_addrhi + 3, x
        lda #$16
        sta vram_buffer_addrlo + 3, x
        lda user_palette + 1, y
        sta vram_buffer_value + 3, x
        ;
        ; 3rd color of selected subpalette
        lda #$3f
        sta vram_buffer_addrhi + 4, x
        lda #$1a
        sta vram_buffer_addrlo + 4, x
        lda user_palette + 2, y
        sta vram_buffer_value + 4, x
        ;
        ; 4th color of selected subpalette
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
