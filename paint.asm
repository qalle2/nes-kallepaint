; Kalle Paint (NES, ASM6)

; --- Constants -----------------------------------------------------------------------------------

; Note: "VRAM buffer" = what to update in VRAM on next VBlank.

; RAM
user_pal        equ $00    ; user palette (16 bytes; each $00-$3f; offsets 4/8/12 are unused)
vram_buf_adrhi  equ $10    ; VRAM buffer - high bytes of addresses (6 bytes)
vram_buf_adrlo  equ $16    ; VRAM buffer - low bytes of addresses (6 bytes)
vram_buf_val    equ $1c    ; VRAM buffer - values (6 bytes)
vram_offset     equ $22    ; offset to name/attr table 0 and vram_copy (2 bytes, low first; 0-$3ff)
vram_copy_addr  equ $24    ; address in vram_copy (2 bytes, low first; vram_copy...vram_copy+$3ff)
mode            equ $26    ; program mode: 0 = paint, 1 = attribute editor, 2 = palette editor
ppu_ctrl_copy   equ $27    ; copy of ppu_ctrl
run_main_loop   equ $28    ; run main loop? (flag; only MSB is important)
pad_status      equ $29    ; first joypad status (bits: A, B, select, start, up, down, left, right)
prev_pad_status equ $2a    ; first joypad status on previous frame
vram_buf_len    equ $2b    ; VRAM buffer - number of bytes (0-6)
delay_left      equ $2c    ; cursor move delay left (paint mode)
brush_size      equ $2d    ; cursor type (paint mode; 0=small, 1=big)
paint_color     equ $2e    ; paint color (paint mode; 0-3)
cursor_x        equ $2f    ; cursor X position (paint/attribute edit mode; 0-63)
cursor_y        equ $30    ; cursor Y position (paint/attribute edit mode; 0-59)
blink_timer     equ $31    ; cursor blink timer (attribute/palette editor)
pal_ed_cur_pos  equ $32    ; cursor position (palette editor; 0-3)
pal_ed_subpal   equ $33    ; selected subpalette (palette editor; 0-3)
temp            equ $34    ; temporary
vram_copy       equ $0200  ; copy of name/attribute table 0 ($400 bytes; must be at $xx00)
spr_data        equ $0600  ; sprite data ($100 bytes; see initial_spr_dat for layout)

; memory-mapped registers; see https://wiki.nesdev.org/w/index.php/PPU_registers
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

; joypad bitmasks
pad_a           equ 1<<7  ; A
pad_b           equ 1<<6  ; B
pad_sl          equ 1<<5  ; select
pad_st          equ 1<<4  ; start
pad_u           equ 1<<3  ; up
pad_d           equ 1<<2  ; down
pad_l           equ 1<<1  ; left
pad_r           equ 1<<0  ; right

; default user palette
col_def_bg      equ $0f  ; background (all subpalettes)
col_def_0a      equ $15  ; reds
col_def_0b      equ $25
col_def_0c      equ $35
col_def_1a      equ $18  ; yellows
col_def_1b      equ $28
col_def_1c      equ $38
col_def_2a      equ $1b  ; greens
col_def_2b      equ $2b
col_def_2c      equ $3b
col_def_3a      equ $12  ; blues
col_def_3b      equ $22
col_def_3c      equ $32

; user interface colors
col_paled_bg    equ $0f  ; palette editor background (black)
col_paled_text  equ $30  ; palette editor text (white)
col_blink1      equ $0f  ; blinking cursor 1 (black)
col_blink2      equ $30  ; blinking cursor 2 (white)

; misc
blink_rate      equ 4    ; attribute/palette editor cursor blink rate (0-7; 0=fastest)
brush_delay     equ 10   ; paint cursor move repeat delay (frames)

; --- iNES header ---------------------------------------------------------------------------------

                ; see https://wiki.nesdev.org/w/index.php/INES
                base $0000
                db "NES", $1a            ; file id
                db 1, 0                  ; 16 KiB PRG ROM, 0 KiB CHR ROM (uses CHR RAM)
                db %00000000, %00000000  ; NROM mapper; name table mirroring doesn't matter
                pad $0010, $00           ; unused

; --- Initialization ------------------------------------------------------------------------------

                base $c000              ; start of PRG ROM;
                pad $f800, $ff          ; only use last 2 KiB of CPU address space

