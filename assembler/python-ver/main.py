#!/bin/python

import os
import struct
from parser import parse_asm
from encoder import (
    build_label_table,
    encode_instr_section,
    encode_data_section,
    to_le_bytes,
)

MEMORY_SIZE = 128 * 1024
INSTR_MEM_BASE = 0x0000
DATA_MEM_BASE = 0x10000


def write_binary(path: str, instr_blob: list[int], data_dict: dict[int, int]):
    binary = bytearray([0] * MEMORY_SIZE)

    # Instructions
    for i, b in enumerate(instr_blob):
        binary[INSTR_MEM_BASE + i] = b

    # Data
    for addr, val in data_dict.items():
        binary[DATA_MEM_BASE + addr] = val

    with open(path, 'wb') as f:
        f.write(binary)

    print(f"✅ 바이너리 저장 완료: {path} ({len(binary)} bytes)")


def main():
    import sys
    if len(sys.argv) != 3:
        print("사용법: python main.py <입력파일> <출력파일>")
        exit(1)

    input_file, output_file = sys.argv[1], sys.argv[2]

    with open(input_file) as f:
        lines = [line.strip() for line in f if line.strip()]

    parsed = parse_asm(lines)
    sections = parsed["sections"]

    instr = sections.get("instr", [])
    data = sections.get("data", [])

    label_map = build_label_table(instr)
    instr_blob = encode_instr_section(instr, label_map)
    data_dict = encode_data_section(data)

    write_binary(output_file, instr_blob, data_dict)


if __name__ == "__main__":
    main()

