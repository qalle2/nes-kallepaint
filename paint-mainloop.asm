main_loop:
    ; wait until NMI has set flag
    bit execute_main_loop
    bpl main_loop

    ; joypad: remember previous status, get new
    lda joypad_status
    sta prev_joypad_status
    jsr read_joypad

    ; run one of two subs depending on the mode we're in
    bit in_palette_editor
    bmi +                  ; branch if flag set
    jsr main_loop_paint_mode
    jmp ++
+   jsr main_loop_palette_edit_mode

    ; clear flag (to run main loop only once per frame)
++  lsr execute_main_loop
    jmp main_loop

; --------------------------------------------------------------------------------------------------

read_joypad:
    ; Read joypad status, save to joypad_status.
    ; Bits: A, B, select, start, up, down, left, right.

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

    rts

; --------------------------------------------------------------------------------------------------

main_loop_paint_mode:
    ; ignore B, select, start if any of them was pressed on previous frame
    lda prev_joypad_status
    and #(button_b | button_select | button_start)
    bne paint_arrow_logic

    ; check B, select, start
    lda joypad_status
    cmp #button_b
    beq change_color          ; ends with rts
    cmp #button_select
    beq enter_palette_editor  ; ends with rts
    cmp #button_start
    beq change_cursor_type    ; ends with rts

paint_arrow_logic:
    ; if no arrow pressed, clear cursor movement delay
    lda joypad_status
    and #$0f
    bne +
    sta paint_move_delay_left
    jmp paint_arrow_logic_done
    ; else if delay > 0, decrement it
+   lda paint_move_delay_left
    beq +
    dec paint_move_delay_left
    jmp paint_arrow_logic_done
    ; else react to arrows and reinitialize delay
+   jsr check_horizontal_arrows
    jsr check_vertical_arrows
    lda #cursor_move_delay
    sta paint_move_delay_left

paint_arrow_logic_done:
    ; make sprite data reflect changes to cursor
    jsr update_paint_mode_sprite_data

    ; if A pressed, tell NMI routine to paint
    lda joypad_status
    and #button_a
    beq +

    jsr get_paint_area_offset    ; paint_cursor_x, paint_cursor_y -> paint_area_offset
    jsr compute_paint_addresses  ; paint_area_offset -> nt_buffer_address, paint_vram_address
    jsr update_nt_buffer         ; update nt_buffer

    ; set flag to tell NMI to update VRAM
    sec
    ror update_paint_area_vram

+   rts

; --------------------------------------------------------------------------------------------------

change_color:
    ; cycle between 4 colors
    ldx paint_color
    inx
    txa
    and #%00000011
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
    ora #2
    sta sprite_data + 0 + 1

    ; if big, make coordinates even
    beq +
    lsr paint_cursor_x
    asl paint_cursor_x
    lsr paint_cursor_y
    asl paint_cursor_y

+   rts

; --------------------------------------------------------------------------------------------------

check_horizontal_arrows:
    ; React to left/right arrow.
    ; Reads: joypad_status, paint_cursor_x, paint_cursor_type
    ; Changes: paint_cursor_x

    lda joypad_status
    lsr
    bcs paint_right
    lsr
    bcs paint_left
    rts

paint_right:
    lda paint_cursor_x
    sec
    adc paint_cursor_type
    jmp store_horizontal
paint_left:
    lda paint_cursor_x
    clc
    sbc paint_cursor_type
store_horizontal:
    and #%00111111
    sta paint_cursor_x
    rts

; --------------------------------------------------------------------------------------------------

check_vertical_arrows:
    ; React to up/down arrow.
    ; Reads: joypad_status, paint_cursor_y, paint_cursor_type
    ; Changes: paint_cursor_y

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
    jmp store_vertical
paint_cursor_up:
    lda paint_cursor_y
    clc
    sbc paint_cursor_type
    bpl store_vertical
    lda #50
    clc
    sbc paint_cursor_type
store_vertical:
    and #%00111111
    sta paint_cursor_y
    rts

; --------------------------------------------------------------------------------------------------

update_paint_mode_sprite_data:
    ; Update sprite data regarding cursor position.
    ; Reads: paint_cursor_x, paint_cursor_y
    ; Writes: sprite_data

    ; cursor sprite X position
    lda paint_cursor_x
    asl
    asl
    sta sprite_data + 0 + 3

    ; cursor sprite Y position
    lda paint_cursor_y
    asl
    asl
    clc
    adc #(4 * 8 - 1)
    sta sprite_data + 0 + 0

    ; tiles of X position sprites
    lda paint_cursor_x
    pha
    jsr to_decimal_tens_tile
    sta sprite_data + 4 + 1
    pla
    jsr to_decimal_ones_tile
    sta sprite_data + 2 * 4 + 1

    ; tiles of Y position sprites
    lda paint_cursor_y
    pha
    jsr to_decimal_tens_tile
    sta sprite_data + 3 * 4 + 1
    pla
    jsr to_decimal_ones_tile
    sta sprite_data + 4 * 4 + 1

    rts

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

