import re

def parse_macros(lines):
    macros = {}
    output = []
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith(".macro"):
            match = re.match(r"\.macro\s+(\w+)\s*\(([^)]*)\)", line)
            if not match:
                raise ValueError(f"Invalid macro format: {line}")
            name = match[1]
            params = [p.strip() for p in match[2].split(",") if p.strip()]
            body = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith(".endm"):
                body.append(lines[i])
                i += 1
            macros[name] = (params, body)
        else:
            output.append(lines[i])
        i += 1
    return macros, output

def expand_macros(lines, macros):
    expanded = []
    for line in lines:
        line_strip = line.strip()
        match = re.match(r"(\w+)\s*\(([^)]*)\)", line_strip)
        if match:
            name = match[1]
            args = [a.strip() for a in match[2].split(",")]
            if name not in macros:
                raise ValueError(f"Undefined Macro: {name}")
            params, body = macros[name]
            if len(args) != len(params):
                raise ValueError(f"'{name}' Macro argument invalid: {args}")
            for bline in body:
                for p, a in zip(params, args):
                    bline = bline.replace(f"\\{p}", a)
                expanded.append(bline)
        else:
            expanded.append(line)
    return expanded

def preprocess_macros(lines):
    macros, plain_lines = parse_macros(lines)
    return expand_macros(plain_lines, macros)

def parse_asm(lines):
    lines = preprocess_macros(lines)
    sections = {}
    current_section = None
    global_label = None

    for line in lines:
        line = line.split(";")[0].strip()
        if not line:
            continue

        # global main 같은 진입점 정의
        if line.startswith("global "):
            _, label = line.split(None, 1)
            global_label = label.strip()
            continue

        if line.startswith(".") and line.endswith(":"):
            current_section = line[1:-1]
            sections[current_section] = []
            continue

        if current_section is None:
            raise ValueError(f"섹션이 지정되지 않은 상태에서 명령 발견: {line}")

        if re.match(r"^[a-zA-Z_][a-zA-Z0-9_]*:$", line):
            sections[current_section].append(("label", line[:-1]))
            continue

        if ":" in line and current_section in {"rodata", "data"}:
            addr, rest = map(str.strip, line.split(":", 1))
            sections[current_section].append(("data", addr, rest))
            continue

        sections[current_section].append(("inst", line))

    return {
        "sections": sections,
        "global": global_label
    }

