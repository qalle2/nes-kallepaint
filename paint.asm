; Kalle Paint a.k.a. Qalle Paint (NES, ASM6)

; --- Constants ---------------------------------------------------------------

; Notes:
; - PPU buffer: what to update in PPU memory on next VBlank.
; - program modes: 0 = paint mode, 1 = attribute editor, 2 = palette editor
; - 2-byte addresses: less significant byte first.
; - Boolean variables: $00-$7f = false, $80-$ff = true.

; RAM
user_pal        equ $00    ; user palette (16 bytes; offsets 4/8/12 unused)
ppu_buf_addrhi  equ $10    ; PPU buffer - high bytes of addresses (6 bytes)
ppu_buf_addrlo  equ $16    ; PPU buffer - low  bytes of addresses (6 bytes)
ppu_buf_values  equ $1c    ; PPU buffer - values                  (6 bytes)
vram_offset     equ $22    ; offset to NT0 & vram_copy (2 bytes, 0-$3ff)
vram_copy_addr  equ $24    ; address within  vram_copy (2 bytes)
mode            equ $26    ; program mode (see above)
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
pal_ed_cur_pos  equ $31    ; cursor position     (palette editor; 0-3)
pal_ed_subpal   equ $32    ; selected subpalette (palette editor; 0-3)
temp            equ $33    ; temporary
vram_copy       equ $0200  ; copy of NT0 & AT0 ($400 bytes; must be at $xx00)
spr_data        equ $0600  ; OAM page ($100 bytes)

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
col_paled_text1 equ $28  ; palette editor text 1 ("Pal" & subpal. num.; yellow)
col_paled_text2 equ $30  ; palette editor text 2 (color numbers; white)
col_blink1      equ $0f  ; blinking cursor 1 (black)
col_blink2      equ $30  ; blinking cursor 2 (white)

; misc
blink_rate      equ 4    ; blink rate of attribute/palette editor cursor
                         ; (0=fastest, 7=slowest)
brush_delay     equ 10   ; paint cursor move repeat delay (frames)

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

                ldx #(21*4-1)           ; init sprite data
-               lda initial_spr_dat,x
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

                ; initialize PPU palette (while still in VBlank)
                ldy #$3f
                jsr set_ppu_addr_pg     ; 0 -> A; Y*$100 -> address
                tax
-               lda initial_pal,x
                sta ppu_data
                inx
                cpx #32
                bne -

                ; clear name/attribute table 0
                ldy #$20
                jsr set_ppu_addr_pg     ; 0 -> A; Y*$100 -> address
                ldy #4
                tax
-               sta ppu_data
                inx
                bne -
                dey
                bne -

                jsr wait_vbl_start      ; wait until next VBlank starts
                jsr set_ppu_regs        ; set ppu_scroll/ppu_ctrl/ppu_mask
                jmp main_loop

wait_vbl_start  bit ppu_status          ; wait until next VBlank starts
-               bit ppu_status
                bpl -
                rts

initial_pal     ; initial palette
                ;
                ; background (also the initial user palette)
                db col_def_bg, col_def_0a, col_def_0b, col_def_0c
                db col_def_bg, col_def_1a, col_def_1b, col_def_1c
                db col_def_bg, col_def_2a, col_def_2b, col_def_2c
                db col_def_bg, col_def_3a, col_def_3b, col_def_3c
                ;
                ; sprites
                ; 2nd color in all subpalettes: palette editor background
                ; 3rd color in all subpalettes: selected colors in pal. editor
                ; 4th color in 1st subpalette : all cursors
                ; 4th color in 2nd subpalette : palette editor text 1
                ; 4th color in 3rd subpalette : palette editor text 2
                ; 4th color in 4th subpalette : unused
                db col_def_bg, col_paled_bg, col_def_bg, col_def_0a
                db col_def_bg, col_paled_bg, col_def_0a, col_paled_text1
                db col_def_bg, col_paled_bg, col_def_0b, col_paled_text2
                db col_def_bg, col_paled_bg, col_def_0c, $00

