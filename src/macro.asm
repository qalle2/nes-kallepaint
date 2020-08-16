; Kalle Paint - macros

; --- Flags ---------------------------------------------------------------------------------------

macro clear_flag _flag
    ; Clear bit 7 of _flag.

    lsr _flag
endm

macro set_flag _flag
    ; Set bit 7 of _flag.

    sec
    ror _flag
endm

macro branch_if_clear _flag, _target
    ; Branch to _target if bit 7 of _flag is clear.

    bit _flag
    bpl _target
endm

macro branch_if_set _flag, _target
    ; Branch to _target if bit 7 of _flag is set.

    bit _flag
    bmi _target
endm

; --- VRAM buffer ---------------------------------------------------------------------------------

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

; --- Misc ----------------------------------------------------------------------------------------

macro copy _from, _to
    ; Copy a byte.

    lda _from
    sta _to
endm

macro push_regs
    ; Push A, X, Y.

    pha
    txa
    pha
    tya
    pha
endm

macro pull_regs
    ; Pull Y, X, A.

    pla
    tay
    pla
    tax
    pla
endm

macro set_ppu_address _addr
    ; Set PPU address.

    lda #>(_addr)
    sta ppu_addr
    if (<_addr) != (>_addr)
        lda #<(_addr)
    endif
    sta ppu_addr
endm

macro set_ppu_scroll _horizontal, _vertical
    ; Set PPU scroll.

    lda #_horizontal
    sta ppu_scroll
    if (_horizontal) != (_vertical)
        lda #_vertical
    endif
    sta ppu_scroll
endm

macro reset_ppu_address_latch
    ; Reset ppu_addr/ppu_scroll latch.

    bit ppu_status
endm

macro copy_sprite_data _address
    ; Copy sprite data from CPU to PPU.

    if <(_address) != 0
        error "invalid sprite data address"
    endif
    lda #$00
    sta oam_addr
    lda #>_address
    sta oam_dma
endm

macro wait_vblank_start
    ; Wait until next VBlank starts.

    bit ppu_status
-   bit ppu_status
    bpl -
endm

macro copy_array _source, _target, _length
    ; Copy _length (0=256) bytes from _source to _target.

    ldx #_length
-   lda (_source) - 1, x
    sta (_target) - 1, x
    dex
    bne -
endm

macro copy_array_to_vram _address, _length
    ; Copy _length bytes starting from _address to VRAM.

    ldx #0
-   lda _address, x
    sta ppu_data
    inx
    cpx #_length
    bne -
endm

macro add _operand
    clc
    adc _operand
endm

macro sub _operand
    sec
    sbc _operand
endm

