; Kalle Paint (NES, ASM6)

; --- Constants -----------------------------------------------------------------------------------

; Note: "PPU buffer" = what to update in PPU memory on next VBlank.

; RAM
user_pal        equ $00    ; user palette (16 bytes; each $00-$3f; offsets 4/8/12 are unused)
ppu_buf_addrhi  equ $10    ; PPU buffer - high bytes of addresses (6 bytes)
ppu_buf_addrlo  equ $16    ; PPU buffer - low  bytes of addresses (6 bytes)
ppu_buf_values  equ $1c    ; PPU buffer - values                  (6 bytes)
vram_offset     equ $22    ; offset to name/attr table 0 and vram_copy (2 bytes, low first; 0-$3ff)
vram_copy_addr  equ $24    ; address in vram_copy (2 bytes, low first; vram_copy...vram_copy+$3ff)
mode            equ $26    ; program mode: 0 = paint, 1 = attribute editor, 2 = palette editor
run_main_loop   equ $27    ; run main loop? (MSB: 0=no, 1=yes)
pad_status      equ $28    ; joypad status (bits: A, B, select, start, up, down, left, right)
prev_pad_status equ $29    ; joypad status on previous frame
ppu_buf_len     equ $2a    ; VRAM buffer - number of bytes (0-6)
delay_left      equ $2b    ; cursor move delay left (paint mode)
brush_size      equ $2c    ; cursor type            (paint mode; 0=small, 1=large)
paint_color     equ $2d    ; paint color            (paint mode; 0-3)
cursor_x        equ $2e    ; cursor X position      (paint mode/attribute editor; 0-63)
cursor_y        equ $2f    ; cursor Y position      (paint mode/attribute editor; 0-59)
blink_timer     equ $30    ; cursor blink timer     (attribute/palette editor)
pal_ed_cur_pos  equ $31    ; cursor position        (palette editor; 0-3)
pal_ed_subpal   equ $32    ; selected subpalette    (palette editor; 0-3)
temp            equ $33    ; temporary
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
col_paled_text1 equ $28  ; palette editor text 1     ("Pal" & subpalette number; yellow)
col_paled_text2 equ $30  ; palette editor text 2     (color numbers; white)
col_blink1      equ $0f  ; blinking cursor 1         (black)
col_blink2      equ $30  ; blinking cursor 2         (white)

; misc
blink_rate      equ 4    ; blink rate of attribute/palette editor cursor (0=fastest, 7=slowest)
brush_delay     equ 10   ; paint cursor move repeat delay (frames)

; --- iNES header ---------------------------------------------------------------------------------

                ; see https://wiki.nesdev.org/w/index.php/INES
                ;
                base $0000
                db "NES", $1a            ; file id
                db 1, 1                  ; 16 KiB PRG ROM, 8 KiB CHR ROM
                db %00000000, %00000000  ; NROM mapper; name table mirroring doesn't matter
                pad $0010, $00           ; unused

; --- Initialization ------------------------------------------------------------------------------

                base $c000              ; last 16 KiB of CPU address space

reset           ; initialize the NES; see https://wiki.nesdev.org/w/index.php/Init_code
                ;
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

                ldy #$3f                ; init PPU palette (while still in VBlank)
                jsr set_ppu_addr_pg     ; 0 -> A; Y*$100 -> address
                tax
-               lda initial_pal,x
                sta ppu_data
                inx
                cpx #32
                bne -

                ldy #$20                ; clear name/attribute table 0 ($400 bytes)
                jsr set_ppu_addr_pg     ; 0 -> A; Y*$100 -> address
                ;
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
                ; 3rd color in all subpalettes: selected colors in palette editor
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
                db 22*8-1, $13, %00000001, 28*8  ; #6:  "Pal" - left  half
                db 22*8-1, $14, %00000001, 29*8  ; #7:  "Pal" - right half
                db 22*8-1, $00, %00000001, 30*8  ; #8:  subpalette number
                db 23*8-1, $15, %00000000, 28*8  ; #9:  color 0 indicator
                db 24*8-1, $15, %00000001, 28*8  ; #10: color 1 indicator
                db 25*8-1, $15, %00000010, 28*8  ; #11: color 2 indicator
                db 26*8-1, $15, %00000011, 28*8  ; #12: color 3 indicator
                db 23*8-1, $00, %00000010, 29*8  ; #13: color 0 - sixteens
                db 23*8-1, $00, %00000010, 30*8  ; #14: color 0 - ones
                db 24*8-1, $00, %00000010, 29*8  ; #15: color 1 - sixteens
                db 24*8-1, $00, %00000010, 30*8  ; #16: color 1 - ones
                db 25*8-1, $00, %00000010, 29*8  ; #17: color 2 - sixteens
                db 25*8-1, $00, %00000010, 30*8  ; #18: color 2 - ones
                db 26*8-1, $00, %00000010, 29*8  ; #19: color 3 - sixteens
                db 26*8-1, $00, %00000010, 30*8  ; #20: color 3 - ones

; --- Main loop - common --------------------------------------------------------------------------

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

                ldx #col_blink1         ; tell NMI routine to update color of blinking cursor
                lda blink_timer
                and #(1<<blink_rate)
                beq +
                ldx #col_blink2
+               txa
                ldy #(4*4+3)
                jsr to_ppu_buf_pal      ; tell NMI routine to write A to VRAM $3f00 + Y

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

