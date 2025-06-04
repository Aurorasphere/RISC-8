global start

.instr:
  exit:
    halt

  start:
    ldi   AH, 0xFF
    ldi   AL, 0xF4
    ldi   A, 0x48
    st    A, [AH:AL]
    ldi   A, 0x49
    st    A, [AH:AL]
    jmp   exit
      
