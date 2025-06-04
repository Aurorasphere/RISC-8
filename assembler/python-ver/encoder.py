import ast
import re

reg_map = {
    "A": 0, "B": 1, "C": 2, "D": 3, "E": 4,
    "SP": 5, "AH": 6, "AL": 7
}

def to_le_bytes(word: int) -> list[int]:
    return [word & 0xFF, word >> 8]

def build_label_table(instr_section):
    pc = 0
    label_map = {}
    for kind, value in instr_section:
        if kind == "label":
            label_map[value] = pc
        elif kind == "inst":
            pc += 2
    return label_map

def calc_relative_offset(from_pc: int, to_addr: int) -> int:
    offset = (to_addr - from_pc) // 2
    if not -1024 <= offset < 1024:  # 11비트 signed range
        raise ValueError(f"Offset out of range: {offset}")
    return offset & 0x7FF  # 11비트로 마스킹

# Encode R-Type instruction 
def encodeR(fn2: int, rd: str, rm: str, rn: str, fn3: int):
    assert 0 <= fn2 < 4, f"fn3 value {fn2} must be lesser than 2-bit maximum"
    assert 0 <= fn3 < 8, f"fn3 value {fn3} must be lesser than 3-bit maximum"
    return (fn2 << 14) | (reg_map[rm] << 11) | (reg_map[rn] << 8) | (reg_map[rd] << 5) | (fn3 << 2) | 0b00
def r_add(rd, rm, rn): return encodeR(0b00, rd, rm, rn, 0b000)
def r_sub(rd, rm, rn): return encodeR(0b10, rd, rm, rn, 0b000)
def r_and(rd, rm, rn): return encodeR(0b00, rd, rm, rn, 0b001)
def r_or(rd, rm, rn):  return encodeR(0b00, rd, rm, rn, 0b010)
def r_xor(rd, rm, rn): return encodeR(0b00, rd, rm, rn, 0b011)
def r_lsl(rd, rm, rn): return encodeR(0b00, rd, rm, rn, 0b100)
def r_lsr(rd, rm, rn): return encodeR(0b00, rd, rm, rn, 0b101)
def r_asr(rd, rm, rn): return encodeR(0b10, rd, rm, rn, 0b101)
def r_cmp(rd, rm, rn): return encodeR(0b00, rd, rm, rn, 0b110)

# Encode I-Type instruction 
def encodeI(rmd: str, imm: int, fn3: int) -> int:
    assert 0 <= fn3 < 8
    return (imm & 0xFF) << 8 | (reg_map[rmd] << 5) | (fn3 << 2) | 0b01
def i_addi(rmd, imm): return encodeI(rmd, imm, 0b000)
def i_ori(rmd, imm):  return encodeI(rmd, imm, 0b001)
def i_andi(rmd, imm): return encodeI(rmd, imm, 0b010)
def i_xori(rmd, imm): return encodeI(rmd, imm, 0b011)
def i_lsli(rmd, imm): return encodeI(rmd, imm, 0b100)
def i_lsri(rmd, imm): return encodeI(rmd, imm, 0b101)
def i_cmpi(rmd, imm): return encodeI(rmd, imm, 0b110)
def i_ldi(rmd, imm):  return encodeI(rmd, imm, 0b111)

# Encode J-Type instruction 
def encodeJ(imm: int, fn3: int): 
    assert 0 <= fn3 < 8
    return ((imm & 0x7FF) << 5) | (fn3 << 2) | 0b10 
def j_jmp(imm): return encodeJ(imm, 0b000)
def j_jeq(imm): return encodeJ(imm, 0b001)
def j_jneq(imm): return encodeJ(imm, 0b010)
def j_jgt(imm): return encodeJ(imm, 0b011)
def j_jlt(imm): return encodeJ(imm, 0b100)
def j_jegt(imm): return encodeJ(imm, 0b101)
def j_jelt(imm): return encodeJ(imm, 0b110)
def j_jr(): return encodeJ(0, 0b111)

# Encode T-Type instruction
def encode_ld(hi: str, lo: str, rd: str):
    return (reg_map[hi] << 11) | (reg_map[lo] << 8) | (reg_map[rd] << 5) | (0 << 2) | 0b11
def encode_st(hi: str, lo: str, rm: str):
    return (reg_map[hi] << 11) | (reg_map[lo] << 8) | (reg_map[rm] << 5) | (1 << 2) | 0b11
