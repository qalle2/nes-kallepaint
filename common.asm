; Constants and macros used by many programs.

; --- Constants ------------------------------------------------------------------------------------

; addresses

ppu_ctrl   equ $2000
ppu_mask   equ $2001
ppu_status equ $2002
oam_addr   equ $2003
oam_data   equ $2004
ppu_scroll equ $2005
ppu_addr   equ $2006
ppu_data   equ $2007

dmc_freq equ $4010
oam_dma  equ $4014
snd_chn  equ $4015
joypad1  equ $4016
joypad2  equ $4017

; joypad bitmasks

button_a      = %10000000
button_b      = %01000000
button_select = %00100000
button_start  = %00010000
button_up     = %00001000
button_down   = %00000100
button_left   = %00000010
button_right  = %00000001

; --- Macros ---------------------------------------------------------------------------------------

macro initialize_nes
    ; Initialize the NES.
    ; Do this at the start of the program.
    ; Afterwards, do a wait_vblank before doing any PPU operations. In between, you have about
    ; 30,000 cycles to do non-PPU-related stuff.
    ; See http://wiki.nesdev.com/w/index.php/Init_code

    sei           ; ignore IRQs
    cld           ; disable decimal mode
    ldx #$40
    stx joypad2   ; disable APU frame IRQ
    ldx #$ff
    txs           ; initialize stack pointer
    inx
    stx ppu_ctrl  ; disable NMI
    stx ppu_mask  ; disable rendering
    stx dmc_freq  ; disable DMC IRQs

    wait_vblank_start
endm

macro wait_vblank
    ; wait until in VBlank
-   bit ppu_status
    bpl -
endm

macro wait_vblank_start
    ; wait until at start of VBlank
    bit ppu_status
-   bit ppu_status
    bpl -
endm

