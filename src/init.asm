; Kalle Paint - initialization

reset
        ; initialize the NES; see http://wiki.nesdev.com/w/index.php/Init_code
        sei           ; ignore IRQs
        cld           ; disable decimal mode
        ldx #$40
        stx joypad2   ; disable APU frame IRQ
        ldx #$ff
        txs           ; initialize stack pointer
        inx
        stx ppu_ctrl  ; disable NMI
        stx ppu_mask  ; disable rendering
        stx dmc_freq  ; disable DMC IRQs
        stx snd_chn   ; disable sound channels

        ; wait until next VBlank starts
        bit ppu_status
-       bit ppu_status
        bpl -

        ; clear zero page and vram_copy
        lda #$00
        tax
        ldx #0
-       sta $00, x
        sta vram_copy, x
        sta vram_copy + $100, x
        sta vram_copy + $200, x
        sta vram_copy + $300, x
        inx
        bne -

        ; initialize nonzero variables
        ;
        ldx #(16 - 1)
-       lda initial_palette, x
        sta user_palette, x
        dex
        bpl -
        ;
        ldx #(24 * 4 - 1)
-       lda initial_sprite_data, x
        sta sprite_data, x
        dex
        bpl -
        ;
        ; hide sprites except paint cursor (#0)
        lda #$ff
        ldx #(1 * 4)
-       sta sprite_data, x
        inx
        inx
        inx
        inx
        bne -
        ;
        ; misc
        lda #30
        sta cursor_x
        lda #26
        sta cursor_y
        inc paint_color

        ; wait until next VBlank starts
        bit ppu_status
-       bit ppu_status
        bpl -

        ; set palette
        lda #$3f
        sta ppu_addr
        ldx #$00
        stx ppu_addr
-       lda initial_palette, x
        sta ppu_data
        inx
        cpx #32
        bne -

        ; clear name/attribute table 0 ($400 bytes)
        lda #$20
        sta ppu_addr
        lda #$00
        sta ppu_addr
        ldy #4
--      tax
-       sta ppu_data
        inx
        bne -
        dey
        bne --

        ; reset PPU address and scroll
        bit ppu_status  ; reset latch
        lda #$00
        sta ppu_addr
        sta ppu_addr
        sta ppu_scroll
        lda #(256 - 8)
        sta ppu_scroll

        ; wait until next VBlank starts
        bit ppu_status
-       bit ppu_status
        bpl -

        ; enable NMI,
        ; use 8*8-pixel sprites,
        ; use pattern table 0 for background and 1 for sprites,
        ; use 1-byte VRAM address auto-increment,
        ; use name table 0
        lda #%10001000
        sta ppu_ctrl

        ; show background and sprites on entire screen,
        ; don't use R/G/B de-emphasis or grayscale mode
        lda #%00011110
        sta ppu_mask

        jmp main_loop

; --------------------------------------------------------------------------------------------------

initial_palette
        ; background (also the initial user palette)
        db defcol_bg, defcol0a, defcol0b, defcol0c
        db defcol_bg, defcol1a, defcol1b, defcol1c
        db defcol_bg, defcol2a, defcol2b, defcol2c
        db defcol_bg, defcol3a, defcol3b, defcol3c
        ;
        ; sprites
        ; all subpalettes used for selected colors in palette editor
        ; 1st one also used for all cursors         (4th color = foreground)
        ; 2nd one also used for palette editor text (4th color = foreground)
        db defcol_bg, editor_bg, defcol_bg, defcol0a
        db defcol_bg, editor_bg, defcol0a,  editor_text
        db defcol_bg, editor_bg, defcol0b,  defcol_bg
        db defcol_bg, editor_bg, defcol0c,  defcol_bg

initial_sprite_data
        ; Y, tile, attributes, X

        ; paint mode
        db $ff, tile_smallcur, %00000000, 0  ; #0: cursor

        ; attribute editor
        db $ff, tile_attrcur, %00000000, 0  ; #1: cursor top left
        db $ff, tile_attrcur, %01000000, 0  ; #2: cursor top right
        db $ff, tile_attrcur, %10000000, 0  ; #3: cursor bottom left
        db $ff, tile_attrcur, %11000000, 0  ; #4: cursor bottom right

        ; palette editor
        db        $ff, tile_largecur, %00000000, 29 * 8  ; #5:  cursor
        db 22 * 8 - 1, tile_p,        %00000001, 28 * 8  ; #6:  "P"
        db 22 * 8 - 1, $00,           %00000001, 30 * 8  ; #7:  subpalette number
        db 23 * 8 - 1, $0c,           %00000001, 28 * 8  ; #8:  "C"
        db 23 * 8 - 1, $00,           %00000001, 29 * 8  ; #9:  color number - 16s
        db 23 * 8 - 1, $00,           %00000001, 30 * 8  ; #10: color number - ones
        db 24 * 8 - 1, tile_colorind, %00000000, 29 * 8  ; #11: color 0
        db 25 * 8 - 1, tile_colorind, %00000001, 29 * 8  ; #12: color 1
        db 26 * 8 - 1, tile_colorind, %00000010, 29 * 8  ; #13: color 2
        db 27 * 8 - 1, tile_colorind, %00000011, 29 * 8  ; #14: color 3
        db 22 * 8 - 1, tile_cover,    %00000001, 29 * 8  ; #15: cover (to left of subpal number)
        db 24 * 8 - 1, tile_cover,    %00000001, 28 * 8  ; #16: cover (to left of color 0)
        db 24 * 8 - 1, tile_cover,    %00000001, 30 * 8  ; #17: cover (to right of color 0)
        db 25 * 8 - 1, tile_cover,    %00000001, 28 * 8  ; #18: cover (to left of color 1)
        db 25 * 8 - 1, tile_cover,    %00000001, 30 * 8  ; #19: cover (to right of color 1)
        db 26 * 8 - 1, tile_cover,    %00000001, 28 * 8  ; #20: cover (to left of color 2)
        db 26 * 8 - 1, tile_cover,    %00000001, 30 * 8  ; #21: cover (to right of color 2)
        db 27 * 8 - 1, tile_cover,    %00000001, 28 * 8  ; #22: cover (to left of color 3)
        db 27 * 8 - 1, tile_cover,    %00000001, 30 * 8  ; #23: cover (to right of color 3)