reset           ; initialize the NES; see https://wiki.nesdev.org/w/index.php/Init_code
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

                lda #$00                ; clear zero page and vram_copy
                tax
-               sta $00,x
                sta vram_copy,x
                sta vram_copy+$100,x
                sta vram_copy+$200,x
                sta vram_copy+$300,x
                inx
                bne -

                ldx #(16-1)             ; init user palette
-               lda initial_pal,x
                sta user_pal,x
                dex
                bpl -

                ldx #(init_sprdat_end-initial_spr_dat-1)
-               lda initial_spr_dat,x   ; init sprite data
                sta spr_data,x
                dex
                bpl -

                ldx #(1*4)              ; hide sprites except paint cursor (#0)
                ldy #63
                jsr hide_sprites        ; X = first byte index, Y = count

                lda #30                 ; init misc vars
                sta cursor_x
                lda #28
                sta cursor_y
                inc paint_color

                jsr wait_vbl_start      ; wait until next VBlank starts

                ldy #$3f                ; init PPU palette (while still in VBlank)
                jsr set_ppu_addr_pg     ; 0 -> A; Y*$100 -> address
                tax
-               lda initial_pal,x
                sta ppu_data
                inx
                cpx #32
                bne -

                ; generate background pattern table data to PT0
                ; 256 tiles, all combinations of 2*2 subpixels and 4 colors
                ; bits of tile index: %AaBbCcDd:
                ;     %Aa/%Bb = top    left/right subpixel
                ;     %Cc/%Dd = bottom left/right subpixel
                ; to generate data:
                ;     for %ab, %cd, %AB, %CD in each tile index:
                ;         convert bit pair into byte as follows and write it 4 times:
                ;             %00->$00, %01->$0f, %10->$f0, %11->$ff
                ; example: tile %10001011 = 00000000 0f0f0f0f f0f0f0f0 ffffffff
                ;
                ldy #$00                ; PPU address $0000
                jsr set_ppu_addr_pg     ; 0 -> A; Y*$100 -> address
                tax                     ; X = tile index; Y = temporary
                ;
-               txa
                jsr wr_pt_bg_bytes      ; write 4 bytes using bits %ab
                jsr wr_pt_bg_bytes      ; write 4 bytes using bits %cd
                ;
                txa
                lsr a
                jsr wr_pt_bg_bytes      ; write 4 bytes using bits %AB
                jsr wr_pt_bg_bytes      ; write 4 bytes using bits %CD
                ;
                inx
                bne -

                ldx #0                  ; copy sprite pattern table data to PT1 (PPU address is
-               lda pt_data_spr,x       ; already correct); X = source index; Y = temporary
                ;
                pha                     ; write byte using high nybble
                lsr a
                lsr a
                lsr a
                lsr a
                tay
                lda pt_spr_bytes,y
                sta ppu_data
                ;
                pla                     ; write byte using low nybble
                and #%00001111
                tay
                lda pt_spr_bytes,y
                sta ppu_data
                ;
                inx
                cpx #(pt_data_spr_end-pt_data_spr)
                bne -

                ldy #$20                ; clear name/attribute table 0 ($400 bytes)
                jsr set_ppu_addr_pg     ; 0 -> A; Y*$100 -> address
                ;
                ldx #4
                tay
-               jsr fill_vram           ; write A to PPU Y times and clear Y
                dex
                bne -

                jsr wait_vbl_start      ; wait until next VBlank starts

                lda #%10001000          ; NMI: enabled, sprites: 8*8 px, BG PT: 0, sprite PT: 1,
                sta ppu_ctrl_copy       ; VRAM address auto-increment: 1 byte, name table: 0
                jsr set_ppu_regs        ; set ppu_scroll/ppu_ctrl/ppu_mask

                jmp main_loop

wait_vbl_start  bit ppu_status          ; wait until next VBlank starts
-               bit ppu_status
                bpl -
                rts

fill_vram       sta ppu_data            ; write A to PPU Y times and clear Y
                dey
                bne fill_vram
                rts

