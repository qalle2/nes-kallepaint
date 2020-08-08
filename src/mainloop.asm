; Kalle Paint - main loop

macro a_to_vram_buffer
    ; Y must hold a copy of VRAM buffer position
    sta vram_buffer, y
    iny
endm

macro a_from_vram_buffer
    ; Y must hold a copy of VRAM buffer position
    iny
    lda vram_buffer, y
endm

main_loop:
    ; wait until NMI has set flag
    bit run_main_loop
    bpl main_loop

    ; prevent ourselves from running again before next NMI
    lsr run_main_loop

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
    and #%00000011
    beq +
    sec
+   rol joypad_status
    bcc -

    ; start writing vram_buffer from beginning
    lda #0
    sta vram_buffer_pos

    ; tell NMI to update blinking cursor
    ;
    ldy vram_buffer_pos
    ;
    lda #$3f
    a_to_vram_buffer
    lda #$13
    a_to_vram_buffer
    ;
    lda blink_timer
    and #(1 << blink_rate)
    bne +
    lda #editor_bg
    jmp ++
+   lda #editor_text
++  sta vram_buffer, y
    iny
    ;
    sty vram_buffer_pos

    ; advance cursor blink timer
    inc blink_timer

    ; run one of three subs depending on the mode we're in
    ldx mode
    beq +
    dex
    beq ++
    jsr palette_edit_mode
    jmp main_loop_end
+   jsr paint_mode
    jmp main_loop_end
++  jsr attribute_edit_mode

main_loop_end:
    ; append terminator to vram_buffer
    ldy vram_buffer_pos
    lda #$00
    a_to_vram_buffer
    sty vram_buffer_pos

    jmp main_loop

; --------------------------------------------------------------------------------------------------

    include "mainloop-paint.asm"
    include "mainloop-attr.asm"
    include "mainloop-pal.asm"

; --- Misc subs ------------------------------------------------------------------------------------

hide_sprites:
    ; Hide sprites by setting their Y positions to $ff.
    ; X: first sprite, times four
    ; Y: number of sprites

    lda #$ff
-   sta sprite_data, x
    rept 4
        inx
    endr
    dey
    bne -
    rts

show_sprites:
    ; Show sprites by copying their Y positions from initial data.
    ; X: first sprite, times four
    ; Y: number of sprites

-   lda initial_sprite_data, x
    sta sprite_data, x
    rept 4
        inx
    endr
    dey
    bne -
    rts

get_decimal_tens:
    ; A: unsigned integer -> decimal tens
    ldx #$ff
    sec
-   inx
    sbc #10
    bcs -
    txa
    rts

get_decimal_ones:
    ; A: unsigned integer -> decimal ones
    sec
-   sbc #10
    bcs -
    adc #10
    rts

get_pos_in_attr_byte:
    ; Get position within attribute byte. (Used in paint/attribute edit mode.)
    ; bits: cursor_y = 00ABCDEF, cursor_x = 00abcdef -> X = 00000Dd0
    ; 0 = top left, 2 = top right, 4 = bottom left, 6 = bottom right.

    lda cursor_y
    and #%00000100
    sta bitop_temp
    lda cursor_x
    and #%00000100
    lsr
    ora bitop_temp
    tax
    rts

get_nt_at_offset_for_nt:
    ; Compute nt_at_offset for a *name table* byte. (Used in paint mode.)
    ; Bits: cursor_y = 00ABCDEF, cursor_x = 00abcdef
    ;       -> nt_at_offset = 000000AB CDEabcde

    lda cursor_y
    lsr
    lsr
    lsr
    lsr
    sta nt_at_offset + 1

    lda cursor_y
    and #%00001110
    asl
    asl
    asl
    asl
    sta bitop_temp
    lda cursor_x
    lsr
    ora bitop_temp
    sta nt_at_offset + 0

    rts

