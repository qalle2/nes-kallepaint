; Kalle Paint - non-maskable interrupt routine

nmi_routine
        pha  ; push A, X, Y
        txa
        pha
        tya
        pha

        bit ppu_status  ; reset ppu_addr/ppu_scroll latch

        lda #$00           ; do OAM DMA
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
        sta vram_buffer_addrhi + 0  ; clear buffer (put terminator at beginning)
        ;
        sta ppu_addr  ; reset PPU address
        sta ppu_addr
        ;
        sta ppu_scroll  ; set PPU scroll
        lda #(256 - 8)
        sta ppu_scroll

        sec                ; set flag to let main loop run once
        ror run_main_loop

        pla  ; pull Y, X, A
        tay
        pla
        tax
        pla

        rti

