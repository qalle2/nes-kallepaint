; Kalle Paint a.k.a. Qalle Paint (NES, ASM6)

; --- Constants ---------------------------------------------------------------

; Notes:
; - ppu_buf_*: PPU memory buffer: what to update in PPU memory on next VBlank.
; - 2-byte addresses: less significant byte first.
; - Boolean variables: $00-$7f = false, $80-$ff = true.

; RAM
user_pal        equ $00    ; user palette (16 bytes; offsets 4/8/12 unused)
ppu_buf_addrhi  equ $10    ; PPU buffer - high bytes of addresses (6 bytes)
ppu_buf_addrlo  equ $16    ; PPU buffer - low  bytes of addresses (6 bytes)
ppu_buf_values  equ $1c    ; PPU buffer - values                  (6 bytes)
vram_offset     equ $22    ; offset to NT0 & vram_copy (2 bytes, 0-$3ff)
vram_copy_addr  equ $24    ; address within  vram_copy (2 bytes)
program_mode    equ $26    ; program mode (see below)
run_main_loop   equ $27    ; run main loop? (boolean)
pad_status      equ $28    ; joypad status
prev_pad_status equ $29    ; joypad status on previous frame
ppu_buf_len     equ $2a    ; VRAM buffer length (0-6)
delay_left      equ $2b    ; cursor move delay left (paint mode)
brush_size      equ $2c    ; cursor type (paint mode; 0=small, 1=large)
paint_color     equ $2d    ; paint color (paint mode; 0-3)
cursor_x        equ $2e    ; cursor X position (paint/attribute editor; 0-63)
cursor_y        equ $2f    ; cursor Y position (paint/attribute editor; 0-59)
blink_timer     equ $30    ; cursor blink timer  (attribute/palette editor)
pal_ed_crsr_pos equ $31    ; cursor position     (palette editor; 0-3)
pal_ed_subpal   equ $32    ; selected subpalette (palette editor; 0-3)
vram_copy       equ $0200  ; copy of name & attribute table 0 ($400 bytes)
sprite_data     equ $0600  ; OAM page ($100 bytes)

; memory-mapped registers
; see https://wiki.nesdev.org/w/index.php/PPU_registers
ppu_ctrl        equ $2000
ppu_mask        equ $2001
ppu_status      equ $2002
oam_addr        equ $2003
ppu_scroll      equ $2005
ppu_addr        equ $2006
ppu_data        equ $2007
dmc_freq        equ $4010
oam_dma         equ $4014
snd_chn         equ $4015
joypad1         equ $4016
joypad2         equ $4017

; program modes
mode_paint      equ 0  ; paint mode
mode_attr_ed    equ 1  ; attribute editor
mode_pal_ed     equ 2  ; palette editor

; user interface colors
color_bg        equ $0f  ; background   (black)
color_fg1       equ $28  ; foreground 1 (yellow) ("Pal X" text only)
color_fg2       equ $30  ; foreground 2 (white)

; --- iNES header -------------------------------------------------------------

                ; see https://wiki.nesdev.org/w/index.php/INES
                base $0000
                db "NES", $1a            ; file id
                db 1, 1                  ; 16 KiB PRG ROM, 8 KiB CHR ROM
                db %00000000, %00000000  ; NROM mapper; any NT mirroring
                pad $0010, $00           ; unused

; --- Initialization ----------------------------------------------------------

                base $c000              ; last 16 KiB of CPU address space

reset           ; initialize the NES
                ; see https://wiki.nesdev.org/w/index.php/Init_code
                sei                     ; ignore IRQs
                cld                     ; disable decimal mode
                ldx #%01000000
                stx joypad2             ; disable APU frame IRQ
                ldx #$ff
                txs                     ; initialize stack pointer
                inx
                stx ppu_ctrl            ; disable NMI
                stx ppu_mask            ; disable rendering
                stx dmc_freq            ; disable DMC IRQs
                stx snd_chn             ; disable sound channels

                jsr wait_vbl_start      ; wait until next VBlank starts
                jsr init_ram            ; initialize main RAM

                jsr wait_vbl_start      ; wait until next VBlank starts
                jsr init_ppu_mem        ; initialize PPU memory

                jsr wait_vbl_start      ; wait until next VBlank starts
                jsr set_ppu_regs        ; set ppu_scroll/ppu_ctrl/ppu_mask
                jmp main_loop           ; start main loop

wait_vbl_start  bit ppu_status          ; wait until next VBlank starts
-               bit ppu_status
                bpl -
                rts

init_ram        ; initialize main RAM

                lda #$00                ; clear zero page
                tax
-               sta $00,x
                inx
                bne -

                lda #<vram_copy         ; clear vram_copy
                sta vram_offset+0
                lda #>vram_copy
                sta vram_offset+1
                lda #$00
                tay
                ldx #4
                ;
-               sta (vram_offset),y
                iny
                bne -
                inc vram_offset+1
                dex
                bne -

                ldx #(16-1)             ; copy initial user palette
-               lda initial_pal,x
                sta user_pal,x
                dex
                bpl -

                ldx #(21*4-1)           ; copy initial sprite data
-               lda initial_spr_dat,x
                sta sprite_data,x
                dex
                bpl -

                ldx #(1*4)              ; hide sprites except paint cursor (#0)
                ldy #63
                jsr hide_sprites        ; X = first byte index, Y = count

                lda #mode_paint         ; set misc vars
                sta program_mode
                lda #32
                sta cursor_x
                lda #28
                sta cursor_y
                lda #1
                sta paint_color

                jmp pm_upd_crsr_pos     ; update cursor position; ends with RTS

init_ppu_mem    ; initialize PPU memory

                ; copy initial palette (while still in VBlank)

                ldy #$3f
                lda #$00
                jsr set_ppu_addr        ; Y*$100+A -> address

                tax
-               lda initial_pal,x
                sta ppu_data
                inx
                cpx #32
                bne -

                ; clear name & attribute table 0

                ldy #$20
                lda #$00
                jsr set_ppu_addr        ; Y*$100+A -> address

                ldy #4
                tax
-               sta ppu_data
                inx
                bne -
                dey
                bne -

                rts

initial_pal     ; initial palette

                ; background (default user palette; changes during runtime)
                db color_bg, $15, $25, $35  ; reds
                db color_bg, $18, $28, $38  ; yellows
                db color_bg, $1b, $2b, $3b  ; greens
                db color_bg, $12, $22, $32  ; blues

                ; sprites (* = changes during runtime)

                db color_bg
                db $00                  ; unused
                db $15                  ; paint cursor *
                db color_bg             ; blinking cursors *

                db color_bg
                db color_bg             ; palette editor - background
                db color_fg1            ; palette editor - text 1
                db color_fg2            ; palette editor - text 2

                db color_bg
                db color_bg             ; palette editor - background
                db color_bg             ; palette editor - selected color #0 *
                db $15                  ; palette editor - selected color #1 *

                db color_bg
                db color_bg             ; palette editor - background
                db $25                  ; palette editor - selected color #2 *
                db $35                  ; palette editor - selected color #3 *

initial_spr_dat ; initial sprite data (Y, tile, attributes, X for each sprite)

                ; paint mode
                db $ff, $10, %00000000, 0  ; #0: cursor

                ; attribute editor
                db $ff, $12, %00000000, 0  ; #1: cursor top    left
                db $ff, $12, %01000000, 0  ; #2: cursor top    right
                db $ff, $12, %10000000, 0  ; #3: cursor bottom left
                db $ff, $12, %11000000, 0  ; #4: cursor bottom right

                ; palette editor
                db    $ff, $13,         %00, 28*8  ; #5:  cursor
                db 23*8-1, $14,         %01, 28*8  ; #6:  "Pal" - left
                db 23*8-1, $15,         %01, 29*8  ; #7:  "Pal" - right
                db 23*8-1, $16,         %01, 30*8  ; #8:  subpalette number
                db 24*8-1, $1a,         %10, 28*8  ; #9:  color 0 - square
                db 25*8-1, $1b,         %10, 28*8  ; #10: color 1 - square
                db 26*8-1, $1a,         %11, 28*8  ; #11: color 2 - square
                db 27*8-1, $1b,         %11, 28*8  ; #12: color 3 - square
                db 24*8-1, color_bg/16, %01, 29*8  ; #13: color 0 - 16s
                db 24*8-1, color_bg&15, %01, 30*8  ; #14: color 0 - 1s
                db 25*8-1, $01,         %01, 29*8  ; #15: color 1 - 16s
                db 25*8-1, $05,         %01, 30*8  ; #16: color 1 - 1s
                db 26*8-1, $02,         %01, 29*8  ; #17: color 2 - 16s
                db 26*8-1, $05,         %01, 30*8  ; #18: color 2 - 1s
                db 27*8-1, $03,         %01, 29*8  ; #19: color 3 - 16s
                db 27*8-1, $05,         %01, 30*8  ; #20: color 3 - 1s

; --- Main loop - common ------------------------------------------------------

main_loop       bit run_main_loop       ; wait until NMI routine has run
                bpl main_loop

                lsr run_main_loop       ; clear flag

                lda pad_status          ; store previous joypad status
                sta prev_pad_status
                jsr read_joypad         ; read joypad

                jsr upd_blink_color     ; update color of blinking cursor
                inc blink_timer         ; advance timer

                jsr jump_engine         ; run code for this program mode
                jmp main_loop

read_joypad     ; read 1st joypad or Famicom expansion port controller
                ; see https://www.nesdev.org/wiki/Controller_reading_code
                ; bits: A, B, select, start, up, down, left, right

                lda #1
                sta joypad1
                sta pad_status
                lsr a
                sta joypad1

-               lda joypad1
                and #%00000011
                cmp #1
                rol pad_status
                bcc -
                rts

upd_blink_color ; tell NMI routine to update color of blinking cursor
                ldx #color_bg
                lda blink_timer
                and #(1<<4)
                beq +
                ldx #color_fg2
+               txa
                ldy #(4*4+3)
                jmp to_ppu_buf_pal      ; A to PPU $3f00 + Y; ends with RTS

jump_engine     ; jump to one sub depending on program mode
                ; note: RTS in the subs below will act like RTS in this sub
                ; see https://www.nesdev.org/wiki/Jump_table
                ; and https://www.nesdev.org/wiki/RTS_Trick

                ; push target address minus one, high byte first
                ldx program_mode
                lda jump_table_hi,x
                pha
                lda jump_table_lo,x
                pha

                ; pull address, low byte first; jump to address plus one
                rts

                ; jump table - high/low bytes
jump_table_hi   dh paint_mode-1, attr_editor-1, palette_editor-1
jump_table_lo   dl paint_mode-1, attr_editor-1, palette_editor-1

; --- Main loop - paint mode (label prefix "pm_") -----------------------------

paint_mode      ; if select/B/start pressed on previous frame, ignore them all
                lda prev_pad_status
                and #%01110000
                bne +

                ; if B/select/start pressed, react to it and exit
                lda pad_status
                asl a
                bmi pm_inc_color        ; B button
                asl a
                bmi to_attr_editor      ; select
                asl a
                bmi toggle_brush        ; start

                ; note: we want to be able to accept a horizontal arrow,
                ; a vertical arrow and button A simultaneously

+               jsr pm_arrows           ; d-pad arrow logic
                bit pad_status          ; paint if button A pressed
                bpl +
                jmp do_paint            ; ends with RTS
+               rts                     ; return to main loop

pm_inc_color    ; increment paint color (0 -> 1 -> 2 -> 3 -> 0)
                ldx paint_color
                inx
                txa
                and #%00000011
                sta paint_color
                jmp pm_upd_crsr_col     ; update cursor color; ends with RTS

to_attr_editor  ; switch to attribute editor

                lda #$ff                ; hide paint cursor
                sta sprite_data+0+0

                lda #%00111100          ; make cursor coordinates
                and cursor_x            ; a multiple of 4
                sta cursor_x
                lda #%00111100
                and cursor_y
                sta cursor_y

                jsr ae_upd_cursor       ; update cursor

                lda #mode_attr_ed       ; change program mode
                sta program_mode
                rts

