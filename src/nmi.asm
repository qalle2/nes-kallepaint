; Kalle Paint - NMI routine

nmi:
    push_registers                 ; first thing to do
    copy_sprite_data sprite_data   ; do early
    reset_ppu_address_latch        ; do before VRAM accesses

    ; update VRAM from vram_buffer (unrolled loop for more speed)
    ; format: addr_hi (0 = terminator), addr_lo, value, ...
    ;
    ldx #$ff
nmi_loop_start
rept 6
    inx
    lda vram_buffer, x   ; address high or terminator
    beq nmi_loop_end
    sta ppu_addr
    ;
    inx
    lda vram_buffer, x   ; address low
    sta ppu_addr
    ;
    inx
    lda vram_buffer, x   ; value
    sta ppu_data
endr
    jmp nmi_loop_start
nmi_loop_end

    ; clear VRAM buffer (put terminator at beginning)
    lda #$00
    sta vram_buffer + 0
    ; reset PPU address
    sta ppu_addr
    sta ppu_addr
    ; set PPU scroll
    sta ppu_scroll
    lda #(256 - 8)
    sta ppu_scroll

    set_flag run_main_loop
    pull_registers             ; last thing to do
    rti