initial_pal     ; initial palette
                ; background (also the initial user palette)
                db col_def_bg, col_def_0a, col_def_0b, col_def_0c
                db col_def_bg, col_def_1a, col_def_1b, col_def_1c
                db col_def_bg, col_def_2a, col_def_2b, col_def_2c
                db col_def_bg, col_def_3a, col_def_3b, col_def_3c
                ; sprites
                ; 2nd color in all subpalettes: palette editor background
                ; 3rd color in all subpalettes: selected colors in palette editor
                ; 4th color in 1st subpalette : all cursors
                ; 4th color in 2nd subpalette : palette editor text
                db col_def_bg, col_paled_bg, col_def_bg, col_def_0a
                db col_def_bg, col_paled_bg, col_def_0a, col_paled_text
                db col_def_bg, col_paled_bg, col_def_0b, $00
                db col_def_bg, col_paled_bg, col_def_0c, $00

initial_spr_dat ; initial sprite data (Y, tile, attributes, X for each sprite)
                ; paint mode
                db    $ff, $10, %00000000,    0  ; #0:  cursor
                ; attribute editor
                db    $ff, $12, %00000000,    0  ; #1:  cursor top left
                db    $ff, $12, %01000000,    0  ; #2:  cursor top right
                db    $ff, $12, %10000000,    0  ; #3:  cursor bottom left
                db    $ff, $12, %11000000,    0  ; #4:  cursor bottom right
                ; palette editor
                db    $ff, $11, %00000000, 29*8  ; #5:  cursor
                db 22*8-1, $14, %00000001, 28*8  ; #6:  "P"
                db 22*8-1, $13, %00000001, 29*8  ; #7:  cover (to right of "P")
                db 22*8-1, $00, %00000001, 30*8  ; #8:  subpalette number
                db 23*8-1, $0c, %00000001, 28*8  ; #9:  "C"
                db 23*8-1, $00, %00000001, 29*8  ; #10: color number - 16s
                db 23*8-1, $00, %00000001, 30*8  ; #11: color number - ones
                db 24*8-1, $15, %00000000, 29*8  ; #12: color 0
                db 25*8-1, $15, %00000001, 29*8  ; #13: color 1
                db 26*8-1, $15, %00000010, 29*8  ; #14: color 2
                db 27*8-1, $15, %00000011, 29*8  ; #15: color 3
                db 24*8-1, $13, %00000001, 28*8  ; #16: cover (to left  of color 0)
                db 24*8-1, $13, %00000001, 30*8  ; #17: cover (to right of color 0)
                db 25*8-1, $13, %00000001, 28*8  ; #18: cover (to left  of color 1)
                db 25*8-1, $13, %00000001, 30*8  ; #19: cover (to right of color 1)
                db 26*8-1, $13, %00000001, 28*8  ; #20: cover (to left  of color 2)
                db 26*8-1, $13, %00000001, 30*8  ; #21: cover (to right of color 2)
                db 27*8-1, $13, %00000001, 28*8  ; #22: cover (to left  of color 3)
                db 27*8-1, $13, %00000001, 30*8  ; #23: cover (to right of color 3)
init_sprdat_end

wr_pt_bg_bytes  ; write 4 bytes of background pattern table data
                ; in: bits %xAxBxxxx of A = which byte to write
                ; side effects: shifts A left 4 times; trashes Y and temp; writes ppu_data 4 times
                ;
                ldy #0                  ; bits of A: xAxBxxxx -> bits of temp: 000000AB
                sty temp
                asl a
                asl a
                rol temp
                asl a
                asl a
                rol temp
                ;
                pha                     ; 4 * [$00,$0f,$f0,$ff][temp] -> PPU
                ldy temp                ; trash Y (but not A/X)
                lda pt_bg_bytes,y
                ldy #4
                jsr fill_vram           ; write A to PPU Y times and clear Y
                pla
                ;
                rts

pt_bg_bytes     hex 00 0f f0 ff