toggle_brush    ; toggle brush size

                lda brush_size
                eor #%00000001
                sta brush_size
                clc                     ; update cursor tile
                adc #$10
                sta sprite_data+0+1

                lda brush_size          ; if large brush, make coordinates even
                beq +                   ; (makes logic a lot simpler)
                lsr cursor_x
                asl cursor_x
                lsr cursor_y
                asl cursor_y

+               jmp pm_upd_crsr_pos     ; update cursor position; ends with RTS

pm_arrows       ; d-pad arrow logic

                lda pad_status
                and #%00001111
                bne +

                sta delay_left          ; none pressed: clear delay & exit
                rts
+               lda delay_left
                beq +

                dec delay_left          ; some pressed but delay > 0:
                rts                     ; decrement delay & exit

+               jsr pm_horz_arrows      ; some pressed and delay = 0:
                jsr pm_vert_arrows      ; accept input
                lda #10                 ; reinit delay
                sta delay_left
                jsr pm_upd_crsr_pos     ; update cursor position
                jmp pm_upd_crsr_col     ; update cursor color (ends with RTS)

pm_horz_arrows  ; check horizontal arrows

                lda pad_status
                lsr a
                bcs +                   ; d-pad right
                lsr a
                bcs ++                  ; d-pad left
                rts

+               lda cursor_x            ; cursor right
                sec
                adc brush_size
                jmp +++

++              lda cursor_x            ; cursor left
                clc
                sbc brush_size
+++             and #%00111111
                sta cursor_x
                rts

pm_vert_arrows  ; check vertical arrows

                lda pad_status
                lsr a
                lsr a
                lsr a
                bcs +                   ; d-pad down
                lsr a
                bcs ++                  ; d-pad up
                rts

+               lda cursor_y            ; cursor down
                sec
                adc brush_size
                cmp #60
                bne +++
                lda #0
                jmp +++

++              lda cursor_y            ; cursor up
                clc
                sbc brush_size
                bpl +++
                lda #60
                clc
                sbc brush_size

+++             sta cursor_y
                rts

pm_upd_crsr_pos ; update position of paint cursor sprite

                lda cursor_x            ; X
                asl a
                asl a
                sta sprite_data+0+3

                lda cursor_y            ; Y
                asl a
                asl a
                sec
                sbc #1
                sta sprite_data+0+0
                rts

pm_upd_crsr_col ; tell NMI routine to update color of paint cursor sprite
                ; (depends on paint_color and attribute data under cursor)

                ldx paint_color         ; color 0 is common to all subpalettes
                beq ++

                jsr get_attr_offset     ; get vram_offset for attribute byte
                jsr get_vramcopyadr     ; get vram_copy_addr from vram_offset
                jsr get_attr_bitpos     ; 0/1/2/3 -> X
                tax
                ldy #0                  ; read attribute byte
                lda (vram_copy_addr),y

                dex                     ; shift correct bit pair to pos 1-0
                bmi +
-               lsr a
                lsr a
                dex
                bpl -

+               and #%00000011          ; clear other bits
                asl a                   ; index to user palette -> X
                asl a
                ora paint_color
                tax

++              lda user_pal,x          ; cursor color
                ldy #(4*4+2)
                jmp to_ppu_buf_pal      ; A to PPU $3f00 + Y; ends with RTS

do_paint        ; edit one byte/tile in vram_copy and tell NMI routine to
                ; update it to VRAM

                jsr get_tile_offset     ; get vram_offset for name table
                jsr get_vramcopyadr     ; get vram_copy_addr from vram_offset

                lda brush_size
                beq +

                ldx paint_color         ; large brush; replace entire byte/tile
                lda solid_tiles,x
                jmp ++

+               ldy #0                  ; small brush; read tile index
                lda (vram_copy_addr),y
                jsr replace_pixel       ; replace pixel in tile index (A)

++              ldy #0                  ; update byte in vram_copy
                sta (vram_copy_addr),y
                jmp to_ppu_buf_vram     ; A -> $2000+vram_offset; ends with RTS

