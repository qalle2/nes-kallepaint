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

    ; clear nt_buffer ($380 = 4 * 224 bytes)
    tya
    tax
-   sta nt_buffer, x
    sta nt_buffer + 224, x
    sta nt_buffer + 2 * 224, x
    sta nt_buffer + 3 * 224, x
    inx
    cpx #224
    bne -

    ; set nonzero default values
    lda #30
    sta paint_cursor_x
    lda #26
    sta paint_cursor_y
    inc paint_color

    ; init user palette
    ldx #3
-   lda initial_palette_bg, x
    sta user_palette, x
    dex
    bpl -

    ; copy initial sprite data (paint mode, palette edit mode)
    ldx #(initial_sprite_data_end - initial_sprite_data - 1)
-   lda initial_sprite_data, x
    sta sprite_data, x
    dex
    bpl -

    ; hide all sprites except the first one (cursor)
    lda #$ff
    ldx #(1 * 4)
-   sta sprite_data, x
    inx
    inx
    inx
    inx
    bne -

    wait_for_vblank

    ; reset ppu_addr/ppu_scroll latch
    bit ppu_status

    ; set BG palette
    lda #$3f
    sta ppu_addr
    sty ppu_addr
    ldx #0
-   lda initial_palette_bg, x
    sta ppu_data
    inx
    cpx #4
    bne -

    ; set sprite palettes
    lda #$3f
    sta ppu_addr
    lda #$10
    sta ppu_addr
    ldx #0
-   lda initial_palette_spr, x
    sta ppu_data
    inx
    cpx #16
    bne -

    ; clear name table 0 and attribute 0 ($400 bytes)
    lda #$20
    sta ppu_addr
    sty ppu_addr
    ldx #0
-   sty ppu_data
    sty ppu_data
    sty ppu_data
    sty ppu_data
    inx
    bne -

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

    jmp main

; --------------------------------------------------------------------------------------------------

initial_palette_bg:
    ; first background subpalette (paint area)
    db default_color0, default_color1, default_color2, default_color3

initial_palette_spr:
    ; all subpalettes used for selected colors in palette editor
    ; first  one also used for cursors             (4th color = foreground)
    ; second one also used for palette editor text (4th color = foreground)
    db default_color0, editor_bg_color, default_color0, default_color1
    db default_color0, editor_bg_color, default_color1, editor_fg_color
    db default_color0, editor_bg_color, default_color2, default_color0
    db default_color0, editor_bg_color, default_color3, default_color0

initial_sprite_data:
    ; Y position, tile, attributes (subpalette), X position

    db        $ff, $10, $00, 0       ; #0:  cursor (paint/palette editor)
    db 11 * 8 - 1, $12, $01, 14 * 8  ; #1:  "X"
    db 11 * 8 - 1, $00, $01, 15 * 8  ; #2:  tens of X position
    db 11 * 8 - 1, $00, $01, 16 * 8  ; #3:  ones of X position
    db 12 * 8 - 1, $13, $01, 14 * 8  ; #4:  "Y"
    db 12 * 8 - 1, $00, $01, 15 * 8  ; #5:  tens of Y position
    db 12 * 8 - 1, $00, $01, 16 * 8  ; #6:  ones of Y position
    db 13 * 8 - 1, $0c, $01, 14 * 8  ; #7:  "C"
    db 13 * 8 - 1, $00, $01, 15 * 8  ; #8:  16s  of color number
    db 13 * 8 - 1, $00, $01, 16 * 8  ; #9:  ones of color number
    db 14 * 8 - 1, $14, $00, 15 * 8  ; #10: selected color 0
    db 15 * 8 - 1, $14, $01, 15 * 8  ; #11: selected color 1
    db 16 * 8 - 1, $14, $02, 15 * 8  ; #12: selected color 2
    db 17 * 8 - 1, $14, $03, 15 * 8  ; #13: selected color 3

initial_sprite_data_end:

