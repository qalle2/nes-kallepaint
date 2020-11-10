; Kalle Paint - NMI routine

nmi_routine
    ; push A, X, Y
    pha
    txa
    pha
    tya
    pha

    ; reset address latch
    bit ppu_status

    ; do OAM DMA
    copy_via_a #$00, oam_addr
    copy_via_a #>sprite_data, oam_dma

    ; update VRAM from vram_buffer
    ; format: addr_hi (0 = terminator), addr_lo, value, ...
    ;
    ldx #$ff
-   inx
    lda vram_buffer, x   ; address high or terminator
    beq +
    sta ppu_addr
    ;
    inx
    lda vram_buffer, x   ; address low
    sta ppu_addr
    ;
    inx
    lda vram_buffer, x   ; value
    sta ppu_data
    jmp -

+   lda #$00
    ;
    ; clear VRAM buffer (put terminator at beginning)
    sta vram_buffer + 0
    ;
    ; reset PPU address
    sta ppu_addr
    sta ppu_addr
    ;
    ; set PPU scroll
    sta ppu_scroll
    lda #(256 - 8)
    sta ppu_scroll

    ; set flag
    sec
    ror run_main_loop

    ; pull Y, X, A
    pla
    tay
    pla
    tax
    pla

    rti