solid_tiles     ; tiles of solid color 0-3
                db %00000000, %01010101, %10101010, %11111111

get_tile_offset ; get VRAM offset for name table
                ; in:  cursor_y    = %00ABCDEF
                ; in:  cursor_x    = %00abcdef
                ; out: vram_offset = %000000AB %CDEabcde

                lda cursor_y            ; high byte
                lsr a
                lsr a
                lsr a
                lsr a
                sta vram_offset+1

                lda cursor_y            ; low byte
                and #%00001110
                lsr a
                lsr a
                ror a
                ror a
                ora cursor_x
                ror a
                sta vram_offset+0

                rts

replace_pixel   ; replace a pixel (bit pair) in a tile index (A)
                ; Python equivalent (t = tile index, s = shift count):
                ;   s = 6 - cursor_y * 4 - cursor_x * 2
                ;   t &= ~(0b11 << s)
                ;   t |= paint_color << s

                pha                     ; store tile index

                ; AND mask index (%000000YX) -> X register
                lda cursor_x
                lsr a
                lda cursor_y
                rol a
                and #%00000011
                tax

                ; OR mask index (%0000YXCC) -> Y register
                asl a
                asl a
                ora paint_color
                tay

                pla                     ; restore tile index
                and pixel_and_masks,x   ; clear bit pair
                ora pixel_or_masks,y    ; set   bit pair
                rts

pixel_and_masks db %00111111, %11001111, %11110011, %11111100
pixel_or_masks  db %00000000, %01000000, %10000000, %11000000
                db %00000000, %00010000, %00100000, %00110000
                db %00000000, %00000100, %00001000, %00001100
                db %00000000, %00000001, %00000010, %00000011

; --- Main loop - attribute editor (label prefix "ae_") -----------------------

attr_editor     ; if any button pressed on previous frame, ignore all
                lda prev_pad_status
                bne +

                lda pad_status          ; react to buttons
                bmi ae_change_pal       ; A button
                asl a
                bmi ae_change_pal       ; B button
                asl a
                bmi to_pal_editor       ; select
                asl a
                asl a
                bmi ae_cursor_up
                asl a
                bmi ae_cursor_down
                asl a
                bmi ae_cursor_left
                bne ae_cursor_right
+               rts

to_pal_editor   ; switch to palette editor

                ldx #(1*4)              ; hide attribute editor sprites (#1-#4)
                ldy #4
                jsr hide_sprites        ; X = first byte index, Y = count

