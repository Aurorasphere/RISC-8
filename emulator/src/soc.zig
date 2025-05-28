const std = @import("std");
const dev = @import("device.zig");

pub const INSTR_MEM_SIZE = 64 * 1024; // 32KB
pub const DATA_MEM_SIZE = 64 * 1024; // 24KB

const STACK_SIZE = 0xFF;
const STACK_START = 0x0000;

const IVT_SIZE = 32;
const IVT_START = STACK_START + STACK_SIZE + 1;

pub const sys_on_chip = struct {
    pc: u16 = 0,
    regfile: [8]u8 = .{0} ** 8,
    instr_mem: [INSTR_MEM_SIZE]u8 = .{0} ** INSTR_MEM_SIZE,
    data_mem: [DATA_MEM_SIZE]u8 = .{0} ** DATA_MEM_SIZE,
    ivt: [16]u16 = .{
        0xF800, 0xF880, 0xF900, 0xF980,
        0xFA00, 0xFA80, 0xFB00, 0xFB80,
        0xFC00, 0xFC80, 0xFD00, 0xFD80,
        0xFE00, 0xFE80, 0xFF00, 0xFF80,
    },
    statusreg: u8 = 0,
    halted: bool = false,
    irq: bool = false,
};

// Register Number
const regs = enum(usize) {
    A = 0,
    B = 1,
    C = 2,
    D = 3,
    E = 4,
    SP = 5,
    AH = 6,
    AL = 7,
};

const flags = enum(u8) {
    EQ = 0b0000_0001,
    LT = 0b0000_0010,
    GT = 0b0000_0100,
    HALTED = 0b0001_0000,
    INTPEND = 0b0100_0000,
    INTMASK = 0b1000_0000,
};

const opcode = enum(u2) {
    R = 0b00,
    I = 0b01,
    J = 0b10,
    P = 0b11,
};