pt_data_spr     ; sprite pattern table data (note: "cXonY" means "color X on color Y")
                ; each nybble is an index to pt_spr_bytes
                hex 99999999 04333340  ; tile $00 ("0"; all digits are c3on1)
                hex 99999999 01111110  ; tile $01 ("1")
                hex 99999999 04142240  ; tile $02 ("2")
                hex 99999999 04141140  ; tile $03 ("3")
                hex 99999999 03341110  ; tile $04 ("4")
                hex 99999999 04241140  ; tile $05 ("5")
                hex 99999999 04243340  ; tile $06 ("6")
                hex 99999999 04111110  ; tile $07 ("7")
                hex 99999999 04343340  ; tile $08 ("8")
                hex 99999999 04341140  ; tile $09 ("9")
                hex 99999999 04343330  ; tile $0a ("A")
                hex 99999999 02243340  ; tile $0b ("B")
                hex 99999999 04222240  ; tile $0c ("C")
                hex 99999999 01143340  ; tile $0d ("D")
                hex 99999999 04242240  ; tile $0e ("E")
                hex 99999999 04242220  ; tile $0f ("F")
                hex 87780000 87780000  ; tile $10 (small paint cursor, c3on0)
                hex 96666669 96666669  ; tile $11 (large paint cursor, c3on0)
                hex 95555555 95555555  ; tile $12 (attribute cursor corner, c3on0)
                hex 99999999 00000000  ; tile $13 (color 1 only)
                hex 99999999 04342220  ; tile $14 ("P", c3on1)
                hex 00000009 99999990  ; tile $15 (rectangle, c2on1)
pt_data_spr_end

pt_spr_bytes    ; see pt_data_spr
                db %00000000  ; index 0
                db %00000110  ; index 1
                db %01100000  ; index 2
                db %01100110  ; index 3
                db %01111110  ; index 4
                db %10000000  ; index 5
                db %10000001  ; index 6
                db %10010000  ; index 7
                db %11110000  ; index 8
                db %11111111  ; index 9

; --- Main loop -----------------------------------------------------------------------------------

main_loop       bit run_main_loop       ; wait until NMI routine has run
                bpl main_loop

                lsr run_main_loop       ; prevent main loop from running until after next NMI
                lda pad_status          ; store previous joypad status
                sta prev_pad_status

                lda #$01                ; read first joypad or Famicom expansion port controller
                sta joypad1             ; see https://www.nesdev.org/wiki/Controller_reading_code
                sta pad_status          ; init joypads; set LSB of variable to detect end of loop
                lsr a
                sta joypad1
-               lda joypad1             ; read 8 buttons
                and #%00000011
                cmp #$01
                rol pad_status
                bcc -

                lda #$3f                ; tell NMI routine to update blinking cursor in VRAM
                sta vram_buf_adrhi+0
                lda #(4*4+3)
                sta vram_buf_adrlo+0
                ldx #col_blink1
                lda blink_timer
                and #(1<<blink_rate)
                beq +
                ldx #col_blink2
+               stx vram_buf_val+0
                lda #1
                sta vram_buf_len

                inc blink_timer         ; advance timer
                jsr jump_engine         ; run code for the program mode we're in
                jmp main_loop

jump_engine     ldx mode                ; jump engine (run one sub depending on program mode)
                lda jump_table_hi,x     ; note: don't inline this sub
                pha                     ; push target address minus one, high byte first
                lda jump_table_lo,x
                pha
                rts                     ; pull address, low byte first; jump to address plus one

jump_table_hi   dh paint_mode-1, attr_editor-1, pal_editor-1  ; jump table - high bytes
jump_table_lo   dl paint_mode-1, attr_editor-1, pal_editor-1  ; jump table - low bytes

; --- Paint mode (code label prefix "pm") ---------------------------------------------------------

paint_mode      lda prev_pad_status     ; select/B/start logic
                and #(pad_sl|pad_b|pad_st)
                bne pm_arrows           ; if any pressed on previous frame, ignore them all

                lda pad_status          ; if select pressed, switch to attribute editor
                and #pad_sl
                beq +
                lda #$ff                ; hide paint cursor sprite
                sta spr_data+0+0
                lda #%00111100          ; make cursor coordinates a multiple of four
                and cursor_x
                sta cursor_x
                lda #%00111100
                and cursor_y
                sta cursor_y
                inc mode                ; change program mode
                rts                     ; return to main loop

+               lda pad_status          ; if B pressed, increment paint color (0-3)
                and #pad_b
                beq +
                ldx paint_color
                inx
                txa
                and #%00000011
                sta paint_color

+               lda pad_status          ; if start pressed, toggle brush size
                and #pad_st
                beq pm_arrows
                lda brush_size
                eor #%00000001
                sta brush_size
                beq pm_arrows
                lsr cursor_x            ; if large brush, make coordinates even
                asl cursor_x            ; note: not allowing the cursor to span multiple tiles
                lsr cursor_y            ; makes the paint logic a lot simpler
                asl cursor_y

