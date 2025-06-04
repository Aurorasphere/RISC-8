#!/bin/python

reg_map_rev = {
    0: "A", 1: "B", 2: "C", 3: "D", 4: "E",
    5: "SP", 6: "AH", 7: "AL"
}

def reg(n):
    return reg_map_rev.get(n, f"r{n}")

def disassemble_word(pc: int, word: int) -> str:
    op = word & 0b11
    
    if word == 0xFFFF:
        return "halt"
    
    if op == 0b00:
        fn3 = (word >> 2) & 0b111
        rd  = (word >> 5) & 0b111
        rn  = (word >> 8) & 0b111
        rm  = (word >> 11) & 0b111
        fn2 = (word >> 14) & 0b11
        table = {
            (0b00, 0b000): "add",
            (0b01, 0b000): "sub",
            (0b00, 0b001): "and",
            (0b00, 0b010): "or",
            (0b00, 0b011): "xor",
            (0b00, 0b100): "lsl",
            (0b00, 0b101): "lsr",
            (0b01, 0b101): "asr",
            (0b00, 0b110): "cmp",
        }
        mnem = table.get((fn2, fn3), None)
        if mnem:
            return f"{mnem:<6} {reg(rd)}, {reg(rm)}, {reg(rn)}"

    elif op == 0b01:
        fn3 = (word >> 2) & 0b111
        rmd = (word >> 5) & 0b111
        imm = (word >> 8) & 0xFF
        table = {
            0b000: "addi",
            0b001: "ori",
            0b010: "andi",
            0b011: "xori",
            0b100: "lsli",
            0b101: "lsri",
            0b110: "cmpi",
            0b111: "ldi",
        }
        mnem = table.get(fn3, None)
        if mnem:
            return f"{mnem:<6} {reg(rmd)}, 0x{imm:02X}"

    elif op == 0b10:
        fn3 = (word >> 2) & 0b111
        imm = (word >> 5) & 0x7FF
        signed_imm = imm if imm < 0x400 else imm - 0x800  # sign-extend
        table = {
            0b000: "jmp",
            0b001: "jeq",
            0b010: "jneq",
            0b011: "jgt",
            0b100: "jlt",
            0b101: "jegt",
            0b110: "jelt",
            0b111: "jr",
        }
        mnem = table.get(fn3, None)
        if mnem == "jr":
            return "jr"
        else:
            return f"{mnem:<6} rel {signed_imm:+d}"

    elif op == 0b11:
        fn2 = (word >> 2) & 0b11
        if fn2 == 0b00:
            hi = (word >> 11) & 0b111
            lo = (word >> 8) & 0b111
            rd = (word >> 5) & 0b111
            return f"ld     {reg(rd)}, [{reg(hi)}:{reg(lo)}]"
        elif fn2 == 0b01:
            hi = (word >> 11) & 0b111
            lo = (word >> 8) & 0b111
            rm = (word >> 5) & 0b111
            return f"st     {reg(rm)}, [{reg(hi)}:{reg(lo)}]"
        elif fn2 == 0b10:
            imm = (word >> 8) & 0xF
            return f"int    {imm}"
        elif fn2 == 0b11:
            return "iret"

    return f".word 0x{word:04X}"

def disassemble_file(path: str):
    with open(path, 'rb') as f:
        data = f.read(0x20000)  # 128KB 전체 메모리

    print("\n===== Instruction Memory =====")
    for pc in range(0x0000, 0x10000, 2):
        word = data[pc] | (data[pc+1] << 8)
        if word == 0:
            continue
        asm = disassemble_word(pc, word)
        print(f"0x{pc:04X}: {asm:<20} ; 0x{word:04X}, {word:016b}")

    print("\n===== Data Memory (0x10000 ~ 0x1FFFF) =====")
    for addr in range(0x10000, 0x20000, 16):
        chunk = data[addr:addr+16]
        if any(b != 0 for b in chunk):
            hex_bytes = ' '.join(f"{b:02X}" for b in chunk)
            ascii_repr = ''.join(chr(b) if 32 <= b <= 126 else '.' for b in chunk)
            print(f"0x{addr:05X}: {hex_bytes:<47} ; {ascii_repr}")

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        print("사용법: python disassembler.py <파일>")
        exit(1)
    disassemble_file(sys.argv[1])

