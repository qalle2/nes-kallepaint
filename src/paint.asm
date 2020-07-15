; Kalle Paint (NES, ASM6f)

    include "common.asm"

    ; value to fill unused areas with
    fillvalue $ff

; --------------------------------------------------------------------------------------------------
; Constants

; Note: in flag variables, only the most significant bit is meaningful ($00-$7f = false, $80-$ff =
; true).
; Note: all address variables (2 bytes) are little endian (low byte, high byte).

; zero page
user_palette           equ $00  ; 4 bytes (each $00-$3f)
paint_area_offset      equ $04  ; 2 bytes (offset to nt_buffer and ppu_paint_area)
nt_buffer_address      equ $06  ; 2 bytes (address within nt_buffer)
in_palette_editor      equ $0a  ; flag (false = in paint mode, true = in palette edit mode)
run_main_loop          equ $0b  ; flag (main loop allowed to run?)
update_paint_area_vram equ $0c  ; flag (update paint area VRAM?)
joypad_status          equ $0d  ; first joypad status (bits: A B select start up down left right)
prev_joypad_status     equ $0e  ; first joypad status on previous frame
paint_move_delay_left  equ $0f  ; cursor move delay left (paint mode)
paint_cursor_type      equ $10  ; cursor type (paint mode; 0=small, 1=big)
paint_cursor_x         equ $11  ; cursor X position (paint mode; 0-63)
paint_cursor_y         equ $12  ; cursor Y position (paint mode; 0-47)
paint_color            equ $13  ; selected color (paint mode; 0-3)
palette_cursor         equ $14  ; cursor position (palette edit mode; 0-3)
cursor_blink_timer     equ $15  ; cursor blink timer (palette edit mode)
temp                   equ $16  ; temporary

; other RAM
sprite_data equ $0200  ; $100 bytes (first paint mode sprites, then palette editor sprites)
nt_buffer   equ $0300  ; $380 = 28*32 bytes (copy of name table data of paint area)

; VRAM
ppu_paint_area equ $2020  ; $380 = 28*32 bytes

; some NES colors
black equ $0f
white equ $30
red   equ $16
green equ $1a
blue  equ $02
pink  equ $24

; default user palette
default_color0 equ white
default_color1 equ red
default_color2 equ green
default_color3 equ blue

; palette editor colors (background, foreground)
editor_bg_color equ black
editor_fg_color equ white

; palette editor cursor blink rate
edit_crsr_blink_rate equ 4  ; 0 (fastest) to 7 (slowest)

; paint cursor move repeat delay
cursor_move_delay equ 10  ; frames

; --- iNES header ----------------------------------------------------------------------------------

    inesprg 1  ; PRG ROM size: 1 * 16 KiB
    ineschr 1  ; CHR ROM size: 1 * 8 KiB
    inesmir 0  ; name table mirroring: horizontal
    inesmap 0  ; mapper: NROM

; --- PRG ROM --------------------------------------------------------------------------------------

    org $c000               ; last 16 KiB of PRG ROM (iNES format limitations)
    pad $fc00               ; last 1 KiB of PRG ROM
    include "init.asm"
    include "mainloop.asm"
    include "nmi.asm"
    pad $fffa
    dw nmi, reset, $ffff    ; interrupt vectors (at the end of PRG ROM)

; --- CHR ROM --------------------------------------------------------------------------------------

    pad $10000
    incbin "../background.bin", $0000, $1000  ; 256 tiles (4 KiB)
    incbin "../sprites.bin", $0000, $1000     ; 256 tiles (4 KiB)

