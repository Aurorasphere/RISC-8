const mem = @import("memory.zig");

const ST_EQ: u8 = 0b00000001;
const ST_GT: u8 = 0b00000010;
const ST_LT: u8 = 0b00000100;
const ST_SIGN: u8 = 0b00001000;
const INT_MASK: u8 = 0b10000000;

pub var CPU = struct {
    var pc: u16 = 0;
    var statusreg: u8 = 0;
    var regs: [8]u8 = .{0};
    const ivr: [16]u16 = .{0};

    fn get_addr() u16 {
        return (@as(u16, regs[6]) << 8) | @as(u16, regs[7]);
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

    fn alu(a: u8, b: u8, opcode: alu_op) u8 {
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
                    statusreg |= ST_GT;
                } else {
                    statusreg &= !ST_GT;
                }

                if (a < b) {
                    statusreg |= ST_LT;
                } else {
                    statusreg &= !ST_LT;
                }

                if (a == b) {
                    statusreg |= ST_EQ;
                } else {
                    statusreg &= !ST_EQ;
                }
            },
            else => result = 0,
        }
        if ((result & 0b10000000) != 0) {
            statusreg |= ST_SIGN;
        } else {
            statusreg &= !ST_SIGN;
        }

        return result;
    }

    fn execR(instr: u16) void {
        const Rmd: u3 = @intCast((instr >> 6) & 0b111);
        const Rn: u3 = @intCast((instr >> 9) & 0b111);

        regs[Rmd] = alu(regs[Rmd], regs[Rn], aluop_decode(instr));
    }

    fn execI(instr: u16) void {
        const opcode: u3 = @intCast(instr & 0b111);
        const Rmd: u3 = @intCast((instr >> 6) & 0b111);
        const imm: u7 = @intCast((instr >> 9) & 0b111111111);
        const fn3: u3 = @intCast((instr >> 3) & 0b111);
        const addr = get_addr();
        switch (opcode) {
            0b001 => {
                regs[Rmd] = alu(regs[Rmd], @intCast(imm), aluop_decode(instr));
            },
            0b101 => {
                switch (fn3) {
                    0b000 => regs[Rmd] = mem.memory[addr],
                    0b001 => mem.memory[addr] = regs[Rmd],
                    0b010 => {
                        const offset = @as(i8, @bitCast(@as(u7, imm)));
                        regs[6] = @intCast(pc >> 8);
                        regs[7] = @intCast(pc & 0xFF);
                        pc = Rmd + (@as(i8, @bitCast(@as(u7, offset))) << 1);
                    },
                    else => return,
                }
            },
        }
    }

    fn execJ(instr: u16) void {
        const fn3: u3 = @intCast((instr >> 3) & 0b111);
        const addr = get_addr();
        switch (fn3) {
            0b000 => pc = addr,
            0b001 => {
                if ((statusreg & ST_EQ) != 0) pc = addr;
            },
            0b010 => {
                if ((statusreg & ST_EQ) == 0) pc = addr;
            },
            0b011 => {
                if ((statusreg & ST_GT) != 0) pc = addr;
            },
            0b100 => {
                if ((statusreg & ST_LT) != 0) pc = addr;
            },
            0b101 => {
                if ((statusreg & (ST_EQ | ST_GT)) != 0) pc = addr;
            },
            0b110 => {
                if ((statusreg & (ST_EQ | ST_LT)) != 0) pc = addr;
            },
            else => return,
        }
    }

    fn execT(instr: u32) void {
        const fn3: u3 = @intCast(instr & 0b111);
        const Rmd: u3 = @intCast((instr >> 9) & 0b111);
        const imm: u8 = @intCast((instr >> 6) & 0b11111111);

        switch (fn3) {
            0b000 => {
                regs[5] -= 1;
                mem.memory[regs[5]] = regs[Rmd];
            },
            0b001 => {
                regs[Rmd] = mem.memory[regs[5]];
                regs[5] += 1;
            },
            0b010 => {
                if (!statusreg.INT_MASK) {
                    const imm_4bit: usize = @intCast(imm & 0b1111);
                    regs[6] = @intCast(pc >> 8);
                    regs[7] = @intCast(pc & 0xFF);
                    pc = ivr[imm_4bit];
                } else {
                    return;
                }
            },
            0b011 => {
                var ret_pc_value: u16 = 0;
                ret_pc_value = regs[6] << 8;
                ret_pc_value |= regs[7];
                pc = ret_pc_value;
            },

            else => return,
        }
    }
};

fn CPU(addr: u16, data: u8, nmi: bool) u8 {}
