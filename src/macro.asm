; Kalle Paint - macros

macro write_vram_buffer
    ; Write one byte to VRAM buffer with preincrement.
    ; Note: 6502 has sta zp,x but no sta zp,y

    inx
    sta vram_buffer, x
endm

macro write_vram_buffer_addr _addr
    ; Write two bytes to VRAM buffer with preincrement.
    ; Note: 6502 has sta zp,x but no sta zp,y

    lda #>(_addr)
    inx
    sta vram_buffer, x
    if (<_addr) != (>_addr)
        lda #<(_addr)
    endif
    inx
    sta vram_buffer, x
endm