get_nt_at_offset_for_at:
    ; Compute nt_at_offset for an *attribute* byte. (Used in paint/attribute edit mode.)
    ; Bits: cursor_y = 00ABCDEF, cursor_x = 00abcdef
    ;       -> nt_at_offset = $3c0 + 00ABCabc = 00000011 11ABCabc

    lda #%00000011
    sta nt_at_offset + 1

    lda cursor_x
    lsr
    lsr
    lsr
    sta bitop_temp
    lda cursor_y
    and #%00111000
    ora #%11000000
    ora bitop_temp
    sta nt_at_offset + 0

    rts

get_nt_at_buffer_addr:
    ; Get nt_at_buffer_addr from nt_at_offset. (nt_at_buffer must start at $xx00.)
    ; (Used in paint/attribute edit mode.)

    lda nt_at_offset + 0
    sta nt_at_buffer_addr + 0
    clc
    lda #>nt_at_buffer
    adc nt_at_offset + 1
    sta nt_at_buffer_addr + 1

    rts

nt_at_update_to_vram_buffer:
    ; Add a name/attribute table update instruction to VRAM buffer, i.e.,
    ; tell NMI routine to write A to VRAM $2000 + nt_at_offset.
    ; (Used in paint/attribute edit mode.)

    pha

    ldy vram_buffer_pos

    lda nt_at_offset + 1
    ora #$20
    a_to_vram_buffer
    lda nt_at_offset + 0
    a_to_vram_buffer
    pla
    a_to_vram_buffer

    sty vram_buffer_pos

    rts

get_user_pal_offset:
    ; Get offset to user_palette or VRAM $3f00-$3f0f.
    ; (Used in palette editor.)
    ;   if palette_cursor = 0: 0
    ;   else:                  palette_subpal * 4 + palette_cursor
    ; Out: A, X

    lda palette_cursor
    beq +
    lda palette_subpal
    asl
    asl
    ora palette_cursor
+   tax
    rts

; --------------------------------------------------------------------------------------------------

replace_bit_pair:
    ; Replace a bit pair in a byte without modifying other bits.
    ; (Used in paint mode.)
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

bitpair_clear_masks:
    ; clear one bit pair
    db %00111111, %11001111, %11110011, %11111100

bitpair_set_masks:
    ; set one bit pair
    db %00000000, %01000000, %10000000, %11000000
    db %00000000, %00010000, %00100000, %00110000
    db %00000000, %00000100, %00001000, %00001100
    db %00000000, %00000001, %00000010, %00000011

; --------------------------------------------------------------------------------------------------

increment_bit_pair:
    ; Increment one bit pair in a byte (00 -> 01 -> 10 -> 11 -> 00) without modifying other bits.
    ; (Used in attribute edit mode.)
    ;   A: byte to modify
    ;   X: which bit pair to modify (0/2/4/6; 0 = least significant)
    ; The algorithm: if LSB is clear, only flip it, otherwise flip MSB too.

    pha
    and bitpair_increment_masks, x  ; if LSB set, increment LUT index to flip both bits
    beq +
    inx
+   pla
    eor bitpair_increment_masks, x
    rts

bitpair_increment_masks:
    ; LSB or both LSB and MSB of each bit pair
    db %00000001, %00000011
    db %00000100, %00001100
    db %00010000, %00110000
    db %01000000, %11000000

; --------------------------------------------------------------------------------------------------

get_cursor_color:
    ; Get correct color for cursor. (Used in paint mode.)
    ; In: cursor_x, cursor_y, nt_at_buffer, user_palette
    ; Out: A

    ; if color 0 of any subpal, no need to read nt_at_buffer
    ldx paint_color
    beq ++

    jsr get_nt_at_offset_for_at
    jsr get_nt_at_buffer_addr
    jsr get_pos_in_attr_byte  ; 0/2/4/6 to X

    ; read attribute byte, shift relevant bits to positions 1-0, clear other bits
    ldy #0
    lda (nt_at_buffer_addr), y
    cpx #0
    beq +
-   lsr
    dex
    bne -
+   and #%00000011

    ; get user_palette index
    asl
    asl
    ora paint_color
    tax

++  lda user_palette, x
    rts

