; Kalle Paint - main loop - paint mode

paint_mode
        ; ignore select, B and start if any of them was pressed on previous frame
        lda prev_joypad_status
        and #(button_select | button_b | button_start)
        bne paint_arrowlogic

        ; if select pressed, enter attribute editor (and ignore other buttons)
        lda joypad_status
        and #button_select
        beq +
        bne enter_attribute_editor  ; unconditional; ends with rts

        ; if B pressed, cycle between 4 colors (0 -> 1 -> 2 -> 3 -> 0)
+       lda joypad_status
        and #button_b
        beq +
        ldx paint_color
        inx
        txa
        and #%00000011
        sta paint_color

        ; if start pressed, toggle between small and big cursor; if big, make coordinates even
+       lda joypad_status
        and #button_start
        beq +
        lda paint_cursor_type
        eor #%00000001
        sta paint_cursor_type
        beq +
        lsr cursor_x
        asl cursor_x
        lsr cursor_y
        asl cursor_y
+

paint_arrowlogic
        ; if no arrow pressed, clear cursor movement delay
        lda joypad_status
        and #(button_up | button_down | button_left | button_right)
        bne +
        sta delay_left
        beq paint_mode_part2  ; unconditional; ends with rts
        ;
        ; else if delay > 0, decrement it
+       lda delay_left
        beq +
        dec delay_left
        bpl paint_mode_part2  ; unconditional; ends with rts
        ;
        ; else react to arrows and reinitialize delay
+       jsr paint_check_arrows
        lda #delay
        sta delay_left
        bne paint_mode_part2  ; unconditional; ends with rts

; --------------------------------------------------------------------------------------------------

enter_attribute_editor
        ; Switch to attribute edit mode.

        ; hide paint cursor sprite
        lda #$ff
        sta sprite_data + 0 + 0

        ; make cursor coordinates a multiple of four
        lda cursor_x
        and #%00111100
        sta cursor_x
        lda cursor_y
        and #%00111100
        sta cursor_y

        ; switch mode
        inc mode

        rts

; --------------------------------------------------------------------------------------------------

paint_check_arrows
        ; React to arrows (including diagonal directions).
        ; Changes: cursor_x, cursor_y

        ; check horizontal
        lda joypad_status
        lsr
        bcs paint_right
        lsr
        bcs paint_left
        bcc paint_check_vert   ; unconditional
paint_right
        lda cursor_x
        sec
        adc paint_cursor_type
        bpl paint_store_horz   ; unconditional
paint_left
        lda cursor_x
        clc
        sbc paint_cursor_type
paint_store_horz               ; store horizontal
        and #%00111111
        sta cursor_x

paint_check_vert               ; check vertical
        lda joypad_status
        lsr
        lsr
        lsr
        bcs paint_down
        lsr
        bcs paint_up
        rts
paint_down
        lda cursor_y
        sec
        adc paint_cursor_type
        cmp #56
        bne paint_store_vert
        lda #0
        beq paint_store_vert   ; unconditional
paint_up
        lda cursor_y
        clc
        sbc paint_cursor_type
        bpl paint_store_vert
        lda #56
        clc
        sbc paint_cursor_type
paint_store_vert               ; store vertical
        sta cursor_y
        rts

; --------------------------------------------------------------------------------------------------

paint_mode_part2
        ; if A pressed, tell NMI routine to paint
        lda joypad_status
        and #button_a
        beq +
        jsr prepare_paint
+

        ; update cursor sprite
        ;
        ; X
        lda cursor_x
        asl
        asl
        sta sprite_data + 0 + 3
        ;
        ; Y
        lda cursor_y
        asl
        asl
        adc #(8 - 1)             ; carry is always clear
        sta sprite_data + 0 + 0
        ;
        ; tile
        lda #tile_smallcur
        ldx paint_cursor_type
        beq +
        lda #tile_largecur
+       sta sprite_data + 0 + 1

        jsr get_cursor_color  ; to A
        pha

        ; tell NMI to update paint color to cursor
        ;
        inc vram_buffer_pos
        ldx vram_buffer_pos
        ;
        lda #$3f
        sta vram_buffer_addrhi, x
        lda #$13
        sta vram_buffer_addrlo, x
        pla
        sta vram_buffer_value, x

        rts

; --------------------------------------------------------------------------------------------------

prepare_paint
        ; Prepare a paint operation to be done by NMI routine. (Used by paint_mode_part2.)
        ; Note: we've scrolled screen vertically so that VRAM $2000 is at top left of visible area.

        ; compute vram_offset for a name table byte; bits:
        ; cursor_y = 00ABCDEF, cursor_x = 00abcdef -> vram_offset = 000000AB CDEabcde
        ;
        lda cursor_y         ; 00ABCDEF
        lsr
        lsr
        lsr
        lsr                  ; 000000AB
        sta vram_offset + 1
        ;
        lda cursor_y         ; 00ABCDEF
        and #%00001110       ; 0000CDE0
        asl
        asl
        asl
        asl                  ; CDE00000
        sta temp
        lda cursor_x         ; 00abcdef
        lsr                  ; 000abcde
        ora temp             ; CDEabcde
        sta vram_offset + 0

        jsr get_vram_copy_addr

        ; get byte to write:
        ; - if cursor is small, replace a bit pair (pixel) in old byte (tile)
        ; - if cursor is big, just replace entire byte (four pixels)
        lda paint_cursor_type
        beq +
        ldx paint_color
        lda solids, x
        jmp overwrite_byte

solids  db %00000000, %01010101, %10101010, %11111111

        ; read old byte and replace a bit pair
        ;
+       ldy #0
        lda (vram_copy_addr), y
        pha
        ;
        ; position within tile (0/2/4/6) -> X
        lda cursor_x
        lsr             ; LSB to carry
        lda cursor_y
        rol
        and #%00000011
        eor #%00000011
        asl
        tax
        ;
        ; shifted AND mask for clearing bit pair -> temp
        ; shifted paint_color for setting bit pair -> A
        lda #%11111100
        sta temp
        lda paint_color
        cpx #0
        beq +
-       sec
        rol temp
        asl
        dex
        bne -
        ;
        ; pull byte to modify, clear bit pair, insert new bit pair
+       tay
        pla
        and temp
        sty temp
        ora temp

        ; overwrite byte and tell NMI to copy A to VRAM
overwrite_byte
        ldy #0
        sta (vram_copy_addr), y
        jsr nt_at_update_to_vram_buffer
        rts

; --------------------------------------------------------------------------------------------------

get_cursor_color
        ; Get correct color for cursor. (Used by paint_mode_part2.)
        ; In: cursor_x, cursor_y, vram_buffer, user_palette
        ; Out: A

        ; if color 0 of any subpal, no need to read vram_copy
        ldx paint_color
        beq ++

        jsr get_vram_offset_for_at
        jsr get_vram_copy_addr
        jsr get_pos_in_attr_byte  ; 0/2/4/6 to X

        ; read attribute byte, shift relevant bits to positions 1-0, clear other bits
        ldy #0
        lda (vram_copy_addr), y
        cpx #0
        beq +
-       lsr
        dex
        bne -
+       and #%00000011

        ; get user_palette index
        asl
        asl
        ora paint_color
        tax

++      lda user_palette, x
        rts