def encode_int(intimm: int):
    return ((intimm & 0b1111) << 8) | (2 << 2) | 0b11 
def encode_iret():
    return (3 << 2) | 0b11
def encode_halt() -> int:
    return 0xFFFF

def encode_single_instruction(line: str, pc: int, label_map: dict) -> int:
    parts = line.strip().replace(",", "").split()
    op = parts[0].lower()
    args = parts[1:]

    if op == "add":
        return r_add(args[0], args[1], args[2])
    elif op == "sub":
        return r_sub(args[0], args[1], args[2])
    elif op == "or": 
        return r_or(args[0], args[1], args[2])
    elif op == "and":
        return r_and(args[0], args[1], args[2])
    elif op == "xor":
        return r_xor(args[0], args[1], args[2])
    elif op == "lsl":
        return r_lsl(args[0], args[1], args[2])
    elif op == "lsr":
        return r_lsr(args[0], args[1], args[2])
    elif op == "asr":
        return r_asr(args[0], args[1], args[2])
    elif op == "cmp":
        return r_cmp(args[0], args[1], args[2])
    elif op == "addi":
        return i_addi(args[0], int(args[1], 0))
    elif op == "ori":
        return i_ori(args[0], int(args[1], 0))
    elif op == "andi":
        return i_andi(args[0], int(args[1], 0))
    elif op == "xori":
        return i_xori(args[0], int(args[1], 0))
    elif op == "lsli":
        return i_lsli(args[0], int(args[1], 0))
    elif op == "lsri":
        return i_lsri(args[0], int(args[1], 0))
    elif op == "cmpi":
        return i_cmpi(args[0], int(args[1], 0))
    elif op == "ldi":
        return i_ldi(args[0], int(args[1], 0))
    elif op == "jmp":
        target_pc = label_map[args[0]]
        offset = calc_relative_offset(pc, target_pc)
        return j_jmp(offset)

    elif op == "jeq":
        target_pc = label_map[args[0]]
        offset = calc_relative_offset(pc, target_pc)
        return j_jeq(offset)

    elif op == "jneq":
        target_pc = label_map[args[0]]
        offset = calc_relative_offset(pc, target_pc)
        return j_jneq(offset)

    elif op == "jgt":
        target_pc = label_map[args[0]]
        offset = calc_relative_offset(pc, target_pc)
        return j_jgt(offset)

    elif op == "jlt":
        target_pc = label_map[args[0]]
        offset = calc_relative_offset(pc, target_pc)
        return j_jlt(offset)

    elif op == "jegt":
        target_pc = label_map[args[0]]
        offset = calc_relative_offset(pc, target_pc)
        return j_jegt(offset)

    elif op == "jelt":
        target_pc = label_map[args[0]]
        offset = calc_relative_offset(pc, target_pc)
        return j_jelt(offset)

    elif op == "jr":
        return j_jr()
    elif op == "ld":
        # ld A, [AH:AL]
        hi, lo = args[1].removeprefix("[").removesuffix("]").split(":")
        return encode_ld(hi, lo, args[0])
    elif op == "st":
        # st A, [AH:AL]
        hi, lo = args[1].removeprefix("[").removesuffix("]").split(":")
        return encode_st(hi, lo, args[0])
    elif op == "int":
        return encode_int(int(args[0], 0))
    elif op == "iret":
        return encode_iret()
    elif op == "halt":
        return encode_halt()
    else:
        raise ValueError(f"Unsupported instruction: {line}")

def encode_instr_section(instr_section, label_map):
    pc = 0
    code = []

    for kind, value in instr_section:
        if kind == "label":
            continue
        elif kind == "inst":
            word = encode_single_instruction(value, pc, label_map)
            code.extend(to_le_bytes(word))
            pc += 2

    return code

def encode_data_section(data_section):
    result = {}
    for kind, addr, value in data_section:
        if "str" in value:
            start = int(addr, 0)

            match = re.search(r'str\s+((?P<quote>[\'"])(?:\\.|(?!\2).)*\2)', value)
            if not match:
                raise SyntaxError(f"문자열 리터럴을 찾을 수 없습니다: {value}")

            string_literal = match.group(1)
            string = ast.literal_eval(string_literal)

            for i, ch in enumerate(string.encode("utf-8")):
                result[start + i] = ch

        elif kind == "data":
            result[int(addr, 0)] = int(value, 0)
    return result
