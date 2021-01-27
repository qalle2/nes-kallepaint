; Kalle Paint - interrupt routines

nmi_routine
        ; push A, X, Y
        pha
        txa
        pha
        tya
        pha

        ; reset ppu_addr/ppu_scroll latch
        bit ppu_status

        ; do OAM DMA
        lda #$00
        sta oam_addr
        lda #>sprite_data
        sta oam_dma

        ; update VRAM from buffer
        ldx #0
-       lda vram_buffer_addrhi, x   ; high byte of address
        beq +                       ; 0 = terminator
        sta ppu_addr
        lda vram_buffer_addrlo, x   ; low byte of address
        sta ppu_addr
        lda vram_buffer_value, x    ; data byte
        sta ppu_data
        inx
        jmp -

+       lda #$00
        ;
        ; clear buffer (put terminator at beginning)
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

        ; set flag to let main loop run once
        sec
        ror run_main_loop

        ; pull Y, X, A
        pla
        tay
        pla
        tax
        pla

irq_routine
        rti