pm_arrows       lda pad_status          ; arrow logic
                and #(pad_u|pad_d|pad_l|pad_r)
                bne +
                sta delay_left          ; if none pressed, clear cursor move delay
                beq paint_mode2         ; unconditional; ends with RTS
+               lda delay_left          ; else if delay > 0, decrement it and exit
                beq +
                dec delay_left
                bpl paint_mode2         ; unconditional; ends with RTS

+               lda pad_status          ; check horizontal arrows
                lsr a
                bcs +
                lsr a
                bcs ++
                bcc pm_check_vert       ; unconditional
+               lda cursor_x            ; right
                sec
                adc brush_size
                bpl +++                 ; unconditional
++              lda cursor_x            ; left
                clc
                sbc brush_size
+++             and #%00111111          ; store horizontal position
                sta cursor_x

pm_check_vert   lda pad_status          ; check vertical arrows
                lsr a
                lsr a
                lsr a
                bcs +
                lsr a
                bcs ++
                bcc pm_arrow_end        ; unconditional
+               lda cursor_y            ; down
                sec
                adc brush_size
                cmp #60
                bne +++
                lda #0
                beq +++                 ; unconditional
++              lda cursor_y            ; up
                clc
                sbc brush_size
                bpl +++
                lda #60
                clc
                sbc brush_size
+++             sta cursor_y            ; store vertical position

pm_arrow_end    lda #brush_delay        ; reinit cursor move delay
                sta delay_left

paint_mode2     ; paint mode, part 2

                lda cursor_x            ; update cursor sprite
                asl a                   ; X pos
                asl a
                sta spr_data+0+3
                lda cursor_y            ; Y pos
                asl a
                asl a
                sbc #0                  ; carry is always clear
                sta spr_data+0+0
                ldx brush_size          ; tile
                lda cursor_tiles,x
                sta spr_data+0+1

                ldx paint_color         ; tell NMI routine to update cursor color
                beq ++                  ; color 0 is common to all subpalettes
                jsr attr_vram_offs      ; get vram_offset and vram_copy_addr
                jsr attr_bit_pos        ; 0/2/4/6 -> X
                ldy #0                  ; read attribute byte
                lda (vram_copy_addr),y
                cpx #0                  ; shift relevant bit pair to positions 1-0
                beq +
-               lsr a
                dex
                bne -
+               and #%00000011          ; clear other bits
                asl a                   ; index to user_pal -> X
                asl a
                ora paint_color
                tax
++              lda user_pal,x          ; cursor color -> A
                sta vram_buf_val+1      ; append to VRAM buffer (always index 1)
                lda #$3f
                sta vram_buf_adrhi+1
                lda #(4*4+3)
                sta vram_buf_adrlo+1
                inc vram_buf_len

                lda pad_status          ; if A not pressed, we are done
                and #pad_a
                beq rts_label

                lda cursor_y            ; edit one byte (tile) in vram_copy and
                lsr a                   ; tell NMI routine to update it to VRAM
                pha                     ; compute offset to vram_copy and VRAM $2000
                lsr a                   ; bits: cursor_y = 00ABCDEF, cursor_x = 00abcdef,
                lsr a                   ; -> vram_offset = 000000AB CDEabcde
                lsr a
                sta vram_offset+1
                pla
                and #%00000111
                lsr a
                ror a
                ror a
                ora cursor_x
                ror a
                sta vram_offset+0

                jsr get_vramcopyadr     ; get vram_copy_addr
                lda brush_size
                beq +

                ldx paint_color         ; large brush -> replace entire byte/tile with solid color
                lda solid_tiles,x
                jmp update_tile

+               ldy #0                  ; small brush -> replace bit pair/pixel within orig byte
                lda (vram_copy_addr),y  ; store original byte
                pha
                lda cursor_x            ; pixel position within tile (0-3) -> X
                lsr a
                lda cursor_y
                rol a
                and #%00000011
                tax
                lda pixel_masks,x       ; AND mask for clearing a bit pair -> temp
                eor #%11111111
                sta temp
                ldy paint_color         ; OR mask for changing a cleared bit pair -> X
                lda solid_tiles,y
                and pixel_masks,x
                tax
                pla                     ; restore original byte, clear bit pair and change it
                and temp
                stx temp
                ora temp

update_tile     ldy #0                  ; update byte in vram_copy
                sta (vram_copy_addr),y
                jsr to_vram_buffer      ; tell NMI routine to update A to VRAM
