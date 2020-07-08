reset:
    initialize_nes

    ; disable all sound channels
    lda #$00
    sta snd_chn

    ; clear zero page
    lda #$00
    tax
-   sta $00, x
    inx
    bne -

    ; clear nt_buffer (800 = 4 * 200 bytes)
    lda #$00
    tax
-   sta nt_buffer, x
    sta nt_buffer + 200, x
    sta nt_buffer + 400, x
    sta nt_buffer + 600, x
    inx
    cpx #200
    bne -

    ; init user palette
    ldx #3
-   lda initial_palette, x
    sta user_palette, x
    dex
    bpl -

    jsr set_sprite_data

    inc paint_color  ; default color: 1

    wait_for_vblank

    ; reset ppu_addr/ppu_scroll latch
    bit ppu_status

    jsr set_palette
    jsr set_pattern_tables
    jsr set_name_table

    ; clear VRAM address & scroll
    lda #$00
    tax
    jsr set_vram_address
    sta ppu_scroll
    sta ppu_scroll

    wait_vblank_start

    ; show background & sprites
    lda #%00011110
    sta ppu_mask

    ; enable NMI, use pattern table 1 for sprites
    lda #%10001000
    sta ppu_ctrl

    jmp main_loop

; --------------------------------------------------------------------------------------------------

set_sprite_data:
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

    rts

initial_sprite_data:
    ; paint mode
    db 0 * 8 - 1, $02, %00000000,  0 * 8   ; cursor
    db    12 - 1, $00, %00000000, 29 * 8   ; tens of X position
    db    12 - 1, $00, %00000000, 30 * 8   ; ones of X position
    db    20 - 1, $00, %00000000, 29 * 8   ; tens of Y position
    db    20 - 1, $00, %00000000, 30 * 8   ; ones of Y position
    db    12 - 1, $1a, %00000000, 28 * 8   ; "X"
    db    20 - 1, $1b, %00000000, 28 * 8   ; "Y"
    db 2 * 8 - 1, $01, %00000000, 27 * 8   ; cover 1 for selected color
    db 3 * 8 - 1, $01, %00000000, 26 * 8   ; cover 2 for selected color
    db 3 * 8 - 1, $01, %00000000, 27 * 8   ; cover 3 for selected color

    ; palette edit mode
    db 22 * 8 - 1, $07, %00000001, 1 * 8   ; cursor
    db 22 * 8 - 1, $08, %00000010, 2 * 8   ; selected color 0
    db 23 * 8 - 1, $09, %00000010, 2 * 8   ; selected color 1
    db 24 * 8 - 1, $08, %00000011, 2 * 8   ; selected color 2
    db 25 * 8 - 1, $09, %00000011, 2 * 8   ; selected color 3
    db 26 * 8 - 1, $01, %00000001, 1 * 8   ; 16s  of color number
    db 26 * 8 - 1, $01, %00000001, 2 * 8   ; ones of color number
    db 21 * 8 - 1, $05, %00000001, 1 * 8   ; left half of "PAL"
    db 21 * 8 - 1, $06, %00000001, 2 * 8   ; right half of "PAL"
    db 22 * 8 - 1, $01, %00000001, 1 * 8   ; blank
    db 23 * 8 - 1, $01, %00000001, 1 * 8   ; blank
    db 24 * 8 - 1, $01, %00000001, 1 * 8   ; blank
    db 25 * 8 - 1, $01, %00000001, 1 * 8   ; blank

; --------------------------------------------------------------------------------------------------

set_palette:
    ; set palette
    lda #$3f
    ldx #$00
    jsr set_vram_address
-   lda initial_palette, x
    sta ppu_data
    inx
    cpx #32
    bne -
    rts

initial_palette:
    ; background
    db white, red,    green, blue    ; paint area; same as two last sprite subpalettes
    db white, yellow, blue,  lblue   ; top bar
    db white, white,  white, white   ; unused
    db white, white,  white, white   ; unused
    ; sprites
    db white, yellow, black, gray    ; status bar cover sprite, status bar text, paint cursor
    db white, black,  white, yellow  ; palette editor - text and cursor
    db white, black,  white, red     ; palette editor - selected colors 0&1
    db white, black,  green, blue    ; palette editor - selected colors 2&3

; --------------------------------------------------------------------------------------------------

set_pattern_tables:
    ; first half of CHR RAM (background)

    ; all combinations of 2*2 subpixels * 4 colors
    ; bits of tile index: AaBbCcDd
    ; corresponding subpixel colors (capital letter = MSB, small letter = LSB):
    ; Aa Bb
    ; Cc Dd

    lda #$00
    tax
    jsr set_vram_address
    ldy #15
--  ldx #15
-   lda background_chr_data1, y
    jsr print_four_times
    lda background_chr_data1, x
    jsr print_four_times
    lda background_chr_data2, y
    jsr print_four_times
    lda background_chr_data2, x
    jsr print_four_times
    dex
    bpl -
    dey
    bpl --

    ; second half of CHR RAM (sprites; 32 tiles, 512 bytes)
    ldx #0
-   lda sprite_chr_data, x
    sta ppu_data
    inx
    bne -
-   lda sprite_chr_data + 256, x
    sta ppu_data
    inx
    bne -

    rts

background_chr_data1:
    ; read backwards
    hex ff f0 ff f0  0f 00 0f 00  ff f0 ff f0  0f 00 0f 00

background_chr_data2:
    ; read backwards
    hex ff ff f0 f0  ff ff f0 f0  0f 0f 00 00  0f 0f 00 00

sprite_chr_data:
    ; 32 tiles (512 bytes)
    incbin "sprites.bin"

; --------------------------------------------------------------------------------------------------

set_name_table:
    ; Set name table 0 and attribute table 0.

    lda #$20
    ldx #$00
    jsr set_vram_address

    ; name table

    ; top bar (4 rows)
    lda #%01010101  ; block of color 1
    ldx #32
    jsr print_repeatedly
    ldx #0
-   lda logo, x
    sta ppu_data
    inx
    cpx #(3 * 32)
    bne -

    ; paint area (25 rows) + bottom bar (1 row)
    lda #$00
    ldx #(26 * 8)
-   jsr print_four_times
    dex
    bne -

    ; attribute table

    ; top bar
    lda #%01010101
    ldx #6
    jsr print_repeatedly
    lda #%00010101
    sta ppu_data
    lda #%01010101
    sta ppu_data

    ; paint area + bottom bar
    lda #%00000000
    ldx #(7 * 8)
    jsr print_repeatedly

    rts

print_repeatedly:
    ; print A X times
-   sta ppu_data
    dex
    bne -
    rts

logo:
    ; Output from "paint-logo-encode.py".
    ; 32*3 bytes (tile indexes), 64*6 pixels.
    ; 1 byte = 2*2 pixels:
    ; - bits: AaBbCcDd
    ; - pixels: Aa = upper left, Bb = upper right, Cc = lower left, Dd = lower right
    ; - capital letter = MSB, small letter = LSB

    incbin "logo.bin"

; --------------------------------------------------------------------------------------------------

set_vram_address:
    ; A = high byte, X = low byte
    sta ppu_addr
    stx ppu_addr
    rts

print_four_times:
    sta ppu_data
    sta ppu_data
    sta ppu_data
    sta ppu_data
    rts

