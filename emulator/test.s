    ; 초기 주소 설정 (0x0100에 문자열 있음)
    ldi   AH, 0x01         ; AH = 0x01
    ldi   AL, 0x00         ; AL = 0x00
    ldi   R1, 0xFF         
    ldi   R2, 0xF0         

loop:
    ld    R0, AH, AL        ; R0 ← 메모리[AH:AL]
    cmpi  R0, 0         ; R0 == 0?
    jeq   end             ; 종료 조건
    st    R0, R1, R2    ; 터미널 출력 (0xFFF0)
    addi  AL, 1       ; AL += 1
    jmp   loop             ; 반복

end:
    halt
