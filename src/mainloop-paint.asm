; Kalle Paint - main loop - paint mode

main_loop_paint_mode:
    ; ignore select, B and start if any of them was pressed on previous frame
    lda prev_joypad_status
    and #(button_select | button_b | button_start)
    bne paint_arrowlogic

    ; if select pressed, enter attribute editor (and ignore other buttons)
    lda joypad_status
    and #button_select
    beq +
    jmp enter_attribute_editor  ; ends with rts

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
    lsr cursor_x
    asl cursor_x
    lsr cursor_y
    asl cursor_y
+

paint_arrowlogic:
    ; if no arrow pressed, clear cursor movement delay
    lda joypad_status
    and #(button_up | button_down | button_left | button_right)
    bne +
    sta delay_left
    beq jump_to_part2  ; unconditional
    ;
    ; else if delay > 0, decrement it
+   lda delay_left
    beq +
    dec delay_left
    bpl jump_to_part2  ; unconditional
    ;
    ; else react to arrows and reinitialize delay
+   jsr paint_check_arrows
    lda #delay
    sta delay_left

jump_to_part2:
    jmp main_paint_part2  ; ends with rts

; --------------------------------------------------------------------------------------------------

enter_attribute_editor:
    ; Switch to attribute edit mode.

    ; hide paint cursor sprite (#0)
    lda #$ff
    sta sprite_data + 0 + 0

    ; show attribute editor sprites (#1-#4)
    lda #$ff
    ldx #(3 * 4)
-   lda initial_sprite_data + 4 + 0, x
    sta sprite_data + 4 + 0, x
    dex
    dex
    dex
    dex
    bpl -

    ; make cursor coordinates a multiple of four
    lda cursor_x
    and #$3c
    sta cursor_x
    lda cursor_y
    and #$3c
    sta cursor_y

    ; switch mode
    inc mode

    rts

; --------------------------------------------------------------------------------------------------

paint_check_arrows:
    ; React to arrows (including diagonal directions).
    ; Reads: joypad_status, cursor_x, cursor_y, paint_cursor_type
    ; Changes: cursor_x, cursor_y

    lda joypad_status
    lsr
    bcs paint_right
    lsr
    bcs paint_left
    bcc check_vertical  ; unconditional

paint_right:
    lda cursor_x
    sec
    adc paint_cursor_type
    bcc store_horizontal  ; unconditional
paint_left:
    lda cursor_x
    clc
    sbc paint_cursor_type
store_horizontal:
    and #%00111111
    sta cursor_x

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
    lda cursor_y
    sec
    adc paint_cursor_type
    cmp #56
    bne store_vertical
    lda #0
    beq store_vertical  ; unconditional
paint_cursor_up:
    lda cursor_y
    clc
    sbc paint_cursor_type
    bpl store_vertical
    lda #56
    clc
    sbc paint_cursor_type
store_vertical:
    sta cursor_y
    rts

; --------------------------------------------------------------------------------------------------

main_paint_part2:
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
    adc #(8 - 1)  ; carry is always clear
    sta sprite_data + 0 + 0
    ;
    ; tile
    lda paint_cursor_type
    ora #$10
    sta sprite_data + 0 + 1

    ; tell NMI to update paint color to cursor (6502 has sta abs,y but no lda zp,y)
    ;
    ldy vram_buffer_pos
    ;
    lda #$3f
    sta vram_buffer, y
    iny
    lda #$13
    sta vram_buffer, y
    iny
    ldx paint_color
    lda user_palette, x
    sta vram_buffer, y
    iny
    ;
    sty vram_buffer_pos

    rts

; --------------------------------------------------------------------------------------------------

prepare_paint:
    ; Prepare a paint operation to be done by NMI routine.
    ; Note: we've scrolled screen vertically so that VRAM $2000 is at top left of visible area.

    ; compute offset of byte to change
    ;   bits of cursor_y    : 00ABCDEF
    ;   bits of cursor_x    : 00abcdef
    ;   bits of nt_at_offset: 000000AB CDEabcde
    ;
    ; high byte
    lda cursor_y
    lsr
    lsr
    lsr
    lsr
    sta nt_at_offset + 1
    ;
    ; low byte
    lda cursor_y
    and #$0e
    asl
    asl
    asl
    asl
    sta bitop_temp
    lda cursor_x
    lsr
    ora bitop_temp
    sta nt_at_offset + 0

    ; address to change in nt_at_buffer (nt_at_buffer is at $xx00)
    lda nt_at_offset + 0
    sta nt_at_buffer_addr + 0
    clc
    lda #>nt_at_buffer
    adc nt_at_offset + 1
    sta nt_at_buffer_addr + 1

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
    lda (nt_at_buffer_addr), y
    pha
    ;
    ; position within tile (0-3) -> A, X
    lda cursor_x
    ror
    lda cursor_y
    rol
    and #$03
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
    ; overwrite and push new byte value
    ldy #0
    sta (nt_at_buffer_addr), y
    pha

    ; also tell NMI to update name table 0 at $2000 + nt_at_offset
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

