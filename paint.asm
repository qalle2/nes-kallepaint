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
paint_area_offset      equ $04  ; 2 bytes (offset to nt_buffer and paint area in VRAM; $000-$2ff)
nt_buffer_address      equ $06  ; 2 bytes (nt_buffer...nt_buffer+$2ff)
paint_vram_address     equ $08  ; 2 bytes (ppu_paint_area_start...ppu_paint_area_start+$2ff)
in_palette_editor      equ $0a  ; flag (in palette edit mode instead of paint mode?)
execute_main_loop      equ $0b  ; flag (allow main loop to run once?)
update_paint_area_vram equ $0c  ; flag (update paint area VRAM?)
joypad_status          equ $0d  ; first joypad status (bits: A, B, select, start, up, down, left, right)
prev_joypad_status     equ $0e  ; first joypad status on previous frame
paint_move_delay_left  equ $0f  ; cursor move delay left (paint mode)
paint_cursor_type      equ $10  ; cursor type (paint mode; 0=small, 1=big)
paint_cursor_x         equ $11  ; cursor X position (paint mode; 0-63)
paint_cursor_y         equ $12  ; cursor Y position (paint mode; 0-47)
paint_color            equ $13  ; selected color (paint mode; 0-3)
palette_cursor         equ $14  ; cursor position (palette edit mode; 0-3)
temp                   equ $15  ; temporary

; other RAM
sprite_data equ $0200  ; 256 bytes (first 9 paint mode sprites, then 13 palette editor sprites)
nt_buffer   equ $0300  ; 800 = $320 = 32*25 bytes (copy of name table data of paint area)

; PPU
ppu_paint_area_start equ $2080  ; 800 = $320 = 32*25 bytes

; colors
black  equ $0f
gray   equ $00
white  equ $30
red    equ $16
yellow equ $28
green  equ $1a
blue   equ $02
lblue  equ $12

; misc
paint_mode_sprite_count     equ 10
palette_editor_sprite_count equ 13
cursor_move_delay           equ 10

; --- iNES header ----------------------------------------------------------------------------------

    inesprg 1  ; PRG ROM size: 1 * 16 KiB
    ineschr 0  ; CHR ROM size: 0 * 8 KiB (uses CHR RAM)
    inesmir 0  ; name table mirroring: horizontal
    inesmap 0  ; mapper: NROM

; --- Main parts -----------------------------------------------------------------------------------

    org $c000
    include "paint-init.asm"
    include "paint-mainloop.asm"
    include "paint-nmi.asm"

; --- Subs/tables used by more than one part -------------------------------------------------------

solid_color_tiles:
    ; tiles of solid color 0/1/2/3
    hex 00 55 aa ff

; --- Interrupt vectors ----------------------------------------------------------------------------

    pad $fffa
    dw nmi, reset, $ffff

