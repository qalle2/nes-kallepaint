; Kalle Paint - NMI routine

nmi:
    push_regs                      ; first thing to do
    copy_sprite_data sprite_data   ; do early
    reset_ppu_address_latch        ; do before VRAM accesses

    ; update VRAM from vram_buffer
    ; format: addr_hi (0 = terminator), addr_lo, byte, ...
    ;
    ldx #$ff
    ;
-   inx
    lda vram_buffer, x  ; address high or terminator
    beq +
    sta ppu_addr
    ;
    inx
    lda vram_buffer, x  ; address low
    sta ppu_addr
    ;
    inx
    lda vram_buffer, x  ; value
    sta ppu_data
    ;
    jmp -
+

    ; clear VRAM buffer (put terminator at beginning)
    lda #$00
    sta vram_buffer + 0

    set_ppu_address $0000      ; do after VRAM accesses
    set_ppu_scroll 0, 256 - 8  ; do after set_ppu_address

    set_flag run_main_loop
    pull_regs               ; last thing to do
    rti

