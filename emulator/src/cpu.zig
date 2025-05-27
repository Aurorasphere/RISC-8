const std = @import("std");
const mem = @import("memory.zig");

const ST_EQ: u8 = 0b00000001;
const ST_GT: u8 = 0b00000010;
const ST_LT: u8 = 0b00000100;
const ST_SIGN: u8 = 0b00001000;
const INT_MASK: u8 = 0b10000000;

pub const CPU = struct {
    pc: u16 = 0,
    statusreg: u8 = 0,
    regs: [8]u8 = [_]u8{0} ** 8,
    ivr: [16]u16 = [_]u16{0} ** 16,
    halted: bool = false,
};

fn sign_extend_7_to_8(val: u7) i8 {
    if ((val & 0b0100_0000) != 0) {
        return @as(i8, @bitCast(val | 0b1000_0000));
    } else {
        return @as(i8, @bitCast(val));
    }
}
pub fn get_addr(cpu: *CPU) u16 {
    return (@as(u16, cpu.regs[6]) << 8) | @as(u16, cpu.regs[7]);
}

const alu_op = enum {
    add,
    sub,
    or_op,
    and_op,
    xor,
    lsl,
    lsr,
    asr,
    cmp,
};

fn aluop_decode(instr: u16) alu_op {
    const opcode: u3 = @intCast(instr & 0b111);
    const fn3: u3 = @intCast((instr >> 3) & 0b111);
    var fn4: u4 = @intCast((instr >> 12) & 0b1111);

    if (opcode == 1) fn4 = 0; // immediate instruction

    switch (fn3) {
        0b000 => switch (fn4) {
            0b0000 => return .add,
            0b1000 => return .sub,
            else => return .add,
        },
        0b001 => return .or_op,
        0b010 => return .and_op,
        0b011 => return .xor,
        0b100 => return .lsl,
        0b101 => switch (fn4) {
            0b0000 => return .lsr,
            0b1000 => return .asr,
            else => return .lsr,
        },
        0b110 => return .cmp,
        else => return .add,
    }
}

fn alu(a: u8, b: u8, opcode: alu_op, cpu: *CPU) u8 {
    var result: u8 = 0;
    switch (opcode) {
        .add => result = a + b,
        .sub => result = a - b,
        .or_op => result = a | b,
        .and_op => result = a & b,
        .xor => result = a ^ b,
        .lsl => result = a << @truncate(b),
        .lsr => result = a >> @truncate(b),
        .asr => result = @bitCast(@as(i8, @bitCast(a)) >> @truncate(b & 0x07)),
        .cmp => {
            if (a > b) {
                cpu.statusreg |= ST_GT;
            } else {
                cpu.statusreg &= ~ST_GT;
            }

            if (a < b) {
                cpu.statusreg |= ST_LT;
            } else {
                cpu.statusreg &= ~ST_LT;
            }

            if (a == b) {
                cpu.statusreg |= ST_EQ;
            } else {
                cpu.statusreg &= ~ST_EQ;
            }
        },
    }
    if ((result & 0b10000000) != 0) {
        cpu.statusreg |= ST_SIGN;
    } else {
        cpu.statusreg &= ~ST_SIGN;
    }

    return result;
}

fn execR(instr: u16, cpu: *CPU) void {
    const Rmd: u3 = @intCast((instr >> 6) & 0b111);
    const Rn: u3 = @intCast((instr >> 9) & 0b111);

    cpu.regs[Rmd] = alu(cpu.regs[Rmd], cpu.regs[Rn], aluop_decode(instr), cpu);
}

fn execI(instr: u16, cpu: *CPU) void {
    const opcode: u3 = @intCast(instr & 0b111);
    const Rmd: u3 = @intCast((instr >> 6) & 0b111);
    const imm: u7 = @intCast((instr >> 9) & 0b111111111);
    const fn3: u3 = @intCast((instr >> 3) & 0b111);
    const addr = get_addr(cpu);

    switch (opcode) {
        0b001 => {
            cpu.regs[Rmd] = alu(cpu.regs[Rmd], @intCast(imm), aluop_decode(instr), cpu);
        },
        0b101 => {
            switch (fn3) {
                0b000 => cpu.regs[Rmd] = mem.read_data(addr),
                0b001 => mem.write_data(addr, cpu.regs[Rmd]),
                else => return,
            }
        },
        else => return,
    }
}