rts_label       rts                     ; return to main loop

cursor_tiles    db $10, $11                                    ; small/large cursor tile
solid_tiles     db %00000000, %01010101, %10101010, %11111111  ; tiles of solid color 0-3
pixel_masks     db %11000000, %00110000, %00001100, %00000011  ; bitmasks for pxls within tile ind

; --- Attribute editor (code label prefix "ae") ---------------------------------------------------

attr_editor     lda prev_pad_status     ; if any button pressed on previous frame, ignore all
                beq +
                jmp attr_editor2        ; TODO: code golf to get label within branch range

+               lda pad_status          ; if select pressed, switch to palette editor
                and #pad_sl
                beq +
                ldx #(1*4)              ; hide attribute editor sprites (#1-#4)
                ldy #4
                jsr hide_sprites        ; X = first byte index, Y = count
-               lda initial_spr_dat,x   ; show palette editor sprites (#5-#23)
                sta spr_data,x
                inx
                inx
                inx
                inx
                cpx #(24*4)
                bne -
                inc mode                ; change program mode
                rts                     ; return to main loop

+               lda pad_status          ; if A/B pressed, change attr block subpalette (bit pair)
                and #(pad_a|pad_b)
                beq ae_arrows
                jsr attr_vram_offs      ; get vram_offset and vram_copy_addr
                jsr attr_bit_pos        ; 0/2/4/6 -> X
                ldy #0                  ; attribute byte to modify -> stack
                lda (vram_copy_addr),y
                pha
                and bitpair_masks,x     ; attr byte with bits other than LSB of bit pair cleared
                bit pad_status          ; if A pressed, increment subpalette, else decrement
                bpl +
                asl a                   ; incr subpalette (ASL is only used to update zero flag)
                beq ++                  ; if LSB of bit pair is CLEAR, only flip it,
                inx                     ; else INX to flip MSB too
                bpl ++                  ; unconditional
+               asl a                   ; decr subpalette (ASL is only used to update zero flag)
                bne ++                  ; if LSB of bit pair is SET, only flip it,
                inx                     ; else INX to flip MSB too
++              pla                     ; pull original attribute byte
                eor bitpair_masks,x     ; flip LSB only or MSB too
                sta (vram_copy_addr),y  ; store to vram_copy (Y is still 0)
                jsr to_vram_buffer      ; tell NMI routine to update A to VRAM

ae_arrows       lda pad_status          ; check horizontal arrows
                lsr a
                bcs +
                lsr a
                bcs ++
                bcc ae_check_vert       ; unconditional
+               lda cursor_x            ; right
                adc #(4-1)              ; carry is always set
                bcc +++                 ; unconditional
++              lda cursor_x            ; left
                sbc #4                  ; carry is always set
+++             and #%00111111          ; store horizontal position
                sta cursor_x
ae_check_vert   lda pad_status          ; check vertical arrows
                lsr a
                lsr a
                lsr a
                bcs +
                lsr a
                bcs ++
                bcc attr_editor2        ; unconditional
+               lda cursor_y            ; down
                adc #(4-1)              ; carry is always set
                cmp #60
                bne +++
                lda #0
                beq +++                 ; unconditional
++              lda cursor_y            ; up
                sbc #4                  ; carry is always set
                bpl +++
                lda #(60-4)
+++             sta cursor_y            ; store vertical position

attr_editor2    lda cursor_x            ; update cursor sprite X
                asl a
                asl a
                sta spr_data+4+3
                sta spr_data+3*4+3
                adc #8                  ; carry is always clear
                sta spr_data+2*4+3
                sta spr_data+4*4+3
                lda cursor_y            ; update cursor sprite Y
                asl a
                asl a
                adc #(8-1)              ; carry is always clear
                sta spr_data+3*4+0
                sta spr_data+4*4+0
                sbc #(8-1)              ; carry is always clear
                sta spr_data+4+0
                sta spr_data+2*4+0
                rts                     ; return to main loop

bitpair_masks   db %00000001, %00000011  ; AND/XOR masks for changing bit pairs
                db %00000100, %00001100  ; (LSB or both LSB and MSB of each)
                db %00010000, %00110000
                db %01000000, %11000000

; --- Subroutines used by both paint mode and attribute editor ------------------------------------

attr_bit_pos    lda cursor_y            ; position within attribute byte -> X (0/2/4/6)
                and #%00000100          ; bits: cursor_y = 00ABCDEF, cursor_x = 00abcdef
                lsr a                   ; -> X = 00000Dd0
                tax
                lda cursor_x
                and #%00000100
                cmp #%00000100          ; bit -> carry
                txa
                adc #0
                asl a
                tax
                rts

attr_vram_offs  lda #%00000011          ; get VRAM offset for attribute byte,
                sta vram_offset+1       ; fall through to next sub
                lda cursor_y            ; bits: cursor_y = 00ABCDEF, cursor_x = 00abcdef
                and #%00111000          ; -> vram_offset = $3c0 + 00ABCabc = 00000011 11ABCabc
                sta temp
                lda cursor_x
                lsr a
                lsr a
                lsr a
                ora temp
                ora #%11000000
                sta vram_offset+0       ; fall through to next sub

get_vramcopyadr lda vram_offset+0       ; get address within vram_copy
                sta vram_copy_addr+0    ; vram_copy + vram_offset -> vram_copy_addr
                lda #>vram_copy         ; (vram_copy must be at $xx00)
                clc
                adc vram_offset+1
                sta vram_copy_addr+1
                rts

to_vram_buffer  ldx vram_buf_len        ; tell NMI routine to write A to VRAM $2000 + vram_offset
                sta vram_buf_val,x
                lda #$20
                ora vram_offset+1
                sta vram_buf_adrhi,x
                lda vram_offset+0
                sta vram_buf_adrlo,x
                inc vram_buf_len
                rts

; --- Palette editor (code label prefix "pe") -----------------------------------------------------

pal_editor      lda prev_pad_status     ; if any button pressed on previous frame, ignore all
                bne pal_editor2

                lda pad_status          ; react to buttons (shift left to take advantage of BMI)
                ;
                asl a
                bcs pe_inc_16s          ; A
                asl a
                bcs pe_dec_16s          ; B
                asl a
                bcs pe_exit             ; select; ends with RTS
                asl a
                bcs pe_inc_subpal       ; start
                asl a
                bcs pe_up               ; up
                asl a
                bcs pe_down             ; down
                bmi pe_dec_ones         ; left
                bne pe_inc_ones         ; right
                beq pal_editor2         ; unconditional

pe_exit         ldx #(5*4)              ; exit palette editor (switch to paint mode)
                ldy #19                 ; hide palette editor sprites (#5-#23)
                jsr hide_sprites        ; X = first byte index, Y = count
                lda #0
                sta mode                ; change program mode
                rts                     ; return to main loop

pe_inc_subpal   lda pal_ed_subpal       ; increment subpalette (0 -> 1 -> 2 -> 3 -> 0)
                adc #0                  ; carry is always set
                and #%00000011
                sta pal_ed_subpal
                bpl pal_editor2         ; unconditional

pe_down         ldx pal_ed_cur_pos      ; move down
                inx
                bpl +                   ; unconditional
pe_up           ldx pal_ed_cur_pos      ; move up
                dex
+               txa                     ; store cursor position
                and #%00000011
                sta pal_ed_cur_pos
                tax
                bpl pal_editor2         ; unconditional

pe_inc_ones     jsr user_pal_offset     ; increment ones
                ldy user_pal,x
                iny
                bpl +                   ; unconditional
pe_dec_ones     jsr user_pal_offset     ; decrement ones
                ldy user_pal,x
                dey
+               tya                     ; store ones
                and #%00001111
                sta temp
                lda user_pal,x
                and #%00110000
                ora temp
                sta user_pal,x
                bpl pal_editor2         ; unconditional

pe_inc_16s      jsr user_pal_offset     ; increment sixteens
                lda user_pal,x
                clc
                adc #$10
                bpl +                   ; unconditional
pe_dec_16s      jsr user_pal_offset     ; decrement sixteens
                lda user_pal,x
                sec
                sbc #$10
+               and #%00111111          ; store sixteens
                sta user_pal,x
                bpl pal_editor2         ; unconditional

pal_editor2     lda pal_ed_subpal       ; palette editor, part 2
                sta spr_data+8*4+1      ; update tile of selected subpalette
                lda pal_ed_cur_pos      ; update cursor Y position
                asl a
                asl a
                asl a
                adc #(24*8-1)           ; carry is always clear
                sta spr_data+5*4+0
                jsr user_pal_offset     ; update sixteens tile of color number
                lda user_pal,x
                lsr a
                lsr a
                lsr a
                lsr a
                sta spr_data+10*4+1
                lda user_pal,x          ; update ones tile of color number
                and #%00001111
                sta spr_data+11*4+1

                ; tell NMI routine to update 5 VRAM bytes (indexes 1-5 in VRAM buffer)
                lda #$3f                ; high bytes of all addresses
                ldx #4
-               sta vram_buf_adrhi+1,x
                dex
                bpl -
                ;
                jsr user_pal_offset     ; selected color -> background palette (sub outputs A, X)
                lda user_pal,x
                sta vram_buf_val+1
                stx vram_buf_adrlo+1
                ;
                lda user_pal+0          ; 1st color of all subpalettes...
                sta vram_buf_val+2
                lda #(4*4+2)            ; to 3rd color in 1st sprite subpalette
                sta vram_buf_adrlo+2
                ;
                lda pal_ed_subpal       ; subpalette offset in user palette -> X
                asl a
                asl a
                tax
                ;
                lda user_pal+1,x        ; 2nd color of selected subpalette...
                sta vram_buf_val+3
                lda #(5*4+2)            ; to 3rd color in 2nd sprite subpalette
                sta vram_buf_adrlo+3
                ;
                lda user_pal+2,x        ; 3rd color of selected subpalette...
                sta vram_buf_val+4
                lda #(6*4+2)            ; to 3rd color in 3rd sprite subpalette
                sta vram_buf_adrlo+4
                ;
                lda user_pal+3,x        ; 4th color of selected subpalette...
                sta vram_buf_val+5
                lda #(7*4+2)            ; to 3rd color in 4th sprite subpalette
                sta vram_buf_adrlo+5
                ;
                lda #6                  ; update buffer length
                sta vram_buf_len

                rts                     ; return to main loop

user_pal_offset lda pal_ed_cur_pos      ; offset to user palette (user_pal or VRAM $3f00-$3f0f)
                beq +                   ; -> A, X
                lda pal_ed_subpal       ; if 1st color of any subpal, zero,
                asl a                   ; else subpalette * 4 + cursor pos
                asl a
                ora pal_ed_cur_pos
+               tax
                rts

; --- Subroutines used by many parts of the program -----------------------------------------------

hide_sprites    lda #$ff                ; hide some sprites
-               sta spr_data,x          ; X = first index on sprite page, Y = count
                inx
                inx
                inx
                inx
                dey
                bne -
                rts

set_ppu_addr_pg lda #$00                ; clear A and set PPU address page from Y
set_ppu_addr    sty ppu_addr            ; set PPU address from Y and A
                sta ppu_addr            ; (don't use X because NMI routine reads addresses from
                rts                     ; zero page array and 6502 has LDA zp,x but no LDA zp,y)

set_ppu_regs    lda #0                  ; reset PPU scroll
                sta ppu_scroll
                sta ppu_scroll
                lda ppu_ctrl_copy
                sta ppu_ctrl
                lda #%00011110          ; show BG & sprites on entire screen
                sta ppu_mask
                rts

; --- Interrupt routines --------------------------------------------------------------------------

nmi             pha                     ; store A, X, Y
                txa
                pha
                tya
                pha

                bit ppu_status          ; reset ppu_addr/ppu_scroll latch
                lda #$00                ; do OAM DMA
                sta oam_addr
                lda #>spr_data
                sta oam_dma

                ldx #$ff                ; update VRAM from buffer (X = source index)
-               inx
                cpx vram_buf_len
                beq +
                ldy vram_buf_adrhi,x    ; high byte of address
                lda vram_buf_adrlo,x    ; low byte of address
                jsr set_ppu_addr        ; Y, A -> address
                lda vram_buf_val,x      ; value
                sta ppu_data
                jmp -

+               jsr set_ppu_regs        ; set ppu_scroll/ppu_ctrl/ppu_mask

                sec                     ; set flag (MSB) to let main loop run once
                ror run_main_loop

                pla                     ; restore Y, X, A
                tay
                pla
                tax
                pla

irq             rti

; --- Interrupt vectors ---------------------------------------------------------------------------

                pad $fffa, $ff
                dw nmi, reset, irq      ; note: IRQ unused
