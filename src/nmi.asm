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

    bit update_paint_area_vram
    bpl +

    ; address
    clc
    lda #<ppu_paint_area
    adc paint_area_offset + 0
    tax
    lda #>ppu_paint_area
    adc paint_area_offset + 1
    sta ppu_addr
    stx ppu_addr

    ; data
    ldy #0
    lda (nt_buffer_address), y
    sta ppu_data

    lsr update_paint_area_vram  ; clear flag

+   rts

; --------------------------------------------------------------------------------------------------

nmi_editor:
    ldx palette_cursor  ; cursor position
    ldy #$3f            ; high byte of ppu_addr

    ; set cursor color from blink timer
    sty ppu_addr
    lda #$13
    sta ppu_addr
    lda cursor_blink_timer
    and #(1 << edit_crsr_blink_rate)
    bne +
    lda #editor_bg_color
    jmp ++                ; unconditional
+   lda #editor_fg_color
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