fn execJ(instr: u16, cpu: *CPU) void {
    const fn3: u3 = @intCast((instr >> 3) & 0b111);
    const addr = get_addr(cpu);
    switch (fn3) {
        0b000 => cpu.pc = addr,
        0b001 => {
            if ((cpu.statusreg & ST_EQ) != 0) cpu.pc = addr;
        },
        0b010 => {
            if ((cpu.statusreg & ST_EQ) == 0) cpu.pc = addr;
        },
        0b011 => {
            if ((cpu.statusreg & ST_GT) != 0) cpu.pc = addr;
        },
        0b100 => {
            if ((cpu.statusreg & ST_LT) != 0) cpu.pc = addr;
        },
        0b101 => {
            if ((cpu.statusreg & (ST_EQ | ST_GT)) != 0) cpu.pc = addr;
        },
        0b110 => {
            if ((cpu.statusreg & (ST_EQ | ST_LT)) != 0) cpu.pc = addr;
        },
        else => return,
    }
}

fn execT(instr: u16, cpu: *CPU) void {
    const fn3: u3 = @intCast(instr & 0b111);
    const Rmd: u3 = @intCast((instr >> 9) & 0b111);
    const imm: u8 = @intCast((instr >> 6) & 0b11111111);

    switch (fn3) {
        0b000 => {
            cpu.regs[5] -= 1;
            mem.write_data(@intCast(cpu.regs[5]), cpu.regs[Rmd]);
        },
        0b001 => {
            cpu.regs[Rmd] = mem.read_data(cpu.regs[5]);
            cpu.regs[5] += 1;
        },
        0b010 => {
            if ((cpu.statusreg & INT_MASK) == 0) {
                cpu.statusreg |= INT_MASK;
                const imm_4bit: usize = @intCast(imm & 0b1111);
                cpu.regs[6] = @intCast(cpu.pc >> 8);
                cpu.regs[7] = @intCast(cpu.pc & 0xFF);
                cpu.pc = cpu.ivr[imm_4bit];
            } else {
                return;
            }
        },
        0b011 => {
            const hi: u16 = @as(u16, @intCast(cpu.regs[6])) << 8;
            const lo: u16 = @intCast(cpu.regs[7]);
            const ret_pc_value: u16 = hi | lo;

            cpu.pc = ret_pc_value;
            cpu.statusreg &= ~INT_MASK;
        },

        else => return,
    }
}

pub fn step(cpu: *CPU) void {
    const instr_hi = mem.fetch_instr(cpu.pc);
    const instr_lo = mem.fetch_instr(cpu.pc + 1);
    const instr: u16 = (@as(u16, instr_lo) << 8) | @as(u16, instr_hi);

    if (instr == 0xFFFF) {
        cpu.halted = true;
        return;
    }

    const opcode: u3 = @intCast(instr & 0b111);

    switch (opcode) {
        0b000 => execR(instr, cpu),
        0b001, 0b101 => execI(instr, cpu),
        0b010 => execJ(instr, cpu),
        0b110 => execT(instr, cpu),
        else => {
            std.debug.print("Invalid opcode {b}\n", .{opcode});
        },
    }

    cpu.pc += 2;
}

pub fn CPU_run(nmi: bool, cpu: *CPU) void {
    while (!cpu.halted) {
        if (nmi) {
            cpu.regs[6] = @intCast(cpu.pc >> 8);
            cpu.regs[7] = @intCast(cpu.pc & 0xFF);

            cpu.pc = cpu.ivr[0x0];
        }
        if (mem.interrupt_pending and (cpu.statusreg & INT_MASK) == 0) { // keyboard int
            cpu.regs[6] = @intCast(cpu.pc >> 8);
            cpu.regs[7] = @intCast(cpu.pc & 0xFF);

            cpu.pc = cpu.ivr[0x1];
            mem.interrupt_pending = false;
        }
        step(cpu);
    }
    std.debug.print("CPU Halted. Final PC: 0x{X:04}\n", .{cpu.pc});
}