compute_paint_addresses:
    ; Reads: paint_area_offset
    ; Writes: nt_buffer_address, paint_vram_address

    ; nt_buffer + paint_area_offset -> nt_buffer_address
    clc
    lda #<nt_buffer
    adc paint_area_offset + 0
    sta nt_buffer_address + 0
    lda #>nt_buffer
    adc paint_area_offset + 1
    sta nt_buffer_address + 1

    ; ppu_paint_area_start + paint_area_offset -> paint_vram_address
    clc
    lda #<ppu_paint_area_start
    adc paint_area_offset + 0
    sta paint_vram_address + 0
    lda #>ppu_paint_area_start
    adc paint_area_offset + 1
    sta paint_vram_address + 1

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

nt_and_masks:
    db %00111111, %11001111, %11110011, %11111100

nt_or_masks:
    db %00000000, %01000000, %10000000, %11000000
    db %00000000, %00010000, %00100000, %00110000
    db %00000000, %00000100, %00001000, %00001100
    db %00000000, %00000001, %00000010, %00000011

; --------------------------------------------------------------------------------------------------

to_decimal_tens_tile:
    ; In: A = unsigned integer
    ; Out: A = tile number for decimal tens

    ldx #$ff
    sec
-   inx
    sbc #10
    bcs -

    txa
    adc #$0a  ; tile number for "0"
    rts

to_decimal_ones_tile:
    ; In: A = unsigned integer
    ; Out: A = tile number for decimal ones

    sec
-   sbc #10
    bcs -
    adc #10

    clc
    adc #$0a  ; tile number for "0"
    rts

; --------------------------------------------------------------------------------------------------

main_loop_palette_edit_mode:
    ; get color at cursor
    ldx palette_cursor
    ldy user_palette, x

    ; ignore all buttons if anything was pressed on previous frame
    lda prev_joypad_status
    bne update_palette_editor_sprite_data  ; ends with rts

    lda joypad_status
    lsr
    bcs small_color_increment  ; right
    lsr
    bcs small_color_decrement  ; left
    lsr
    bcs palette_cursor_down    ; down
    lsr
    bcs palette_cursor_up      ; up
    lsr
    lsr
    bcs exit_palette_editor    ; select; ends with rts
    lsr
    bcs large_color_decrement  ; B
    bne large_color_increment  ; A

    ; nothing pressed
    jmp update_palette_editor_sprite_data  ; ends with rts

; --------------------------------------------------------------------------------------------------

palette_cursor_up:
    dex
    dex
palette_cursor_down:
    inx
    txa
    and #%00000011
    sta palette_cursor
    tax
    jmp update_palette_editor_sprite_data  ; ends with rts

small_color_decrement:
    dey
    dey
small_color_increment:
    iny
    tya
    and #$0f
    sta temp
    lda user_palette, x
    and #$f0
    ora temp
    sta user_palette, x
    jmp update_palette_editor_sprite_data  ; ends with rts

large_color_decrement:
    tya
    sec
    sbc #$10
    jmp +
large_color_increment:
    tya
    clc
    adc #$10
+   and #%00111111
    sta user_palette, x
    jmp update_palette_editor_sprite_data  ; ends with rts

; --------------------------------------------------------------------------------------------------

exit_palette_editor:
    ; show paint cursor
    lda initial_sprite_data + 0 * 4 + 0
    sta sprite_data + 0 * 4 + 0

    ; hide all palette editor sprites
    lda #$ff
    ldx #((palette_editor_sprite_count - 1) * 4)
-   sta sprite_data + paint_mode_sprite_count * 4, x
    dex
    dex
    dex
    dex
    bpl -

    lsr in_palette_editor  ; clear flag
    rts

; --------------------------------------------------------------------------------------------------

update_palette_editor_sprite_data:
    ; Update palette editor sprite data.
    ; Reads: palette_cursor, user_palette
    ; Writes: sprite_data

    ldx palette_cursor

    ; cursor sprite Y position
    txa
    asl
    asl
    asl
    clc
    adc #(22 * 8 - 1)
    sta sprite_data + paint_mode_sprite_count * 4 + 0

    ; 16s of color number (sprite tile)
    lda user_palette, x
    lsr
    lsr
    lsr
    lsr
    clc
    adc #10
    sta sprite_data + (paint_mode_sprite_count + 5) * 4 + 1

    ; ones of color number (sprite tile)
    lda user_palette, x
    and #$0f
    clc
    adc #$0a
    sta sprite_data + (paint_mode_sprite_count + 6) * 4 + 1

    rts

