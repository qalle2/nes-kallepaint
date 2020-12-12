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

        lda #$ff                 ; hide paint cursor sprite
        sta sprite_data + 0 + 0

        lda cursor_x    ; make cursor coordinates a multiple of four
        and #%00111100
        sta cursor_x
        lda cursor_y
        and #%00111100
        sta cursor_y

        inc mode  ; switch mode

        rts

; --------------------------------------------------------------------------------------------------

paint_check_arrows
        ; React to arrows (including diagonal directions).
        ; Changes: cursor_x, cursor_y

        lda joypad_status      ; check horizontal
        lsr
        bcs pnt_r
        lsr
        bcs pnt_l
        bcc pnt_cv             ; unconditional
pnt_r   lda cursor_x           ; right
        sec
        adc paint_cursor_type
        bpl pnt_sh             ; unconditional
pnt_l   lda cursor_x           ; left
        clc
        sbc paint_cursor_type
pnt_sh  and #%00111111         ; store horizontal
        sta cursor_x

pnt_cv  lda joypad_status      ; check vertical
        lsr
        lsr
        lsr
        bcs pnt_d
        lsr
        bcs pnt_u
        rts
pnt_d   lda cursor_y           ; down
        sec
        adc paint_cursor_type
        cmp #56
        bne pnt_sv
        lda #0
        beq pnt_sv             ; unconditional
pnt_u   lda cursor_y           ; up
        clc
        sbc paint_cursor_type
        bpl pnt_sv
        lda #56
        clc
        sbc paint_cursor_type
pnt_sv  sta cursor_y           ; store vertical
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
        lda cursor_y
        lsr
        lsr
        lsr
        lsr
        sta vram_offset + 1
        ;
        lda cursor_y
        and #%00001110
        asl
        asl
        asl
        asl
        sta temp
        lda cursor_x
        lsr
        ora temp
        sta vram_offset + 0

        jsr get_vram_copy_addr

        ; get byte to write

        lda paint_cursor_type
        beq +

        ; cursor is big; just fetch correct solid color tile
        ldx paint_color
        lda solids, x
        jmp ++

        ; cursor is small; read old byte and replace a bit pair
+       ldy #0
        lda (vram_copy_addr), y
        jsr replace_bit_pair

        ; overwrite byte
++      ldy #0
        sta (vram_copy_addr), y
        jsr nt_at_update_to_vram_buffer  ; tell NMI to copy A to VRAM
        rts

        ; tiles of solid color 0/1/2/3 (2 bits = 1 pixel)
solids  db %00000000, %01010101, %10101010, %11111111

replace_bit_pair
        ; Replace a bit pair in a byte without modifying other bits. (Used by prepare_paint.)
        ;   A: byte to modify
        ;   cursor_x, cursor_y: which bit pair to modify
        ;   paint_color: value of new bit pair

        pha

        ; position within tile (0-3) -> A, X
        lda cursor_x
        lsr
        lda cursor_y
        rol
        and #%00000011
        tax

        ; (position within tile) * 4 + paint_color -> Y
        asl
        asl
        ora paint_color
        tay

        ; pull old byte, clear bits to replace, write new bits
        pla
        and bitpair_clear_masks, x
        ora bitpair_set_masks, y

        rts

bitpair_clear_masks
        ; clear one bit pair
        db %00111111, %11001111, %11110011, %11111100

bitpair_set_masks
        ; set one bit pair
        db %00000000, %01000000, %10000000, %11000000
        db %00000000, %00010000, %00100000, %00110000
        db %00000000, %00000100, %00001000, %00001100
        db %00000000, %00000001, %00000010, %00000011

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

