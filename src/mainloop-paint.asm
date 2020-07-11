; Kalle Paint - main loop - paint mode

main_loop_paint_mode:
    ; ignore B, select, start if any of them was pressed on previous frame
    lda prev_joypad_status
    and #(button_b | button_select | button_start)
    bne paint_arrows_logic

    ; check B, select, start
    lda joypad_status
    cmp #button_b
    beq change_color          ; ends with rts
    cmp #button_select
    beq enter_palette_editor  ; ends with rts
    cmp #button_start
    beq change_cursor_type    ; ends with rts

paint_arrows_logic:
    ; if no arrow pressed, clear cursor movement delay
    lda joypad_status
    and #$0f
    bne +
    sta paint_move_delay_left
    jmp paint_arrows_done
    ; else if delay > 0, decrement it
+   lda paint_move_delay_left
    beq +
    dec paint_move_delay_left
    jmp paint_arrows_done
    ; else react to arrows and reinitialize delay
+   jsr check_arrows
    lda #cursor_move_delay
    sta paint_move_delay_left

paint_arrows_done:
    ; if A pressed, tell NMI routine to paint
    lda joypad_status
    and #button_a
    beq paint_buttons_done

    jsr get_paint_area_offset  ; paint_cursor_x, paint_cursor_y -> paint_area_offset

    ; nt_buffer + paint_area_offset -> nt_buffer_address
    clc
    lda #<nt_buffer
    adc paint_area_offset + 0
    sta nt_buffer_address + 0
    lda #>nt_buffer
    adc paint_area_offset + 1
    sta nt_buffer_address + 1

    jsr update_nt_buffer

    ; tell NMI to update VRAM
    sec
    ror update_paint_area_vram

paint_buttons_done:
    jmp update_paint_sprites  ; ends with rts

; --------------------------------------------------------------------------------------------------

change_color:
    ; cycle between 4 colors (0 -> 1 -> 2 -> 3 -> 0)
    ldx paint_color
    inx
    txa
    and #$03
    sta paint_color
    rts

; --------------------------------------------------------------------------------------------------

enter_palette_editor:
    ; init palette cursor position
    lda #0
    sta palette_cursor

    ; hide paint cursor
    lda #$ff
    sta sprite_data + 0 * 4 + 0

    ; show all palette editor sprites
    ldx #((palette_editor_sprite_count - 1) * 4)
-   lda initial_sprite_data + paint_mode_sprite_count * 4, x
    sta sprite_data + paint_mode_sprite_count * 4, x
    dex
    dex
    dex
    dex
    bpl -

    ; set flag
    sec
    ror in_palette_editor

    rts

; --------------------------------------------------------------------------------------------------

change_cursor_type:
    ; toggle between small and big cursor, update sprite tile
    lda paint_cursor_type
    eor #%00000001
    sta paint_cursor_type
    ora #$10
    sta sprite_data + 0 + 1

    ; if big, make coordinates even
    beq +
    lsr paint_cursor_x
    asl paint_cursor_x
    lsr paint_cursor_y
    asl paint_cursor_y

+   rts

; --------------------------------------------------------------------------------------------------

check_arrows:
    ; React to arrows (including diagonal directions).
    ; Reads: joypad_status, paint_cursor_x, paint_cursor_y, paint_cursor_type
    ; Changes: paint_cursor_x, paint_cursor_y

    lda joypad_status
    lsr
    bcs paint_right
    lsr
    bcs paint_left
    bcc check_vertical  ; unconditional

paint_right:
    lda paint_cursor_x
    sec
    adc paint_cursor_type
    bcc store_horizontal  ; unconditional
paint_left:
    lda paint_cursor_x
    clc
    sbc paint_cursor_type
store_horizontal:
    and #%00111111
    sta paint_cursor_x

check_vertical:
    lda joypad_status
    lsr
    lsr
    lsr
    bcs paint_cursor_down
    lsr
    bcs paint_cursor_up
    rts

paint_cursor_down:
    lda paint_cursor_y
    sec
    adc paint_cursor_type
    cmp #50
    bne store_vertical
    lda #0
    beq store_vertical  ; unconditional
