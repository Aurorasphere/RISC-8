        .org 0x0000
start:  ; 스택 초기화
        andi  SP, #0
        addi  SP, #0x7F   ; SP = 0x7F00 (예시)

        ; AH:AL = 문자열 주소
        andi  AH, #0
        addi  AL, #msg & 0x7F      ; 저주소 예: 0x8000
        addi  AH, #((msg >> 8) & 0x7F)

loop:   ld    A                   ; A ← mem[AH:AL]
        cmpi  A, #0               ; 끝? (널)
        jeq   done
        st    A                   ; TTY OUT
        addi  AL, #1              ; AL++
        jmp   loop

done:   halt

        ; ─── 데이터 영역 ───────────────────────
        .org 0x8000
msg:    .ascii "HELLO WORLD!\0"

