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

    ; update VRAM from vram_buffer
    ; format: addr_hi (0 = terminator), addr_lo, byte, ...
    ;
    ldx #0
-   lda vram_buffer, x
    beq +
    sta ppu_addr
    inx
    lda vram_buffer, x
    sta ppu_addr
    inx
    lda vram_buffer, x
    sta ppu_data
    inx
    jmp -
+

    ; clear vram_buffer (put terminator at beginning), reset VRAM address and set scroll
    lda #$00
    sta vram_buffer + 0
    sta ppu_addr
    sta ppu_addr
    sta ppu_scroll
    lda #(256 - 8)
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

