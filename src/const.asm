; Kalle Paint - constants

; --- Addresses ------------------------------------------------------------------------------------

; memory-mapped registers
ppu_ctrl   equ $2000
ppu_mask   equ $2001
ppu_status equ $2002
oam_addr   equ $2003
oam_data   equ $2004
ppu_scroll equ $2005
ppu_addr   equ $2006
ppu_data   equ $2007
dmc_freq   equ $4010
oam_dma    equ $4014
snd_chn    equ $4015
joypad1    equ $4016
joypad2    equ $4017

; Note: flag variables: $00-$7f = false, $80-$ff = true.
; Note: all address variables (2 bytes) are little endian (low byte, high byte).

; RAM
user_palette       equ $00    ; 4 bytes (each $00-$3f)
nt_offset          equ $04    ; 2 bytes (offset to name table 0 and nt_buffer)
nt_buffer_address  equ $06    ; 2 bytes (address within nt_buffer)
in_palette_editor  equ $0a    ; flag (false = in paint mode, true = in palette edit mode)
run_main_loop      equ $0b    ; flag (main loop allowed to run?)
update_nt          equ $0c    ; flag (update name table?)
joypad_status      equ $0d    ; first joypad status (bits: A B select start up down left right)
prev_joypad_status equ $0e    ; first joypad status on previous frame
delay_left         equ $0f    ; cursor move delay left (paint mode)
paint_cursor_type  equ $10    ; cursor type (paint mode; 0=small, 1=big)
paint_cursor_x     equ $11    ; cursor X position (paint mode; 0-63)
paint_cursor_y     equ $12    ; cursor Y position (paint mode; 0-47)
paint_color        equ $13    ; selected color (paint mode; 0-3)
palette_cursor     equ $14    ; cursor position (palette edit mode; 0-3)
blink_timer        equ $15    ; cursor blink timer (palette edit mode)
temp               equ $16    ; temporary
sprite_data        equ $0200  ; $100 bytes (first paint mode sprites, then palette editor sprites)
nt_buffer          equ $0300  ; $400 bytes (copy of name table 0 and attribute table 0; must be $xx00)

; --- Non-addresses --------------------------------------------------------------------------------

; joypad bitmasks
button_a      equ $80
button_b      equ $40
button_select equ $20
button_start  equ $10
button_up     equ $08
button_down   equ $04
button_left   equ $02
button_right  equ $01

; misc
default_color0 equ $30  ; default palette - color 0 (white)
default_color1 equ $16  ; default palette - color 1 (red)
default_color2 equ $1a  ; default palette - color 2 (green)
default_color3 equ $02  ; default palette - color 3 (blue)
editor_bg      equ $0f  ; palette editor background color (black)
editor_text    equ $30  ; palette editor text color (white)
blink_rate     equ 4    ; palette editor cursor blink rate (0=fastest, 7=slowest)
delay          equ 10   ; paint cursor move repeat delay (frames)

