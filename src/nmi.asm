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

    ; update VRAM from buffer
    ldx #0
-   lda vram_buffer_addrhi, x   ; high byte of address
    beq +                       ; 0 = terminator
    sta ppu_addr
    lda vram_buffer_addrlo, x   ; low byte of address
    sta ppu_addr
    lda vram_buffer_value, x    ; data byte
    sta ppu_data
    inx
    jmp -

+   lda #$00
    ;
    ; clear VRAM buffer (put terminator at beginning)
    sta vram_buffer_addrhi + 0
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

