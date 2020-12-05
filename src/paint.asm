; Kalle Paint (NES, ASM6) - main program

    include "../../nes-util/nes.asm"  ; see readme
    include "const.asm"

; --- iNES header ----------------------------------------------------------------------------------

    ; https://wiki.nesdev.com/w/index.php/INES

    base 0
    db "NES", $1a            ; file id
    db 1, 1                  ; 16 KiB PRG ROM, 8 KiB CHR ROM
    db %00000000, %00000000  ; NROM mapper, horizontal mirroring
    pad $0010, 0             ; unused

; --- PRG ROM --------------------------------------------------------------------------------------

    ; only use last 2 KiB of CPU address space
    base $c000
    pad $f800, $ff

    include "init.asm"
    include "mainloop.asm"
    include "nmi.asm"

    ; interrupt vectors
    pad $fffa, $ff
    dw nmi_routine, reset, $ffff
    pad $10000, $ff

; --- CHR ROM --------------------------------------------------------------------------------------

    base 0
    incbin "../background.bin"  ; 256 tiles (4 KiB)
    pad $1000, $ff
    incbin "../sprites.bin"     ; 256 tiles (4 KiB)
    pad $2000, $ff