-               lda initial_spr_dat,x   ; show palette editor sprites (#5-#20)
                sta sprite_data,x
                inx
                inx
                inx
                inx
                cpx #(21*4)
                bne -

                lda #mode_pal_ed        ; change program mode
                sta program_mode

                jmp pe_upd_crsr_spr     ; update cursor sprite; ends with RTS

ae_change_pal   ; decrement/increment attribute block subpalette (bit pair)

                jsr get_attr_offset     ; get vram_offset for attribute byte
                jsr get_vramcopyadr     ; get vram_copy_addr from vram_offset
                jsr get_attr_bitpos     ; 0/1/2/3 -> X
                tax
                ldy #0
                lda (vram_copy_addr),y  ; attribute byte to modify -> A

                ; add 4 to X if (LSB of bit pair set) XNOR (A pressed)
                and bitpair_masks,x     ; LSB of bit pair -> carry -> MSB of A
                cmp #1
                ror a
                eor pad_status          ; XOR with pad_status MSB (button A)
                bmi +                   ; increment index if both/neither set
                inx
                inx
                inx
                inx

+               lda bitpair_masks,x     ; flip LSB only or MSB too
                eor (vram_copy_addr),y
                sta (vram_copy_addr),y
                jmp to_ppu_buf_vram     ; A -> $2000 + vram_offset; ends w/ RTS

bitpair_masks   ; AND/XOR masks for changing bit pairs
                db %00000001, %00000100, %00010000, %01000000  ; LSB
                db %00000011, %00001100, %00110000, %11000000  ; LSB & MSB

ae_cursor_up    ; cursor up
                lda cursor_y
                sec
                sbc #4
                bpl +
                lda #(60-4)
                jmp +

ae_cursor_down  ; cursor down
                lda cursor_y
                clc
                adc #4
                cmp #60
                bne +
                lda #0
+               sta cursor_y
                jmp ae_upd_cursor       ; update cursor

ae_cursor_left  ; cursor left
                lda cursor_x
                sec
                sbc #4
                jmp +

ae_cursor_right ; cursor right
                lda cursor_x
                clc
                adc #4
+               and #%00111111
                sta cursor_x
                ; fall through

ae_upd_cursor   ; update attribute editor cursor

                lda cursor_x            ; X position
                asl a
                asl a
                sta sprite_data+1*4+3
                sta sprite_data+3*4+3
                clc
                adc #8
                sta sprite_data+2*4+3
                sta sprite_data+4*4+3

                lda cursor_y            ; Y position
                asl a
                asl a
                clc
                adc #(8-1)
                sta sprite_data+3*4+0
                sta sprite_data+4*4+0
                sec
                sbc #8
                sta sprite_data+1*4+0
                sta sprite_data+2*4+0
                rts

; --- Subs used in both paint mode and attribute editor -----------------------

get_attr_offset ; get VRAM offset for attribute byte
                ; in:  cursor_y    = %00ABCDEF
                ; in:  cursor_x    = %00abcdef
                ; out: vram_offset = $3c0 + %00ABCabc = %00000011 %11ABCabc

                ; high byte
                lda #%00000011
                sta vram_offset+1

                ; low byte

                lda cursor_x
                lsr a
                lsr a
                lsr a
                tax                     ; %00000abc

                lda cursor_y
                and #%00111000          ; %00ABC000
                ora attr_offset_tbl,x
                sta vram_offset+0
                rts

attr_offset_tbl db %11000000, %11000001, %11000010, %11000011
                db %11000100, %11000101, %11000110, %11000111

get_vramcopyadr ; get address within vram_copy
                ; vram_copy + vram_offset -> vram_copy_addr

                clc
                lda #<vram_copy
                adc vram_offset+0
                sta vram_copy_addr+0

                lda #>vram_copy
                adc vram_offset+1
                sta vram_copy_addr+1
                rts

get_attr_bitpos ; get position within attribute byte
                ; in:  cursor_y = %00ABCDEF
                ; in:  cursor_x = %00abcdef
                ; out: A        = %000000Dd

                lda cursor_y
                and #%00000100
                lsr a
                lsr a
                pha                     ; %0000000D

                lda cursor_x
                and #%00000100          ; %00000d00
                cmp #%00000100          ; %d -> carry
                pla
                rol a
                rts

; --- Main loop - palette editor (label prefix "pe_") -------------------------

palette_editor  ; if any button pressed on previous frame, ignore all
                lda prev_pad_status
                bne +

                lda pad_status          ; react to buttons
                bmi pe_inc_16s          ; A button
                asl a
                bmi pe_dec_16s          ; B button
                asl a
                bmi to_paint_mode       ; select
                asl a
                bmi pe_inc_subpal       ; start
                asl a
                bmi pe_cursor_up
                asl a
                bmi pe_cursor_down
                asl a
                bmi pe_dec_ones
                bne pe_inc_ones
+               rts

pe_inc_16s      ; increment sixteens of color at cursor
                jsr get_usrpal_offs     ; offset -> A
                tax
                lda user_pal,x
                clc
                adc #$10
                jmp +

pe_dec_16s      ; decrement sixteens of color at cursor

                jsr get_usrpal_offs     ; offset -> A
                tax
                lda user_pal,x
                sec
                sbc #$10
+               and #%00111111
                sta user_pal,x

                jsr pe_upd_col_dgts     ; update color digits
                jmp pe_upd_palette      ; update palette; ends with RTS

to_paint_mode   ; switch to paint mode

                ldx #(5*4)              ; hide palette editor sprites (#5-#20)
                ldy #16
                jsr hide_sprites        ; X = first byte index, Y = count

                jsr pm_upd_crsr_pos     ; update cursor position
                jsr pm_upd_crsr_col     ; update cursor color

                lda #mode_paint
                sta program_mode
                rts                     ; return to main loop

pe_inc_subpal   ; increment selected subpalette (0 -> 1 -> 2 -> 3 -> 0)

                ldx pal_ed_subpal
                inx
                txa
                and #%00000011
                sta pal_ed_subpal

                clc                     ; update tile of selected subpalette
                adc #$16
                sta sprite_data+8*4+1
                jsr pe_upd_col_dgts     ; update color digits
                jmp pe_upd_palette      ; update palette; ends with RTS

pe_cursor_up    ; move cursor up
                ldx pal_ed_crsr_pos
                dex
                jmp +

pe_cursor_down  ; move cursor down
                ldx pal_ed_crsr_pos
                inx
+               txa
                and #%00000011
                sta pal_ed_crsr_pos
                bpl pe_upd_crsr_spr     ; update sprite; ends with RTS

pe_dec_ones     ; decrement ones of color at cursor

                jsr get_usrpal_offs     ; offset -> X
                tax
                lda user_pal,x          ; decremented color -> A
                sec
                sbc #1
                jmp +

pe_inc_ones     ; increment ones of color at cursor

                jsr get_usrpal_offs     ; offset -> X
                tax
                lda user_pal,x          ; incremented color -> A
                clc
                adc #1

+               and #%00001111          ; push decremented/incremented ones
                pha

                lda user_pal,x          ; original sixteens -> Y
                lsr a
                lsr a
                lsr a
                lsr a
                tay

                pla                     ; pull decremented/incremented ones
                ora pe_or_masks,y       ; restore original sixteens
                sta user_pal,x

                jsr pe_upd_col_dgts     ; update color digits
                jmp pe_upd_palette      ; update palette; ends with RTS

pe_or_masks     db 0<<4, 1<<4, 2<<4, 3<<4  ; sixteens of color numbers

pe_upd_crsr_spr ; update palette editor cursor sprite
                lda pal_ed_crsr_pos     ; Y position
                asl a
                asl a
                asl a
                clc
                adc #(24*8-1)
                sta sprite_data+5*4+0
                rts

get_usrpal_offs ; offset to user palette (user_pal or VRAM $3f00-$3f0f) -> A
                ; if color 0 of any subpalette, then 0,
                ; else subpalette * 4 + cursor position

                lda pal_ed_crsr_pos
                beq +

                lda pal_ed_subpal
                asl a
                asl a
                ora pal_ed_crsr_pos
+               rts

pe_upd_col_dgts ; update tiles of all 8 color digit sprites (sprites 13-20)
                ; Python equivalent (n = which number, s = source index):
                ;   for n in range(4):
                ;     s = 0 if n == 0 else pal_ed_subpal * 4 + n
                ;     sprite_data[(13+n*2  )*4+1] = user_pal[s] // 16
                ;     sprite_data[(13+n*2+1)*4+1] = user_pal[s] %  16

                ; X = source index (user_pal), Y = dst index (sprite_data)

                ; sixteens and ones of color 0
                ldx #0
                ldy #(13*4)
                jsr pe_upd_numtiles     ; X/Y = source/dst index

                ; sixteens and ones of colors 1-3

                lda pal_ed_subpal
                asl a
                asl a
                tax

-               inx
                tya
                clc
                adc #(2*4)
                tay
                jsr pe_upd_numtiles     ; X/Y = source/dst index
                txa
                and #%00000011
                cmp #%00000011
                bne -
                rts

pe_upd_numtiles ; update tiles of 2 number sprites (sixteens and ones)
                ; in: X = source index (user_pal), Y = dst index (sprite_data)
                ; Python equivalent:
                ;   sprite_data[Y+1]   = user_pal[X] // 16
                ;   sprite_data[Y+4+1] = user_pal[X] %  16

                lda user_pal,x          ; sixteens tile
                lsr a
                lsr a
                lsr a
                lsr a
                sta sprite_data+1,y

                lda user_pal,x          ; ones tile
                and #%00001111
                sta sprite_data+4+1,y
                rts

pe_upd_palette  ; tell NMI routine to update 5 colors

                ; selected color -> BG palette
                jsr get_usrpal_offs     ; offset -> A
                tay
                lda user_pal,y
                jsr to_ppu_buf_pal      ; A to PPU $3f00 + Y

                ; color 0 of all subpalettes to sprite subpalette 2, color 2
                lda user_pal+0
                ldy #(6*4+2)
                jsr to_ppu_buf_pal      ; A to PPU $3f00 + Y

                ; subpalette offset in user palette -> A
                lda pal_ed_subpal
                asl a
                asl a

                ; color 1 of selected subpalette to sprite subpal 2, color 3
                tax
                pha
                lda user_pal+1,x
                ldy #(6*4+3)
                jsr to_ppu_buf_pal      ; A to PPU $3f00 + Y; trashes X

                ; color 2 of selected subpalette to sprite subpal 3, color 2
                pla
                tax
                pha
                lda user_pal+2,x
                ldy #(7*4+2)
                jsr to_ppu_buf_pal      ; A to PPU $3f00 + Y; trashes X

                ; color 3 of selected subpalette to sprite subpal 3, color 3
                pla
                tax
                lda user_pal+3,x
                ldy #(7*4+3)
                jsr to_ppu_buf_pal      ; A to PPU $3f00 + Y
                rts

; --- Subs used in many places ------------------------------------------------

hide_sprites    ; hide some sprites
                ; in: X = first index on sprite page, Y = count
                lda #$ff
-               sta sprite_data,x
                inx
                inx
                inx
                inx
                dey
                bne -
                rts

to_ppu_buf_pal  ; tell NMI routine to write A to PPU $3f00 + Y

                ldx ppu_buf_len
                sta ppu_buf_values,x
                lda #$3f
                sta ppu_buf_addrhi,x
                sty ppu_buf_addrlo,x

                inc ppu_buf_len
                rts

to_ppu_buf_vram ; tell NMI routine to write A to VRAM $2000 + vram_offset

                ldx ppu_buf_len
                sta ppu_buf_values,x
                lda #$20
                ora vram_offset+1
                sta ppu_buf_addrhi,x
                lda vram_offset+0
                sta ppu_buf_addrlo,x

                inc ppu_buf_len
                rts

; --- Interrupt routines ------------------------------------------------------

nmi             pha                     ; push A, X, Y
                txa
                pha
                tya
                pha

                bit ppu_status          ; reset ppu_addr/ppu_scroll latch

                lda #$00                ; do OAM DMA
                sta oam_addr
                lda #>sprite_data
                sta oam_dma

                jsr flush_ppu_buf       ; flush PPU memory buffer
                jsr set_ppu_regs        ; set ppu_scroll/ppu_ctrl/ppu_mask

                sec                     ; set flag to let main loop run once
                ror run_main_loop

                pla                     ; pull Y, X, A
                tay
                pla
                tax
                pla

irq             rti                     ; IRQ unused

flush_ppu_buf   ; flush PPU memory buffer

                ldx #$ff                ; source index
-               inx
                cpx ppu_buf_len
                beq +
                ldy ppu_buf_addrhi,x
                lda ppu_buf_addrlo,x
                jsr set_ppu_addr        ; Y, A -> address
                lda ppu_buf_values,x
                sta ppu_data
                jmp -

+               lda #0
                sta ppu_buf_len
                rts

set_ppu_addr    ; Y*$100+A -> address
                sty ppu_addr
                sta ppu_addr
                rts

set_ppu_regs    lda #0                  ; reset PPU scroll
                sta ppu_scroll
                sta ppu_scroll
                lda #%10001000          ; NMI enabled, use PT1 for sprites
                sta ppu_ctrl
                lda #%00011110          ; show BG & sprites
                sta ppu_mask
                rts

; --- Interrupt vectors -------------------------------------------------------

                pad $fffa, $ff
                dw nmi, reset, irq      ; IRQ unused

; --- CHR ROM -----------------------------------------------------------------

                base $0000
                incbin "chr-pt0.bin"    ; background
                pad $1000, $ff
                incbin "chr-pt1.bin"    ; sprites
                pad $2000, $ff
