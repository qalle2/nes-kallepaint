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
    jsr nmi_paint
    jmp ++
+   jsr nmi_editor

    ; reset VRAM address & scroll
++  lda #$00
    sta ppu_addr
    sta ppu_addr
    sta ppu_scroll
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

    rti

; --------------------------------------------------------------------------------------------------

nmi_paint:
    ; update paint color to cursor
    lda #$3f
    sta ppu_addr
    lda #$13
    sta ppu_addr
    ldx paint_color
    lda user_palette, x
    sta ppu_data

    ; update one byte in VRAM paint area from nt_buffer if requested by main loop

    bit update_nt
    bpl +

    ; address ($2000 + nt_offset; high byte of nt_offset is 0-3)
    lda #$20
    ora nt_offset + 1
    sta ppu_addr
    lda nt_offset + 0
    sta ppu_addr

    ; data
    ldy #0
    lda (nt_buffer_address), y
    sta ppu_data

    ; clear flag
    lsr update_nt

+   rts

; --------------------------------------------------------------------------------------------------

nmi_editor:
    ldx palette_cursor  ; cursor position
    ldy #$3f            ; high byte of ppu_addr

    ; set cursor color from blink timer
    sty ppu_addr
    lda #$13
    sta ppu_addr
    lda blink_timer
    and #(1 << blink_rate)
    bne +
    lda #editor_bg
    jmp ++
+   lda #editor_text
++  sta ppu_data

    ; update selected color to background palette
    sty ppu_addr
    stx ppu_addr
    lda user_palette, x
    sta ppu_data

    ; update selected color to 3rd color of some sprite subpalette ($3f12/$3f16/$3f1a/$3f1e)
    sty ppu_addr
    txa
    asl
    asl
    adc #$12      ; carry is always clear
    sta ppu_addr
    lda user_palette, x
    sta ppu_data

    rts

