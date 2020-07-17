; Kalle Paint - main loop

main:
    ; wait until NMI has set flag
    bit run_main_loop
    bpl main

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

    ; run one of two subs depending on the mode we're in
    bit in_palette_editor
    bmi +
    jsr main_paint
    jmp ++
+   jsr main_editor

    ; prevent ourselves from running again before next NMI
++  lsr run_main_loop
    jmp main

    include "main-paint.asm"
    include "main-editor.asm"

