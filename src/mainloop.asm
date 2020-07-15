main:
    ; wait until NMI has set flag
    bit run_main_loop
    bpl main

    ; remember previous joypad status
    lda joypad_status
    sta prev_joypad_status

    ; read joypad (bits: A, B, select, start, up, down, left, right)
    ldx #$01
    stx joypad_status  ; to detect end of loop
    stx joypad1
    dex
    stx joypad1
-   clc
    lda joypad1
    and #$03
    beq +
    sec
+   rol joypad_status
    bcc -

    ; run one of two subs depending on the mode we're in
    bit in_palette_editor
    bmi +
    jsr main_paint
    jmp ++
+   jsr main_editor

    ; prevent ourselves from running again before next NMI
++  lsr run_main_loop
    jmp main

; --------------------------------------------------------------------------------------------------
; --- Paint mode -----------------------------------------------------------------------------------
; --------------------------------------------------------------------------------------------------

main_paint:
    ; ignore select, B and start if any of them was pressed on previous frame
    lda prev_joypad_status
    and #(button_select | button_b | button_start)
    bne paint_arrowlogic

    ; if select pressed, enter palette editor (and ignore other buttons)
    lda joypad_status
    and #button_select
    beq +
    jmp enter_editor  ; ends with rts

    ; if B pressed, cycle between 4 colors (0 -> 1 -> 2 -> 3 -> 0)
+   lda joypad_status
    and #button_b
    beq +
    ldx paint_color
    inx
    txa
    and #$03
    sta paint_color

    ; if start pressed, toggle between small and big cursor; if big, make coordinates even
+   lda joypad_status
    and #button_start
    beq +
    lda paint_cursor_type
    eor #$01
    sta paint_cursor_type
    beq +
    lsr paint_cursor_x
    asl paint_cursor_x
    lsr paint_cursor_y
    asl paint_cursor_y
+

paint_arrowlogic:
    ; if no arrow pressed, clear cursor movement delay
    lda joypad_status
    and #$0f
    bne +
    sta paint_move_delay_left
    beq jump_to_part2          ; unconditional
    ; else if delay > 0, decrement it
+   lda paint_move_delay_left
    beq +
    dec paint_move_delay_left
    bpl jump_to_part2          ; unconditional
    ; else react to arrows and reinitialize delay
+   jsr check_arrows
    lda #cursor_move_delay
    sta paint_move_delay_left

jump_to_part2:
    jmp main_paint_part2  ; ends with rts

; --------------------------------------------------------------------------------------------------

enter_editor:
    ; init palette cursor position
    lda #0
    sta palette_cursor

    ; update cursor sprite (X, tile)
    lda #(15 * 8)
    sta sprite_data + 0 + 3
    lda #$11
    sta sprite_data + 0 + 1

    ; show sprites except the first one (already visible)
    ldx #(initial_sprite_data_end - initial_sprite_data - 2 * 4)
-   lda initial_sprite_data + 4 + 0, x
    sta sprite_data + 4 + 0, x
    dex
    dex
    dex
    dex
    bpl -

    ; update tiles of cursor X position
    lda paint_cursor_x
    pha
    jsr to_decimal_tens
    sta sprite_data + 2 * 4 + 1
    pla
    jsr to_decimal_ones
    sta sprite_data + 3 * 4 + 1

    ; update tiles of cursor Y position
    lda paint_cursor_y
    pha
    jsr to_decimal_tens
    sta sprite_data + 5 * 4 + 1
    pla
    jsr to_decimal_ones
    sta sprite_data + 6 * 4 + 1

    ; set flag
    sec
    ror in_palette_editor
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
    cmp #56
    bne store_vertical
    lda #0
    beq store_vertical  ; unconditional
paint_cursor_up:
    lda paint_cursor_y
    clc
    sbc paint_cursor_type
    bpl store_vertical
    lda #56
    clc
    sbc paint_cursor_type
store_vertical:
    sta paint_cursor_y
    rts

; --------------------------------------------------------------------------------------------------

main_paint_part2:
    ; if A pressed, tell NMI routine to paint
    lda joypad_status
    and #button_a
    beq +
    jsr prepare_paint
    sec
    ror update_paint_area_vram
+

    ; update cursor sprite
    ;
    ; X
    lda paint_cursor_x
    asl
    asl
    sta sprite_data + 0 + 3
    ;
    ; Y
    lda paint_cursor_y
    asl
    asl
    adc #(8 - 1)  ; carry is always clear
    sta sprite_data + 0 + 0
    ;
    ; tile
    lda paint_cursor_type
    ora #$10
    sta sprite_data + 0 + 1

    rts

; --------------------------------------------------------------------------------------------------

prepare_paint:
    ; Prepare a paint operation to be done by NMI routine.

    ; compute offset of byte to change
    ;   bits of paint_cursor_y   : 00ABCDEF
    ;   bits of paint_cursor_x   : 00abcdef
    ;   bits of paint_area_offset: 000000AB CDEabcde
    ;
    ; high byte
    lda paint_cursor_y
    lsr
    lsr
    lsr
    lsr
    sta paint_area_offset + 1
    ;
    ; low byte
    lda paint_cursor_y
    and #$0e
    asl
    asl
    asl
    asl
    sta temp
    lda paint_cursor_x
    lsr
    ora temp
    sta paint_area_offset + 0

    ; compute address to change in nt_buffer (the offset we just computed)
    clc
    lda #<nt_buffer
    adc paint_area_offset + 0
    sta nt_buffer_address + 0
    lda #>nt_buffer
    adc paint_area_offset + 1
    sta nt_buffer_address + 1

    ; get byte to write

    lda paint_cursor_type
    beq +

    ; cursor is big; just fetch correct solid color tile
    ldx paint_color
    lda solid_color_tiles, x
    jmp overwrite_byte

    ; cursor is small; read old byte and replace two bits
    ;
    ; push old byte
+   ldy #0
    lda (nt_buffer_address), y
    pha
    ;
    ; position within tile (0-3) -> A, X
    lda paint_cursor_x
    ror
    lda paint_cursor_y
    rol
    and #%00000011
    tax
    ;
    ; (position within tile) * 4 + paint_color -> Y
    asl
    asl
    ora paint_color
    tay
    ;
    ; pull old byte
    pla
    ;
    ; clear bits to replace
    and nt_and_masks, x
    ;
    ; write new bits
    ora nt_or_masks, y

overwrite_byte:
    ldy #0
    sta (nt_buffer_address), y
    rts

solid_color_tiles:
    ; tiles of solid color 0/1/2/3
    hex 00 55 aa ff

nt_and_masks:
    hex 3f cf f3 fc

nt_or_masks:
    hex 00 40 80 c0
    hex 00 10 20 30
    hex 00 04 08 0c
    hex 00 01 02 03

; --------------------------------------------------------------------------------------------------
; --- Palette editor -------------------------------------------------------------------------------
; --------------------------------------------------------------------------------------------------

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

    ; advance timer
    inc cursor_blink_timer
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

