; Kalle Paint - initialization

reset:
    initialize_nes

    ; we use Y as the "zero register" during initialization
    ldy #$00

    ; disable all sound channels
    sty snd_chn

    ; clear zero page
    ldx #0
-   sty $00, x
    inx
    bne -

    ; clear nt_buffer ($320 = 4 * 200 bytes)
    tya
    tax
-   sta nt_buffer, x
    sta nt_buffer + 200, x
    sta nt_buffer + 400, x
    sta nt_buffer + 600, x
    inx
    cpx #200
    bne -

    ; set default coordinates and paint color
    lda #30
    sta paint_cursor_x
    lda #24
    sta paint_cursor_y
    inc paint_color

    ; init user palette
    ldx #3
-   lda initial_palette, x
    sta user_palette, x
    dex
    bpl -

    ; copy initial sprite data (paint mode, palette edit mode)
    ldx #((paint_mode_sprite_count + palette_editor_sprite_count) * 4 - 1)
-   lda initial_sprite_data, x
    sta sprite_data, x
    dex
    bpl -

    ; hide palette editor sprites and unused sprites
    lda #$ff
    ldx #(paint_mode_sprite_count * 4)
-   sta sprite_data, x
    inx
    inx
    inx
    inx
    bne -

    wait_for_vblank

    ; reset ppu_addr/ppu_scroll latch
    bit ppu_status

    ; set palette
    lda #$3f
    sta ppu_addr
    sty ppu_addr
    ldx #0
-   lda initial_palette, x
    sta ppu_data
    inx
    cpx #32
    bne -

    ; prepare to write name table 0 and attribute table 0
    lda #$20
    sta ppu_addr
    sty ppu_addr

    ; 1 row of invisible area (solid color 1)
    lda #$55
    ldx #32
    jsr print_repeatedly

    ; 3 rows of logo
    ldx #0
-   lda logo, x
    sta ppu_data
    inx
    cpx #(3 * 32)
    bne -

    ; 25 rows of paint area + 1 row of invisible area (solid color 0, 26*32 tiles)
    ldx #(26 * 8)
-   sty ppu_data
    sty ppu_data
    sty ppu_data
    sty ppu_data
    dex
    bne -

    ; attribute table - top bar: hex 55 55 55 55 55 55 15 55
    lda #$55
    ldx #6
    jsr print_repeatedly
    ldx #$15
    stx ppu_data
    sta ppu_data

    ; attribute table - paint area & invisible area: $00
    tya
    ldx #(7 * 8)
    jsr print_repeatedly

    ; clear VRAM address & scroll
    sty ppu_addr
    sty ppu_addr
    sty ppu_scroll
    sty ppu_scroll

    wait_vblank_start

    ; show background & sprites
    lda #%00011110
    sta ppu_mask

    ; enable NMI, use pattern table 1 for sprites
    lda #%10001000
    sta ppu_ctrl

    jmp main_loop

; --------------------------------------------------------------------------------------------------

print_repeatedly:
    ; print A X times
-   sta ppu_data
    dex
    bne -
    rts

; --------------------------------------------------------------------------------------------------

initial_palette:
    ; background
    db white, red,    green, blue    ; paint area; same as two last sprite subpalettes
    db white, yellow, blue,  lblue   ; top bar
    db white, white,  white, white   ; unused
    db white, white,  white, white   ; unused
    ; sprites
    db white, yellow, black, gray    ; top bar cover sprites, top bar text, paint cursor
    db white, black,  white, yellow  ; palette editor: BG, text, cursor
    db white, black,  white, red     ; palette editor: color 0&1 border, color 0, color 1
    db white, black,  green, blue    ; palette editor: color 2&3 border, color 2, color 3

initial_sprite_data:
    ; paint mode
    db 0 * 8 - 1, $10, %00000000,  0 * 8   ; cursor
    db    12 - 1, $00, %00000000, 29 * 8   ; tens of X position
    db    12 - 1, $00, %00000000, 30 * 8   ; ones of X position
    db    20 - 1, $00, %00000000, 29 * 8   ; tens of Y position
    db    20 - 1, $00, %00000000, 30 * 8   ; ones of Y position
    db    12 - 1, $13, %00000000, 28 * 8   ; "X"
    db    20 - 1, $14, %00000000, 28 * 8   ; "Y"
    db 2 * 8 - 1, $19, %00000000, 27 * 8   ; cover 1 for selected color
    db 3 * 8 - 1, $19, %00000000, 26 * 8   ; cover 2 for selected color
    db 3 * 8 - 1, $19, %00000000, 27 * 8   ; cover 3 for selected color

    ; palette edit mode
    db 22 * 8 - 1, $12, %00000001, 1 * 8   ; cursor
    db 22 * 8 - 1, $17, %00000010, 2 * 8   ; selected color 0
    db 23 * 8 - 1, $18, %00000010, 2 * 8   ; selected color 1
    db 24 * 8 - 1, $17, %00000011, 2 * 8   ; selected color 2
    db 25 * 8 - 1, $18, %00000011, 2 * 8   ; selected color 3
    db 26 * 8 - 1, $00, %00000001, 1 * 8   ; 16s  of color number
    db 26 * 8 - 1, $00, %00000001, 2 * 8   ; ones of color number
    db 21 * 8 - 1, $15, %00000001, 1 * 8   ; left half of "PAL"
    db 21 * 8 - 1, $16, %00000001, 2 * 8   ; right half of "PAL"
    db 22 * 8 - 1, $19, %00000001, 1 * 8   ; blank
    db 23 * 8 - 1, $19, %00000001, 1 * 8   ; blank
    db 24 * 8 - 1, $19, %00000001, 1 * 8   ; blank
    db 25 * 8 - 1, $19, %00000001, 1 * 8   ; blank

logo:
    ; from logo-encode.py
    incbin "logo.bin", 0, 96