initial_spr_dat ; initial sprite data (Y, tile, attributes, X for each sprite)
                ;
                ; paint mode
                db    $ff, $10, %00000000,    0  ; #0:  cursor
                ;
                ; attribute editor
                db    $ff, $12, %00000000,    0  ; #1:  cursor top left
                db    $ff, $12, %01000000,    0  ; #2:  cursor top right
                db    $ff, $12, %10000000,    0  ; #3:  cursor bottom left
                db    $ff, $12, %11000000,    0  ; #4:  cursor bottom right
                ;
                ; palette editor
                db    $ff, $11, %00000000, 28*8  ; #5:  cursor
                db 23*8-1, $13, %00000001, 28*8  ; #6:  "Pal" - left  half
                db 23*8-1, $14, %00000001, 29*8  ; #7:  "Pal" - right half
                db 23*8-1, $00, %00000001, 30*8  ; #8:  subpalette number
                db 24*8-1, $15, %00000000, 28*8  ; #9:  color 0 indicator
                db 25*8-1, $15, %00000001, 28*8  ; #10: color 1 indicator
                db 26*8-1, $15, %00000010, 28*8  ; #11: color 2 indicator
                db 27*8-1, $15, %00000011, 28*8  ; #12: color 3 indicator
                db 24*8-1, $00, %00000010, 29*8  ; #13: color 0 - sixteens
                db 24*8-1, $00, %00000010, 30*8  ; #14: color 0 - ones
                db 25*8-1, $00, %00000010, 29*8  ; #15: color 1 - sixteens
                db 25*8-1, $00, %00000010, 30*8  ; #16: color 1 - ones
                db 26*8-1, $00, %00000010, 29*8  ; #17: color 2 - sixteens
                db 26*8-1, $00, %00000010, 30*8  ; #18: color 2 - ones
                db 27*8-1, $00, %00000010, 29*8  ; #19: color 3 - sixteens
                db 27*8-1, $00, %00000010, 30*8  ; #20: color 3 - ones

; --- Main loop - common ------------------------------------------------------

main_loop       bit run_main_loop       ; wait until NMI routine has run
                bpl main_loop

                ; prevent main loop from running until after next NMI
                lsr run_main_loop

                lda pad_status          ; store previous joypad status
                sta prev_pad_status

                ; read first joypad or Famicom expansion port controller
                ; see https://www.nesdev.org/wiki/Controller_reading_code
                ; bits: A, B, select, start, up, down, left, right
                lda #$01
                sta joypad1
                sta pad_status
                lsr a
                sta joypad1
-               lda joypad1
                and #%00000011
                cmp #$01
                rol pad_status
                bcc -

                ; tell NMI routine to update color of blinking cursor
                ldx #col_blink1
                lda blink_timer
                and #(1<<blink_rate)
                beq +
                ldx #col_blink2
+               txa
                ldy #(4*4+3)
                jsr to_ppu_buf_pal      ; A to VRAM $3f00 + Y

                inc blink_timer         ; advance timer
                jsr jump_engine         ; run code for this program mode
                jmp main_loop

jump_engine     ; jump engine (run one sub depending on program mode)
                ; note: don't inline this sub
                ;
                ; push target address minus one, high byte first
                ldx mode
                lda jump_table_hi,x
                pha
                lda jump_table_lo,x
                pha
                ; pull address, low byte first; jump to address plus one
                rts

                ; jump table - high/low bytes
jump_table_hi   dh paint_mode-1, attr_editor-1, pal_editor-1
jump_table_lo   dl paint_mode-1, attr_editor-1, pal_editor-1

; --- Main loop - paint mode (label prefix "pm_") -----------------------------

paint_mode      ; if select/B/start pressed on previous frame, ignore them all
                lda prev_pad_status
                and #%01110000
                bne pm_arrows

                lda pad_status          ; select: switch to attribute editor
                and #pad_sl
                beq +
                lda #$ff                ; hide paint cursor sprite
                sta spr_data+0+0
                lda #%00111100          ; make cursor coordinates multiple of 4
                and cursor_x
                sta cursor_x
                lda #%00111100
                and cursor_y
                sta cursor_y
                inc mode                ; change program mode
                rts                     ; return to main loop

+               lda pad_status          ; B button: increment paint color (0-3)
                and #pad_b
                beq +
                ldx paint_color
                inx
                txa
                and #%00000011
                sta paint_color

