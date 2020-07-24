; Kalle Paint - main loop - attribute edit mode

main_loop_attribute_editor:
    ; ignore buttons if anything was pressed on previous frame
    lda prev_joypad_status
    bne attr_buttons_done

    ; if select pressed, enter palette editor
    lda joypad_status
    and #button_select
    beq +
    jmp enter_palette_editor  ; ends with rts

    ; otherwise if A pressed, tell NMI to update attribute byte
+   lda joypad_status
    and #button_a
    beq +
    jsr prepare_attr_change
    jmp attr_buttons_done

    ; otherwise, check arrows
+   jsr attr_check_arrows

attr_buttons_done:
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

enter_palette_editor:
    ; Switch to palette edit mode.

    ; reset palette cursor position and selected subpalette
    lda #0
    sta palette_cursor
    sta palette_subpal

    ; hide paint and attribute editor sprites (#0-#4)
    lda #$ff
    ldx #(4 * 4)
-   sta sprite_data + 0 + 0, x
    dex
    dex
    dex
    dex
    bpl -

    ; show palette editor sprites (#5-)
    ldx #(initial_sprite_data_end - initial_sprite_data - 6 * 4)
-   lda initial_sprite_data + 5 * 4 + 0, x
    sta sprite_data + 5 * 4 + 0, x
    dex
    dex
    dex
    dex
    bpl -

    ; update tiles of cursor X position
    lda cursor_x
    pha
    jsr to_decimal_tens
    sta sprite_data + 7 * 4 + 1
    pla
    jsr to_decimal_ones
    sta sprite_data + 8 * 4 + 1

    ; update tiles of cursor Y position
    lda cursor_y
    pha
    jsr to_decimal_tens
    sta sprite_data + 10 * 4 + 1
    pla
    jsr to_decimal_ones
    sta sprite_data + 11 * 4 + 1

    inc mode
    rts

to_decimal_tens:
    ; A: unsigned integer -> decimal tens
    ldx #$ff
    sec
-   inx
    sbc #10
    bcs -
    txa
    rts

to_decimal_ones:
    ; A: unsigned integer -> decimal ones
    sec
-   sbc #10
    bcs -
    adc #10
    rts

; --------------------------------------------------------------------------------------------------

prepare_attr_change:
    ; Prepare to cycle attribute value (0 -> 1 -> 2 -> 3 -> 0) of selected 2*2-tile block.
    ; Note: we've scrolled screen vertically so that VRAM $2000 is at top left of visible area.

    ; get nt_at_offset and nt_at_buffer_addr
    jsr compute_attr_offset_and_addr

    ; get byte to write (read old byte and replace two bits)
    ;
    ; position within attribute byte -> X
    jsr get_pos_in_attr_byte  ; 0-3 to A
    tax
    ;
    ; read old byte, increment correct bits, clear other bits, store
    ldy #0
    lda (nt_at_buffer_addr), y
    clc
    adc attr_byte_increment, x
    and attr_byte_masks, x
    sta bitop_temp
    ;
    ; read old byte again, clear bits to change, get them from temp var
    lda (nt_at_buffer_addr), y
    and attr_byte_inverse_masks, x
    ora bitop_temp
    ;
    ; write new byte and push it
    sta (nt_at_buffer_addr), y
    pha

    ; also tell NMI to update attribute table 0 at $2000 + nt_at_offset
    ;
    ldx vram_buffer_pos
    ;
    lda nt_at_offset + 1
    ora #$20
    sta vram_buffer, x
    inx
    lda nt_at_offset + 0
    sta vram_buffer, x
    inx
    pla
    sta vram_buffer, x
    inx
    ;
    stx vram_buffer_pos

    rts

compute_attr_offset_and_addr:
    ; Compute nt_at_offset and nt_at_buffer_addr in context of an *attribute* byte.
    ; (This sub is also used in paint mode.)

    ; bits of cursor_y    : 00ABCDEF
    ; bits of cursor_x    : 00abcdef
    ; bits of nt_at_offset: $3c0 + 00ABCabc = 00000011 11ABCabc
    ;
    ; low byte
    lda cursor_x
    lsr
    lsr
    lsr
    sta bitop_temp
    lda cursor_y
    and #$38
    ora #$c0
    ora bitop_temp
    sta nt_at_offset + 0
    ;
    ; high byte
    lda #$03
    sta nt_at_offset + 1

    ; nt_at_buffer_addr (nt_at_buffer must start at $xx00)
    lda nt_at_offset + 0
    sta nt_at_buffer_addr + 0
    clc
    lda #>nt_at_buffer
    adc nt_at_offset + 1
    sta nt_at_buffer_addr + 1

    rts

get_pos_in_attr_byte:
    ; Get position within attribute byte.
    ; 0 = top left, 1 = top right, 2 = bottom left, 3 = bottom right.
    ; Bits:
    ;   cursor_y: 00ABCDEF
    ;   cursor_x: 00abcdef
    ;   A       : 000000Dd

    lda cursor_y
    and #%00000100
    sta bitop_temp
    lda cursor_x
    and #%00000100
    lsr
    ora bitop_temp
    lsr
    rts

attr_byte_increment:
    db %00000001, %00000100, %00010000, %01000000

attr_byte_masks:
    db %00000011, %00001100, %00110000, %11000000

attr_byte_inverse_masks:
    db %11111100, %11110011, %11001111, %00111111

; --------------------------------------------------------------------------------------------------

attr_check_arrows:
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

attr_right:
    lda cursor_x
    clc
    adc #4
    bcc attr_store_horz  ; unconditional
attr_left:
    lda cursor_x
    sec
    sbc #4
attr_store_horz:
    and #$3f
    sta cursor_x
    rts

attr_down:
    lda cursor_y
    clc
    adc #4
    cmp #56
    bne attr_store_vert
    lda #0
    beq attr_store_vert  ; unconditional
attr_up:
    lda cursor_y
    src
    sbc #4
    bpl attr_store_vert
    lda #(56 - 4)
attr_store_vert:
    sta cursor_y
    rts

