; Kalle Paint - main loop

main_loop
        ; wait until NMI routine has run
        bit run_main_loop
        bpl main_loop

        ; prevent main loop from running again until after next NMI
        lsr run_main_loop

        ; store previous joypad status
        lda joypad_status
        sta prev_joypad_status

        ; read first joypad
        ;
        ; initialize; set LSB of variable to detect end of loop
        ldx #$01
        stx joypad_status
        stx joypad1
        dex
        stx joypad1
        ; read 1st joypad 8 times; for each button, compute OR of two LSBs
        ; bits of joypad_status: A, B, select, start, up, down, left, right
-       clc
        lda joypad1
        and #%00000011
        beq +
        sec
+       rol joypad_status
        bcc -

        ; tell NMI routine to update blinking cursor (this is the first item in vram_buffer)
        ;
        lda #$3f
        sta vram_buffer_addrhi + 0
        lda #$13
        sta vram_buffer_addrlo + 0
        ;
        ldx #editor_bg
        lda blink_timer
        and #(1 << blink_rate)
        beq +
        ldx #editor_text
+       stx vram_buffer_value + 0
        ;
        lda #0               ; store position of last byte written
        sta vram_buffer_pos

        inc blink_timer

        jsr jump_engine

        ; terminate VRAM buffer (append terminator)
        ldx vram_buffer_pos
        lda #$00
        sta vram_buffer_addrhi + 1, x

        beq main_loop  ; unconditional

; --------------------------------------------------------------------------------------------------

jump_engine
        ; Run one subroutine depending on the mode we're in. Note: don't inline this sub.

        ; push target address minus one, high byte first
        ldx mode
        lda jump_table_hi, x
        pha
        lda jump_table_lo, x
        pha
        ;
        ; pull address, low byte first; jump to that address plus one
        rts

jump_table_hi
        dh paint_mode - 1, attribute_edit_mode - 1, palette_edit_mode - 1
jump_table_lo
        dl paint_mode - 1, attribute_edit_mode - 1, palette_edit_mode - 1
