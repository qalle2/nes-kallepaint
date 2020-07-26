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
nt_at_offset       equ $00    ; 2 bytes (offset to name/attribute table 0 and nt_at_buffer)
nt_at_buffer_addr  equ $02    ; 2 bytes (address within nt_at_buffer)
mode               equ $04    ; 0 = paint, 1 = attribute editor, 2 = palette editor
run_main_loop      equ $05    ; flag (true = main loop allowed to run)
joypad_status      equ $06    ; first joypad status (bits: A B select start up down left right)
prev_joypad_status equ $07    ; first joypad status on previous frame
delay_left         equ $08    ; cursor move delay left (paint mode)
paint_cursor_type  equ $09    ; cursor type (paint mode; 0=small, 1=big)
cursor_x           equ $0a    ; cursor X position (paint/attribute edit mode; 0-63)
cursor_y           equ $0b    ; cursor Y position (paint/attribute edit mode; 0-55)
paint_color        equ $0c    ; selected color (paint mode; 0-3)
palette_cursor     equ $0d    ; cursor position (palette edit mode; 0-3)
palette_subpal     equ $0e    ; selected subpalette (palette edit mode; 0-3)
blink_timer        equ $0f    ; cursor blink timer (attribute/palette edit mode)
vram_buffer_pos    equ $10    ; offset of first free byte in vram_buffer (main loop)
bitop_temp         equ $11    ; temp var for bitops
user_palette       equ $12    ; 16 bytes (each $00-$3f; bytes 4/8/12 are unused)
sprite_data        equ $0200  ; $100 bytes (see initial_sprite_data for layout)
nt_at_buffer       equ $0300  ; $400 bytes (copy of name/attribute table 0; must be at $xx00)
vram_buffer        equ $0700  ; $100 bytes (what to update in VRAM on next VBlank; addr, byte,
                              ; addr, byte, ...; addr's are big endian; $00xx = end of data)

; --- Non-addresses --------------------------------------------------------------------------------

; joypad bitmasks
button_a      equ %10000000
button_b      equ %01000000
button_select equ %00100000
button_start  equ %00010000
button_up     equ %00001000
button_down   equ %00000100
button_left   equ %00000010
button_right  equ %00000001

; default user palette
defcol_bg equ $0f  ; background (all subpalettes)
defcol0a  equ $15
defcol0b  equ $25
defcol0c  equ $35
defcol1a  equ $18
defcol1b  equ $28
defcol1c  equ $38
defcol2a  equ $1b
defcol2b  equ $2b
defcol2c  equ $3b
defcol3a  equ $12
defcol3b  equ $22
defcol3c  equ $32

; sprite tile indexes
; note: hexadecimal digits must be at $00-$0f
tile_smallcur equ $10  ; cursor - small
tile_largecur equ $11  ; cursor - large
tile_attrcur  equ $12  ; cursor - corner of attribute cursor
tile_cover    equ $13  ; cover (palette editor)
tile_x        equ $14  ; "X"
tile_y        equ $15  ; "Y"
tile_p        equ $16  ; "P"
tile_colorind equ $17  ; color indicator (palette editor)

; other
editor_bg   equ $0f  ; palette editor background color / blinking cursor 1 (black)
editor_text equ $30  ; palette editor text color / blinking cursor 2 (white)
blink_rate  equ 4    ; attribute/palette editor cursor blink rate (0=fastest, 7=slowest)
delay       equ 10   ; paint cursor move repeat delay (frames)

