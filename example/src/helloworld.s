global start

.instr:
    start:
        ldi   AH, 0x00          ; AH:AL = 0x1000
        ldi   AL, 0x00        
        ldi   B, 0xFF           ; B:C = 0xFFF0 
        ldi   C, 0xF4         
        
    loop:
        ld    A, [AH:AL]        ; A ← MEM[AH:AL]
        cmpi  A, 0              ; is (A == 0)?
        jeq   end               ; if (A == 0) PC += (4 << 1)
        st    A, [B:C]          ; print A 
        addi  AL, 1             ; AL += 1
        jmp   loop              ; PC += (-5 << 1)

    end:
        halt                  

.data:
    0x0000: str "Hello, World!\n\0", 15
