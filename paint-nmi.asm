nmi:
    ; push A, X, Y
    pha
    txa
    pha
    tya
    pha

    ; copy sprite data from RAM to PPU
    lda #>sprite_data
    sta oam_dma

    ; reset ppu_addr/ppu_scroll latch
    bit ppu_status

    ; run one of two subs depending on the mode we're in
    bit in_palette_editor
    bmi +
    jsr nmi_paint_mode
    jmp ++
+   jsr nmi_palette_edit_mode

    ; reset VRAM address & scroll
++  lda #$00
    sta ppu_addr
    sta ppu_addr
    sta ppu_scroll
    sta ppu_scroll

    ; set flag to allow main loop to run once
    sec
    ror execute_main_loop

    ; pull Y, X, A
    pla
    tay
    pla
    tax
    pla

    rti

; --- Paint mode -----------------------------------------------------------------------------------

nmi_paint_mode:
    ; update selected color to top bar (NT 0, row 2, column 26)
    ldx paint_color
    lda solid_color_tiles, x
    ldx #$20
    stx ppu_addr
    ldx #$5a
    stx ppu_addr
    sta ppu_data

    ; update one byte in VRAM paint area from nt_buffer if requested by main loop

    bit update_paint_area_vram
    bpl +

    lda paint_vram_address + 1
    sta ppu_addr
    lda paint_vram_address + 0
    sta ppu_addr
    ldy #0
    lda (nt_buffer_address), y
    sta ppu_data
    lsr update_paint_area_vram  ; clear flag

+   rts

; --- Palette edit mode ----------------------------------------------------------------------------

nmi_palette_edit_mode:
    ldx palette_cursor  ; cursor position
    ldy #$3f            ; high byte of ppu_addr
    bit ppu_status      ; reset ppu_addr latch

    ; copy selected color to first background subpalette
    sty ppu_addr
    stx ppu_addr
    lda user_palette, x
    sta ppu_data

    ; copy selected color to third/fourth sprite subpalette
    sty ppu_addr
    lda selected_color_offsets, x
    sta ppu_addr
    lda user_palette, x
    sta ppu_data

    rts

selected_color_offsets:
    db (4 + 2) * 4 + 2
    db (4 + 2) * 4 + 3
    db (4 + 3) * 4 + 2
    db (4 + 3) * 4 + 3