const aluop = enum {
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

fn aluop_decode(fn3: u3, fn2: u2) aluop {
    switch (fn2) {
        0b00 => switch (fn3) {
            0b000 => return .add,
            0b001 => return .or_op,
            0b010 => return .and_op,
            0b011 => return .xor,
            0b100 => return .lsl,
            0b101 => return .lsr,
            0b110 => return .cmp,
            else => return .add,
        },
        0b10 => switch (fn3) {
            0b000 => return .sub,
            0b101 => return .asr,
            else => return .add,
        },
        else => return .add,
    }
}

fn alu(soc: *sys_on_chip, op: aluop, A: u8, B: u8) u8 {
    var result: u8 = 0;

    switch (op) {
        .add => result = A + B,
        .sub => result = A - B,
        .or_op => result = A | B,
        .and_op => result = A & B,
        .xor => result = A ^ B,
        .lsl => result = A << @truncate(B),
        .lsr => result = A >> @truncate(B),
        .asr => result = @intCast(@as(i8, @intCast(A)) >> @truncate(B)),
        .cmp => {
            if (A == B) {
                soc.statusreg |= @intFromEnum(flags.EQ);
            } else {
                soc.statusreg &= ~@intFromEnum(flags.EQ);
            }
            if (A < B) {
                soc.statusreg |= @intFromEnum(flags.LT);
            } else {
                soc.statusreg &= ~@intFromEnum(flags.LT);
            }
            if (A > B) {
                soc.statusreg |= @intFromEnum(flags.GT);
            } else {
                soc.statusreg &= ~@intFromEnum(flags.GT);
            }
        },
    }
    return result;
}

fn execR(soc: *sys_on_chip, instr: u16) void {
    const fn3: u3 = @intCast((instr >> 2) & 0b111);
    const Rd: u3 = @intCast((instr >> 5) & 0b111);
    const Rn: u3 = @intCast((instr >> 8) & 0b111);
    const Rm: u3 = @intCast((instr >> 11) & 0b111);
    const fn2: u2 = @intCast((instr >> 14) & 0b11);

    const result = alu(soc, aluop_decode(fn3, fn2), soc.regfile[Rm], soc.regfile[Rn]);
    if (aluop_decode(fn3, fn2) != .cmp) {
        soc.regfile[Rd] = result;
    }
}

fn execI(soc: *sys_on_chip, instr: u16) void {
    const fn3: u3 = @intCast((instr >> 2) & 0b111);
    const Rmd: u3 = @intCast((instr >> 5) & 0b111);
    const imm: u8 = @intCast((instr >> 8) & 0b1111_1111);

    switch (fn3) {
        0b111 => {
            soc.regfile[Rmd] = imm;
        },
        else => {
            const result = alu(soc, aluop_decode(fn3, 0), soc.regfile[Rmd], imm);
            if (aluop_decode(fn3, 0) != .cmp) {
                soc.regfile[Rmd] = result;
            }
        },
    }
}

fn sign_extend11(x: u11) i16 {
    return @as(i16, (@as(i16, x) << 5)) >> 5;
}

fn execJ(soc: *sys_on_chip, instr: u16) void {
    const fn3: u3 = @intCast((instr >> 2) & 0b111);
    const offset: u11 = @intCast((instr >> 5) & 0b111_1111_1111);

    const rel_offset: i16 = sign_extend11(offset) << 1;
    const ah = soc.regfile[@intFromEnum(regs.AH)];
    const al = soc.regfile[@intFromEnum(regs.AL)];
    const abs_addr: u16 = (@as(u16, ah) << 8) | al;

    switch (fn3) {
        0b000 => {
            soc.pc = @as(u16, @intCast(@as(i16, @intCast(soc.pc)) + rel_offset));
        },
        0b001 => {
            if ((soc.statusreg & @intFromEnum(flags.EQ)) != 0) {
                soc.pc = @as(u16, @intCast(@as(i16, @intCast(soc.pc)) + rel_offset));
            }
        },
        0b010 => {
            if ((soc.statusreg & @intFromEnum(flags.EQ)) == 0) {
                soc.pc = @as(u16, @intCast(@as(i16, @intCast(soc.pc)) + rel_offset));
            }
        },
        0b011 => {
            if ((soc.statusreg & @intFromEnum(flags.GT)) != 0) {
                soc.pc = @as(u16, @intCast(@as(i16, @intCast(soc.pc)) + rel_offset));
            }
        },
        0b100 => {
            if ((soc.statusreg & @intFromEnum(flags.LT)) != 0) {
                soc.pc = @as(u16, @intCast(@as(i16, @intCast(soc.pc)) + rel_offset));
            }
        },

        0b101 => {
            if ((soc.statusreg & @intFromEnum(flags.GT)) != 0) {
                soc.pc = @as(u16, @intCast(@as(i16, @intCast(soc.pc)) + rel_offset));
            } else if ((soc.statusreg & @intFromEnum(flags.EQ)) != 0) {
                soc.pc = @as(u16, @intCast(@as(i16, @intCast(soc.pc)) + rel_offset));
            }
        },
        0b110 => {
            if ((soc.statusreg & @intFromEnum(flags.LT)) != 0) {
                soc.pc = @as(u16, @intCast(@as(i16, @intCast(soc.pc)) + rel_offset));
            } else if ((soc.statusreg & @intFromEnum(flags.EQ)) != 0) {
                soc.pc = @as(u16, @intCast(@as(i16, @intCast(soc.pc)) + rel_offset));
            }
        },
        0b111 => {
            soc.pc = abs_addr;
        },
    }
}

fn execP(soc: *sys_on_chip, instr: u16) void {
    const fn3: u3 = @intCast((instr >> 2) & 0b111);
    const Rd: u3 = @intCast((instr >> 5) & 0b111);
    const hi: u3 = @intCast((instr >> 11) & 0b111);
    const lo: u3 = @intCast((instr >> 8) & 0b111);
    const intnum: u4 = @intCast((instr >> 8) & 0b1111);

    switch (fn3) {
        0b000 => {
            const ah = soc.regfile[hi];
            const al = soc.regfile[lo];
            const addr: u16 = (@as(u16, ah) << 8) | al;

            if (addr >= dev.IO_BASE) {
                const dev_id: usize = addr - dev.IO_BASE;
                if (dev_id < dev.MAX_DEVICE and dev.devices[dev_id].readable) {
                    const devmain = dev.devices[dev_id];
                    if (devmain.read) |read_fn| {
                        soc.regfile[Rd] = read_fn();
                    }
                }
            } else {
                soc.regfile[Rd] = soc.data_mem[addr];
            }
        },
        0b001 => {
            const ah = soc.regfile[hi];
            const al = soc.regfile[lo];
            const addr: u16 = (@as(u16, ah) << 8) | al;

            if (addr >= dev.IO_BASE) {
                const dev_id: usize = addr - dev.IO_BASE;
                if (dev_id < dev.MAX_DEVICE) {
                    const devmain = dev.devices[dev_id];
                    if (devmain.write) |write_fn| {
                        write_fn(soc.regfile[Rd]);
                    }
                }
            } else {
                soc.data_mem[addr] = soc.regfile[Rd];
            }
        },
        0b010 => { // INT
            if (soc.statusreg & @intFromEnum(flags.INTMASK) != 0) {
                return;
            }
            const targetaddr: u16 = soc.ivt[intnum];
            soc.regfile[@intFromEnum(regs.AH)] = @truncate(soc.pc >> 8);
            soc.regfile[@intFromEnum(regs.AL)] = @truncate(soc.pc & 0x00FF);

            soc.statusreg |= @intFromEnum(flags.INTPEND);
            soc.statusreg |= @intFromEnum(flags.INTMASK);
            soc.pc = targetaddr;
        },
        0b011 => { // IRET
            const ah = soc.regfile[@intFromEnum(regs.AH)];
            const al = soc.regfile[@intFromEnum(regs.AL)];
            soc.pc = (@as(u16, ah) << 8) | al;
            soc.statusreg &= ~@intFromEnum(flags.INTPEND);
            soc.statusreg &= ~@intFromEnum(flags.INTMASK);
        },
        else => return,
    }
    if (instr == 0xFFFF) {
        soc.statusreg |= @intFromEnum(flags.HALTED);
        soc.halted = true;
    }
}

pub fn SoC_run(soc: *sys_on_chip) void {
    while (!soc.halted) {
        dev.poll_keyboard();
        dev.poll_timer();

        // IRQ 감지
        for (0..dev.MAX_DEVICE) |i| {
            if (i >= dev.MAX_DEVICE) break;
            const d = dev.devices[i];
            if (d.is_interrupting != null and d.is_interrupting.?()) {
                if ((soc.statusreg & @intFromEnum(flags.INTMASK)) == 0) {
                    // 인터럽트 처리
                    const irq_num: u4 = switch (d.id) {
                        .keyboard => dev.keyboard_irq_num,
                        .timer => dev.timer_irq_num,
                        else => continue,
                    };
                    const target = soc.ivt[irq_num];
                    // PC 저장
                    soc.regfile[@intFromEnum(regs.AH)] = @truncate(soc.pc >> 8);
                    soc.regfile[@intFromEnum(regs.AL)] = @truncate(soc.pc & 0xFF);
                    // 상태 갱신
                    soc.statusreg |= @intFromEnum(flags.INTPEND);
                    soc.statusreg |= @intFromEnum(flags.INTMASK);
                    soc.pc = target;
                    break;
                }
            }
        }

        // 명령어 fetch-decode-execute (예시)
        const instr: u16 = @as(u16, soc.instr_mem[soc.pc]) |
            (@as(u16, soc.instr_mem[soc.pc + 1]) << 8);
        soc.pc += 2;

        const opc: u2 = @intCast(instr & 0b11);
        switch (opc) {
            0b00 => execR(soc, instr),
            0b01 => execI(soc, instr),
            0b10 => execJ(soc, instr),
            0b11 => execP(soc, instr),
        }
    }

    std.debug.print("SoC Halted. Final PC Value: .{}", .{soc.pc});
}
