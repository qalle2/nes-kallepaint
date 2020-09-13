; Kalle Paint - constants

; --- Addresses ------------------------------------------------------------------------------------

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
vram_buffer_pos    equ $10    ; offset of last written byte in vram_buffer (main loop)
user_palette       equ $11    ; 16 bytes (each $00-$3f; bytes 4/8/12 are unused)
vram_buffer        equ $21    ; to end of zero page (what to update in VRAM on next VBlank; format:
                              ; addr hi (0=terminator), addr lo, byte, ...)
sprite_data        equ $0200  ; $100 bytes (see initial_sprite_data for layout)
nt_at_buffer       equ $0300  ; $400 bytes (copy of name/attribute table 0; must be at $xx00)

; --- Non-addresses --------------------------------------------------------------------------------

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
tile_digits   equ $00  ; hexadecimal digits "0"-"F"
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

