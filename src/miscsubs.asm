; Kalle Paint - miscellaneous subroutines

get_pos_in_attr_byte
        ; Get position within attribute byte.
        ; Used by mainloop-paint, mainloop-attr.
        ; bits: cursor_y = 00ABCDEF, cursor_x = 00abcdef -> X = 00000Dd0
        ; 0 = top left, 2 = top right, 4 = bottom left, 6 = bottom right.

        lda cursor_y
        and #%00000100  ; 00000D00
        lsr             ; 000000D0
        tax

        lda cursor_x
        and #%00000100  ; 00000d00
        cmp #%00000100  ; d -> carry
        txa
        adc #0          ; 000000Dd
        asl             ; 00000Dd0
        tax

        rts

get_vram_offset_for_at
        ; Compute vram_offset for an attribute table byte.
        ; Used by mainloop-paint, mainloop-attr.
        ; Bits: cursor_y = 00ABCDEF, cursor_x = 00abcdef
        ;       -> vram_offset = $3c0 + 00ABCabc = 00000011 11ABCabc

        lda #%00000011
        sta vram_offset + 1

        lda cursor_y
        and #%00111000       ; 00ABC000
        sta temp
        lda cursor_x
        lsr
        lsr
        lsr                  ; 00000abc
        ora temp             ; 00ABCabc
        ora #%11000000       ; 11ABCabc
        sta vram_offset + 0

        rts

get_vram_copy_addr
        ; vram_copy + vram_offset -> vram_copy_addr (vram_copy must be at $xx00)
        ; Used by mainloop-paint, mainloop-attr.

        lda vram_offset + 0
        sta vram_copy_addr + 0
        ;
        lda #>vram_copy
        clc
        adc vram_offset + 1
        sta vram_copy_addr + 1

        rts

nt_at_update_to_vram_buffer
        ; Tell NMI routine to write A to VRAM $2000 + vram_offset.
        ; Used by mainloop-paint, mainloop-attr.

        pha
        inc vram_buffer_pos
        ldx vram_buffer_pos
        ;
        lda #$20
        ora vram_offset + 1
        sta vram_buffer_addrhi, x
        lda vram_offset + 0
        sta vram_buffer_addrlo, x
        pla
        sta vram_buffer_value, x

        rts
