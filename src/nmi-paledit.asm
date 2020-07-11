; Kalle Paint - NMI routine - palette edit mode

nmi_palette_edit_mode:
    ldx palette_cursor  ; cursor position
    ldy #$3f            ; high byte of ppu_addr

    ; copy selected color to first background subpalette:
    ; RAM[user_palette + palette_cursor] -> VRAM[$3f00 + palette_cursor]
    sty ppu_addr
    stx ppu_addr
    lda user_palette, x
    sta ppu_data

    ; copy selected color to a sprite subpalette:
    ; RAM[user_palette + palette_cursor] -> VRAM[$3f00 + selected_color_offsets[palette_cursor]]
    sty ppu_addr
    lda selected_color_offsets, x
    sta ppu_addr
    lda user_palette, x
    sta ppu_data

    rts

selected_color_offsets:
    ; 3rd/4th color of 3rd/4th sprite subpalette
    db (4 + 2) * 4 + 2
    db (4 + 2) * 4 + 3
    db (4 + 3) * 4 + 2
    db (4 + 3) * 4 + 3