; --- Main loop - paint mode (label prefix "pm_") -------------------------------------------------

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
++              lda user_pal,x          ; cursor color
                ldy #(4*4+3)
                jsr to_ppu_buf_pal      ; tell NMI routine to write A to VRAM $3f00 + Y

                lda pad_status          ; if A not pressed, we are done
                and #pad_a
                beq rts_label

                ; edit one byte (tile) in vram_copy and tell NMI routine to update it to VRAM

                lda cursor_y            ; get vram_offset; bits: cursor_y = %00ABCDEF,
                lsr a                   ; cursor_x = %00abcdef, vram_offset = %000000AB %CDEabcde
                pha
                lsr a
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

                ldx paint_color         ; large brush; replace entire byte/tile with solid color
                lda solid_tiles,x
                jmp update_tile

+               ldy #0                  ; small brush; replace bit pair/pixel within orig byte
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
                jsr to_ppu_buf_vram     ; tell NMI routine to update A to VRAM
rts_label       rts                     ; return to main loop

solid_tiles     db %00000000, %01010101, %10101010, %11111111  ; tiles of solid color 0-3
pixel_masks     db %11000000, %00110000, %00001100, %00000011  ; bitmasks for pxls within tile ind

; --- Main loop - attribute editor (label prefix "ae_") -------------------------------------------

attr_editor     lda prev_pad_status     ; if any button pressed on previous frame, ignore all
                beq +
                jmp attr_editor2

+               lda pad_status          ; if select pressed, switch to palette editor
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

; --- Subs used by paint mode & attribute editor --------------------------------------------------

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

; --- Main loop - palette editor (label prefix "pe_") ---------------------------------------------

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
                ldy #16                 ; hide palette editor sprites (#5-#20)
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

pal_editor2     ; palette editor, part 2

                ; update sprites
                ;
                lda pal_ed_subpal       ; tile of selected subpalette
                sta spr_data+8*4+1
                lda pal_ed_cur_pos      ; cursor Y position
                asl a
                asl a
                asl a
                adc #(23*8-1)           ; carry is always clear
                sta spr_data+5*4+0
                ;
                ldx #0                  ; sixteens and ones of 1st color
                ldy #(13*4)
                jsr upd_num_tiles       ; X = user_pal index, Y = spr_data index
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
                jsr upd_num_tiles       ; X = user_pal index, Y = spr_data index
                txa
                and #%00000011
                cmp #%00000011
                bne -

                ; tell NMI routine to update 5 colors
                ;
                jsr user_pal_offset     ; selected color -> background palette (A, X)
                tay
                lda user_pal,x
                jsr to_ppu_buf_pal      ; tell NMI routine to write A to VRAM $3f00 + Y
                ;
                lda user_pal+0          ; 1st color of all subpalettes
                ldy #(4*4+2)            ; to 3rd color in 1st sprite subpalette
                jsr to_ppu_buf_pal
                ;
                lda pal_ed_subpal       ; subpalette offset in user palette -> X
                asl a
                asl a
                tax
                ;
                lda user_pal+1,x        ; 2nd/3rd/4th color of selected subpalette
                ldy #(5*4+2)            ; to 3rd color in 2nd/3rd/4th sprite subpalette
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

user_pal_offset lda pal_ed_cur_pos      ; offset to user palette (user_pal or VRAM $3f00-$3f0f)
                beq +                   ; -> A, X
                lda pal_ed_subpal       ; if 1st color of any subpal, zero,
                asl a                   ; else subpalette * 4 + cursor pos
                asl a
                ora pal_ed_cur_pos
+               tax
                rts

upd_num_tiles   lda user_pal,x          ; update tiles of 2 sprites (sixteens and ones)
                lsr a                   ; X = index to user_pal
                lsr a                   ; Y = index to 1st sprite in spr_data
                lsr a
                lsr a
                sta spr_data+1,y
                lda user_pal,x
                and #%00001111
                sta spr_data+4+1,y
                rts

; --- Interrupt routines --------------------------------------------------------------------------

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

                sec                     ; set flag (MSB) to let main loop run once
                ror run_main_loop

                pla                     ; pull Y, X, A
                tay
                pla
                tax
                pla

irq             rti                     ; IRQ unused

; --- Subs used in many places --------------------------------------------------------------------

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
                lda #%10001000          ; NMI: enabled, sprites: 8*8 px, BG PT: 0, sprite PT: 1,
                sta ppu_ctrl            ; VRAM address auto-increment: 1 byte, name table: 0
                lda #%00011110          ; show BG & sprites on entire screen
                sta ppu_mask
                rts

to_ppu_buf_pal  stx temp                ; tell NMI routine to write A to VRAM $3f00 + Y
                ldx ppu_buf_len
                sta ppu_buf_values,x
                lda #$3f
                sta ppu_buf_addrhi,x
                sty ppu_buf_addrlo,x
                inc ppu_buf_len
                ldx temp
                rts

to_ppu_buf_vram ldx ppu_buf_len         ; tell NMI routine to write A to VRAM $2000 + vram_offset
                sta ppu_buf_values,x
                lda #$20
                ora vram_offset+1
                sta ppu_buf_addrhi,x
                lda vram_offset+0
                sta ppu_buf_addrlo,x
                inc ppu_buf_len
                rts

; --- Interrupt vectors ---------------------------------------------------------------------------

                pad $fffa, $ff
                dw nmi, reset, irq      ; IRQ unused

; --- CHR ROM -------------------------------------------------------------------------------------

                base $0000
                incbin "chr-bg.bin"     ; background (combinations of 2*2 subpixels in 4 colors)
                pad $1000, $ff
                incbin "chr-spr.bin"    ; sprites
                pad $2000, $ff