+               lda pad_status          ; start: toggle brush size
                and #pad_st
                beq pm_arrows
                lda brush_size
                eor #%00000001
                sta brush_size
                beq pm_arrows
                lsr cursor_x            ; if large brush, make coordinates even
                asl cursor_x            ; note: not allowing odd coordinates
                lsr cursor_y            ; makes logic a lot simpler
                asl cursor_y

pm_arrows       lda pad_status          ; d-pad arrow logic
                and #%00001111
                bne +
                sta delay_left          ; none: clear cursor move delay
                beq paint_mode2         ; unconditional; ends with RTS
+               lda delay_left          ; elseif delay > 0, decrement & exit
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
                lda brush_size          ; tile
                clc
                adc #$10
                sta spr_data+0+1

                ; tell NMI routine to update cursor color
                ;
                ldx paint_color
                beq ++                  ; color 0 is common to all subpalettes
                jsr attr_vram_offs      ; get vram_offset and vram_copy_addr
                jsr attr_bit_pos        ; 0/2/4/6 -> X
                ldy #0                  ; read attribute byte
                lda (vram_copy_addr),y
                cpx #0                  ; shift correct bit pair to pos 1-0
                beq +
-               lsr a
                dex
                bne -
+               and #%00000011          ; clear other bits
                asl a                   ; index to user_pal -> X
                asl a
                ora paint_color
                tax
++              lda user_pal,x          ; cursor color
                ldy #(4*4+3)
                jsr to_ppu_buf_pal      ; A to VRAM $3f00 + Y

                lda pad_status          ; if A not pressed, we are done
                and #pad_a
                beq rts_label

                ; edit one byte/tile in vram_copy and tell NMI routine to
                ; update it to VRAM

                lda cursor_y            ; get vram_offset; bits:
                lsr a                   ; cursor_y = %00ABCDEF
                pha                     ; cursor_x = %00abcdef
                lsr a                   ; vram_offset = %000000AB %CDEabcde
                lsr a
                lsr a
                sta vram_offset+1
                ;
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

                ; large brush; replace entire byte/tile with solid color
                ldx paint_color
                lda solid_tiles,x
                jmp update_tile

+               ; small brush; replace bit pair/pixel within original byte
                ldy #0                  ; store original byte
                lda (vram_copy_addr),y
                pha
                lda cursor_x            ; pixel position within tile (0-3) -> X
                lsr a
                lda cursor_y
                rol a
                and #%00000011
                tax
                lda pixel_masks,x       ; AND mask to clear bitpair -> temp
                eor #%11111111
                sta temp
                ldy paint_color         ; OR mask to set cleared bitpair -> X
                lda solid_tiles,y
                and pixel_masks,x
                tax
                pla                     ; restore original byte
                and temp                ; clear bitpair
                stx temp
                ora temp                ; set new bitpair

update_tile     ldy #0                  ; update byte in vram_copy
                sta (vram_copy_addr),y
                jsr to_ppu_buf_vram     ; tell NMI routine to update A to VRAM
rts_label       rts                     ; return to main loop

solid_tiles     ; tiles of solid color 0-3
                db %00000000, %01010101, %10101010, %11111111
                ; bitmasks for individual pixels in tile index
pixel_masks     db %11000000, %00110000, %00001100, %00000011

; --- Main loop - attribute editor (label prefix "ae_") -----------------------

attr_editor     ; if any button pressed on previous frame, ignore all
                lda prev_pad_status
                beq +
                jmp attr_editor2

+               lda pad_status          ; select: switch to palette editor
                and #pad_sl
                beq +
                ldx #(1*4)              ; hide attribute editor sprites (#1-#4)
                ldy #4
                jsr hide_sprites        ; X = first byte index, Y = count