paint_cursor_up:
    lda paint_cursor_y
    clc
    sbc paint_cursor_type
    bpl store_vertical
    lda #50
    clc
    sbc paint_cursor_type
store_vertical:
    sta paint_cursor_y
    rts

; --------------------------------------------------------------------------------------------------

get_paint_area_offset:
    ; Compute offset within name table data of paint area from paint_cursor_x and paint_cursor_y.
    ; Bits of paint_cursor_y    (0-49):  ABCDEF
    ; Bits of paint_cursor_x    (0-63):  abcdef
    ; Bits of paint_area_offset (0-799): 000000AB CDEabcde

    ; high byte
    lda paint_cursor_y  ; 00ABCDEF
    lsr
    lsr
    lsr
    lsr                 ; 000000AB
    sta paint_area_offset + 1

    ; low byte
    lda paint_cursor_y  ; 00ABCDEF
    and #$0e            ; 0000CDE0
    asl
    asl
    asl
    asl
    sta temp            ; CDE00000
    lda paint_cursor_x  ; 00abcdef
    lsr                 ; 000abcde
    ora temp            ; CDEabcde
    sta paint_area_offset + 0

    rts

; --------------------------------------------------------------------------------------------------

update_nt_buffer:
    ; Update a byte in nt_buffer.
    ; In: paint_cursor_type, paint_cursor_x, paint_cursor_y, paint_color, nt_buffer_address, nt_buffer
    ; Writes: nt_buffer

    ; get new byte

    lda paint_cursor_type
    beq +

    ; big cursor; just fetch correct solid color tile
    ldx paint_color
    lda solid_color_tiles, x
    jmp ++

    ; small cursor; replace two bits within old byte

    ; old byte -> stack
+   ldy #0
    lda (nt_buffer_address), y
    pha
    ; position within tile (0-3) -> A, X
    lda paint_cursor_x
    ror
    lda paint_cursor_y
    rol
    and #%00000011
    tax
    ; position_within_tile * 4 + paint_color -> Y
    asl
    asl
    ora paint_color
    tay
    ; pull old byte
    pla
    ; clear bits to replace
    and nt_and_masks, x
    ; write new bits
    ora nt_or_masks, y

    ; overwrite old byte
++  ldy #0
    sta (nt_buffer_address), y
    rts

solid_color_tiles:
    ; tile indexes of solid color 0/1/2/3
    hex 00 55 aa ff

nt_and_masks:
    db %00111111, %11001111, %11110011, %11111100

nt_or_masks:
    db %00000000, %01000000, %10000000, %11000000
    db %00000000, %00010000, %00100000, %00110000
    db %00000000, %00000100, %00001000, %00001100
    db %00000000, %00000001, %00000010, %00000011

; --------------------------------------------------------------------------------------------------

update_paint_sprites:
    ; Update sprite data regarding cursor position.

    ; X of cursor sprite
    lda paint_cursor_x
    asl
    asl
    sta sprite_data + 0 + 3

    ; Y of cursor sprite
    lda paint_cursor_y
    asl
    asl
    clc
    adc #(4 * 8 - 1)
    sta sprite_data + 0 + 0

    ; tiles of cursor X coordinate sprites
    lda paint_cursor_x
    pha
    jsr to_decimal_tens_tile
    sta sprite_data + 4 + 1
    pla
    jsr to_decimal_ones_tile
    sta sprite_data + 2 * 4 + 1

    ; tiles of cursor Y coordinate sprites
    lda paint_cursor_y
    pha
    jsr to_decimal_tens_tile
    sta sprite_data + 3 * 4 + 1
    pla
    jsr to_decimal_ones_tile
    sta sprite_data + 4 * 4 + 1

    rts

; --------------------------------------------------------------------------------------------------

to_decimal_tens_tile:
    ; In: A = unsigned integer
    ; Out: A = decimal tens

    ldx #$ff
    sec
-   inx
    sbc #10
    bcs -

    txa
    rts

to_decimal_ones_tile:
    ; In: A = unsigned integer
    ; Out: A = decimal ones

    sec
-   sbc #10
    bcs -
    adc #10

    rts

