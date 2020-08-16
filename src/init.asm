; Kalle Paint - initialization

reset:
    ; Initialize the NES. See http://wiki.nesdev.com/w/index.php/Init_code
    ;
    ; ignore IRQs
    sei
    ;
    ; disable decimal mode
    cld
    ;
    ; disable APU frame IRQ
    ldx #$40
    stx joypad2
    ;
    ; initialize stack pointer
    ldx #$ff
    txs
    ;
    ; disable NMI, rendering, DMC IRQs and all sound channels
    inx
    stx ppu_ctrl
    stx ppu_mask
    stx dmc_freq
    stx snd_chn

    wait_vblank_start

    ; clear zero page, nt_at_buffer and vram_buffer
    lda #$00
    tax
    ldx #0
-   sta $00, x
    sta nt_at_buffer, x
    sta nt_at_buffer + $100, x
    sta nt_at_buffer + $200, x
    sta nt_at_buffer + $300, x
    sta vram_buffer, x
    inx
    bne -

    ; initialize nonzero variables
    ;
    copy_array initial_palette, user_palette, 16
    copy_array initial_sprite_data, sprite_data, 30 * 4
    ;
    ; hide sprites except paint cursor (#0)
    lda #$ff
    ldx #(1 * 4)
-   sta sprite_data, x
    inx
    inx
    inx
    inx
    bne -
    ;
    ; misc
    copy #30, cursor_x
    copy #26, cursor_y
    inc paint_color

    ; prepare for PPU operations
    wait_vblank_start
    reset_ppu_address_latch

    ; set palette
    set_ppu_address $3f00
    copy_array_to_vram initial_palette, 32

    ; clear name/attribute table 0 ($400 bytes)
    set_ppu_address $2000
    lda #$00
    ldy #4
--  tax
-   sta ppu_data
    inx
    bne -
    dey
    bne --

    set_ppu_address $0000      ; do after VRAM accesses
    set_ppu_scroll 0, 256 - 8  ; do after set_ppu_address
    wait_vblank_start          ; do before enabling rendering

    ; show background and sprites on entire screen,
    ; don't use R/G/B de-emphasis or grayscale mode
    copy #%00011110, ppu_mask

    ; enable NMI,
    ; use 8*8-pixel sprites,
    ; use pattern table 0 for background and 1 for sprites,
    ; use 1-byte VRAM address auto-increment,
    ; use name table 0
    copy #%10001000, ppu_ctrl

    jmp main_loop

; --------------------------------------------------------------------------------------------------

initial_palette:
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

initial_sprite_data:
    ; Y, tile, attributes, X

    ; paint mode
    db $ff, tile_smallcur, %00000000, 0  ; #0: cursor

    ; attribute editor
    db $ff, tile_attrcur, %00000000, 0  ; #1: cursor top left
    db $ff, tile_attrcur, %01000000, 0  ; #2: cursor top right
    db $ff, tile_attrcur, %10000000, 0  ; #3: cursor bottom left
    db $ff, tile_attrcur, %11000000, 0  ; #4: cursor bottom right

    ; palette editor
    db        $ff, tile_largecur,  %00000000, 15 * 8  ; #5:  cursor
    db 11 * 8 - 1, tile_x,         %00000001, 14 * 8  ; #6:  "X"
    db 11 * 8 - 1, $00,            %00000001, 15 * 8  ; #7:  X position - tens
    db 11 * 8 - 1, $00,            %00000001, 16 * 8  ; #8:  X position - ones
    db 12 * 8 - 1, tile_y,         %00000001, 14 * 8  ; #9:  "Y"
    db 12 * 8 - 1, $00,            %00000001, 15 * 8  ; #10: Y position - tens
    db 12 * 8 - 1, $00,            %00000001, 16 * 8  ; #11: Y position - ones
    db 13 * 8 - 1, tile_p,         %00000001, 14 * 8  ; #12: "P"
    db 13 * 8 - 1, $00,            %00000001, 15 * 8  ; #13: subpalette number
    db 14 * 8 - 1, tile_digits+$c, %00000001, 14 * 8  ; #14: "C"
    db 14 * 8 - 1, $00,            %00000001, 15 * 8  ; #15: color number - 16s
    db 14 * 8 - 1, $00,            %00000001, 16 * 8  ; #16: color number - ones
    db 15 * 8 - 1, tile_colorind,  %00000000, 15 * 8  ; #17: color 0
    db 16 * 8 - 1, tile_colorind,  %00000001, 15 * 8  ; #18: color 1
    db 17 * 8 - 1, tile_colorind,  %00000010, 15 * 8  ; #19: color 2
    db 18 * 8 - 1, tile_colorind,  %00000011, 15 * 8  ; #20: color 3
    db 13 * 8 - 1, tile_cover,     %00000001, 16 * 8  ; #21: cover (to right of subpal number)
    db 15 * 8 - 1, tile_cover,     %00000001, 14 * 8  ; #22: cover (to left of color 0)
    db 16 * 8 - 1, tile_cover,     %00000001, 14 * 8  ; #23: cover (to left of color 1)
    db 17 * 8 - 1, tile_cover,     %00000001, 14 * 8  ; #24: cover (to left of color 2)
    db 18 * 8 - 1, tile_cover,     %00000001, 14 * 8  ; #25: cover (to left of color 3)
    db 15 * 8 - 1, tile_cover,     %00000001, 16 * 8  ; #26: cover (to right of color 0)
    db 16 * 8 - 1, tile_cover,     %00000001, 16 * 8  ; #27: cover (to right of color 1)
    db 17 * 8 - 1, tile_cover,     %00000001, 16 * 8  ; #28: cover (to right of color 2)
    db 18 * 8 - 1, tile_cover,     %00000001, 16 * 8  ; #29: cover (to right of color 3)