-               lda initial_spr_dat,x   ; show palette editor sprites (#5-#20)
                sta spr_data,x
                inx
                inx
                inx
                inx
                cpx #(21*4)
                bne -
                inc mode                ; change program mode
                rts                     ; return to main loop

+               ; A/B button: change attribute block subpalette (bit pair)
                ; TODO: less code golf
                lda pad_status
                and #(pad_a|pad_b)
                beq ae_arrows
                jsr attr_vram_offs      ; get vram_offset and vram_copy_addr
                jsr attr_bit_pos        ; 0/2/4/6 -> X
                ldy #0                  ; attribute byte to modify -> stack
                lda (vram_copy_addr),y
                pha
                ; attr byte with bits other than LSB of bit pair cleared
                and bitpair_masks,x
                bit pad_status          ; subpal: increment if A btn, else decr
                bpl +
                asl a                   ; incr subpalette (ASL updates Z flag)
                beq ++                  ; if LSB of bitpair CLEAR, only flip
                inx                     ; it, else INX to flip MSB too
                bpl ++                  ; unconditional
+               asl a                   ; decr subpalette (ASL updates Z flag)
                bne ++                  ; if LSB of bitpair SET, only flip it,
                inx                     ; else INX to flip MSB too
++              pla                     ; pull original attribute byte
                eor bitpair_masks,x     ; flip LSB only or MSB too
                sta (vram_copy_addr),y  ; store to vram_copy (Y is still 0)
                jsr to_ppu_buf_vram     ; tell NMI routine to update A to VRAM

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

; --- Subs used by paint mode & attribute editor ------------------------------

attr_bit_pos    ; position within attribute byte -> X (0/2/4/6)
                ; bits: cursor_y = 00ABCDEF, cursor_x = 00abcdef,
                ; result = 00000Dd0
                lda cursor_y
                and #%00000100
                lsr a
                tax
                lda cursor_x
                and #%00000100
                cmp #%00000100          ; bit -> carry
                txa
                adc #0
                asl a
                tax
                rts

attr_vram_offs  ; get VRAM offset for attribute byte, fall through to next sub
                ; bits: cursor_y = 00ABCDEF, cursor_x = 00abcdef
                ; -> vram_offset = $3c0 + 00ABCabc = 00000011 11ABCabc
                lda #%00000011
                sta vram_offset+1
                lda cursor_y
                and #%00111000
                sta temp
                lda cursor_x
                lsr a
                lsr a
                lsr a
                ora temp
                ora #%11000000
                sta vram_offset+0
                ; fall through

get_vramcopyadr ; get address within vram_copy:
                ; vram_copy + vram_offset -> vram_copy_addr
                ; (vram_copy must be at $xx00)
                lda vram_offset+0
                sta vram_copy_addr+0
                lda #>vram_copy
                clc
                adc vram_offset+1
                sta vram_copy_addr+1
                rts

; --- Main loop - palette editor (label prefix "pe_") -------------------------

pal_editor      ; if any button pressed on previous frame, ignore all
                lda prev_pad_status
                bne pal_editor2

                lda pad_status          ; react to buttons
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

pe_exit         ; exit palette editor (switch to paint mode)
                ldx #(5*4)              ; hide palette editor sprites (#5-#20)
                ldy #16
                jsr hide_sprites        ; X = first byte index, Y = count
                lda #0
                sta mode                ; change program mode
                rts                     ; return to main loop

pe_inc_subpal   ; increment selected subpalette (0 -> 1 -> 2 -> 3 -> 0)
                lda pal_ed_subpal
                adc #0                  ; carry is always set
                and #%00000011
                sta pal_ed_subpal
                bpl pal_editor2         ; unconditional

pe_down         ldx pal_ed_cur_pos      ; move cursor down
                inx
                bpl +                   ; unconditional
                ;
pe_up           ldx pal_ed_cur_pos      ; move cursor up
                dex
+               txa                     ; store cursor position
                and #%00000011
                sta pal_ed_cur_pos
                tax
                bpl pal_editor2         ; unconditional

pe_inc_ones     jsr user_pal_offset     ; increment ones of color at cursor
                ldy user_pal,x
                iny
                bpl +                   ; unconditional
                ;
pe_dec_ones     jsr user_pal_offset     ; decrement ones of color at cursor
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

pe_inc_16s      jsr user_pal_offset     ; increment sixteens of color at cursor
                lda user_pal,x
                clc
                adc #$10
                bpl +                   ; unconditional
                ;
pe_dec_16s      jsr user_pal_offset     ; decrement sixteens of color at cursor
                lda user_pal,x
                sec
                sbc #$10
+               and #%00111111          ; store sixteens
                sta user_pal,x
                bpl pal_editor2         ; unconditional

pal_editor2     ; palette editor, part 2

                ; update sprites
                ;
                lda pal_ed_subpal       ; tile of selected subpalette
                sta spr_data+8*4+1
                lda pal_ed_cur_pos      ; cursor Y position
                asl a
                asl a
                asl a
                adc #(24*8-1)           ; carry is always clear
                sta spr_data+5*4+0
                ;
                ldx #0                  ; sixteens and ones of 1st color
                ldy #(13*4)
                jsr upd_num_tiles       ; X=user_pal index, Y=spr_data index
                ;
                lda pal_ed_subpal       ; sixteens and ones of 2nd-4th color
                asl a
                asl a
                tax
-               inx
                tya
                clc
                adc #(2*4)
                tay
                jsr upd_num_tiles       ; X=user_pal index, Y=spr_data index
                txa
                and #%00000011
                cmp #%00000011
                bne -

                ; tell NMI routine to update 5 colors
                ;
                jsr user_pal_offset     ; selected color -> BG palette (A, X)
                tay
                lda user_pal,x
                jsr to_ppu_buf_pal      ; A to VRAM $3f00 + Y
                ;
                lda user_pal+0          ; 1st color of all subpalettes
                ldy #(4*4+2)            ; to 3rd color in 1st sprite subpalette
                jsr to_ppu_buf_pal
                ;
                lda pal_ed_subpal       ; subpalette offset in user pal -> X
                asl a
                asl a
                tax
                ;
                lda user_pal+1,x        ; 2nd-4th color of selected subpalette
                ldy #(5*4+2)            ; to 3rd color in 2nd-4th sprite subpal
                jsr to_ppu_buf_pal
                ;
                lda user_pal+2,x
                ldy #(6*4+2)
                jsr to_ppu_buf_pal
                ;
                lda user_pal+3,x
                ldy #(7*4+2)
                jsr to_ppu_buf_pal

                rts                     ; return to main loop

user_pal_offset ; offset to user palette (user_pal or VRAM $3f00-$3f0f) -> A, X
                ; if 1st color of any subpal, then zero,
                ; else subpalette * 4 + cursor pos
                lda pal_ed_cur_pos
                beq +
                lda pal_ed_subpal
                asl a
                asl a
                ora pal_ed_cur_pos
+               tax
                rts

upd_num_tiles   ; update tiles of 2 sprites (sixteens and ones)
                ; X = index to user_pal
                ; Y = index to 1st sprite in spr_data
                lda user_pal,x
                lsr a
                lsr a
                lsr a
                lsr a
                sta spr_data+1,y
                lda user_pal,x
                and #%00001111
                sta spr_data+4+1,y
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
                lda #>spr_data
                sta oam_dma

                ldx #$ff                ; flush VRAM buffer (X = source index)
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

                jsr set_ppu_regs        ; set ppu_scroll/ppu_ctrl/ppu_mask

                sec                     ; set flag to let main loop run once
                ror run_main_loop

                pla                     ; pull Y, X, A
                tay
                pla
                tax
                pla

irq             rti                     ; IRQ unused

; --- Subs used in many places ------------------------------------------------

hide_sprites    ; hide some sprites
                ; X = first index on sprite page, Y = count
                lda #$ff
-               sta spr_data,x
                inx
                inx
                inx
                inx
                dey
                bne -
                rts

set_ppu_addr_pg ; 0 -> A, Y*$100+A -> address
                lda #$00
set_ppu_addr    ; Y*$100+A -> address
                ; (use Y because X is needed for indexed zero page addressing)
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

to_ppu_buf_pal  ; tell NMI routine to write A to VRAM $3f00 + Y
                stx temp
                ldx ppu_buf_len
                sta ppu_buf_values,x
                lda #$3f
                sta ppu_buf_addrhi,x
                sty ppu_buf_addrlo,x
                inc ppu_buf_len
                ldx temp
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

; --- Interrupt vectors -------------------------------------------------------

                pad $fffa, $ff
                dw nmi, reset, irq      ; IRQ unused

; --- CHR ROM -----------------------------------------------------------------

                base $0000
                incbin "chr-bg.bin"     ; background
                pad $1000, $ff
                incbin "chr-spr.bin"    ; sprites
                pad $2000, $ff
