; Kalle Paint - NMI routine - paint mode

nmi_paint_mode:
    ; update selected color to top bar (NT 0, row 2, column 26)
    ldx paint_color
    lda solid_color_tiles_nmi, x
    ldx #$20
    stx ppu_addr
    ldx #$5a
    stx ppu_addr
    sta ppu_data

    ; update one byte in VRAM paint area from nt_buffer if requested by main loop

    bit update_paint_area_vram
    bpl +

    ; VRAM address
    clc
    lda #<ppu_paint_area
    adc paint_area_offset + 0
    tax
    lda #>ppu_paint_area
    adc paint_area_offset + 1
    sta ppu_addr
    stx ppu_addr

    ; VRAM data
    ldy #0
    lda (nt_buffer_address), y
    sta ppu_data

    lsr update_paint_area_vram  ; don't do this again

+   rts

solid_color_tiles_nmi:
    ; tile indexes of solid color 0/1/2/3
    hex 00 55 aa ff

