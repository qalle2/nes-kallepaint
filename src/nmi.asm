; Kalle Paint - NMI routine

nmi:
    ; push A, X, Y
    pha
    txa
    pha
    tya
    pha

    ; copy sprite data from RAM to PPU
    lda #$00
    sta oam_addr
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

    ; let main loop run once
    sec
    ror run_main_loop

    ; pull Y, X, A
    pla
    tay
    pla
    tax
    pla

    rti

