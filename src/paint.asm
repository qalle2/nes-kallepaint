; Kalle Paint (NES, ASM6f) - main program

    ; value to fill unused areas with
    fillvalue $ff

    include "../../nes-util/nes.asm"  ; see readme
    include "const.asm"

; --- iNES header ----------------------------------------------------------------------------------

    inesprg 1  ; PRG ROM size: 1 * 16 KiB
    ineschr 1  ; CHR ROM size: 1 * 8 KiB
    inesmir 0  ; name table mirroring: horizontal
    inesmap 0  ; mapper: NROM

; --- PRG ROM --------------------------------------------------------------------------------------

    org $c000  ; last 16 KiB of PRG ROM
    pad $f800  ; last  2 KiB of PRG ROM
    include "init.asm"
    include "mainloop.asm"
    include "nmi.asm"
code_end

    pad $fffa
    dw nmi_routine, reset, $ffff  ; interrupt vectors (at the end of PRG ROM)

; --- CHR ROM --------------------------------------------------------------------------------------

    pad $10000
    incbin "../background.bin", $0000, $1000  ; 256 tiles (4 KiB)
    incbin "../sprites.bin", $0000, $1000     ; 256 tiles (4 KiB)

