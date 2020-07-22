; Kalle Paint - main loop

main_loop:
    ; wait until NMI has set flag
    bit run_main_loop
    bpl main_loop

    ; prevent ourselves from running again before next NMI
    lsr run_main_loop

    ; remember previous joypad status
    lda joypad_status
    sta prev_joypad_status

    ; read joypad (bits: A, B, select, start, up, down, left, right)
    ldx #$01
    stx joypad_status  ; to detect end of loop
    stx joypad1
    dex
    stx joypad1
-   clc
    lda joypad1
    and #$03
    beq +
    sec
+   rol joypad_status
    bcc -

    ; start writing vram_buffer from beginning
    lda #0
    sta vram_buffer_pos

    ; tell NMI to update blinking cursor
    ;
    ldx vram_buffer_pos
    ;
    lda #$3f
    sta vram_buffer, x
    inx
    lda #$13
    sta vram_buffer, x
    inx
    ;
    lda blink_timer
    and #(1 << blink_rate)
    bne +
    lda #editor_bg
    jmp ++
+   lda #editor_text
++  sta vram_buffer, x
    inx
    ;
    stx vram_buffer_pos

    ; advance cursor blink timer
    inc blink_timer

    ; run one of three subs depending on the mode we're in
    ldx mode
    beq +
    dex
    beq ++
    jsr main_loop_palette_editor
    jmp main_loop_end
+   jsr main_loop_paint_mode
    jmp main_loop_end
++  jsr main_loop_attribute_editor
    jmp main_loop_end

main_loop_end:
    ; append terminator to vram_buffer
    ldx vram_buffer_pos
    lda #$00
    sta vram_buffer, x

    jmp main_loop

    include "mainloop-paint.asm"
    include "mainloop-attr.asm"
    include "mainloop-pal.asm"

