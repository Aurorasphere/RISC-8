const std = @import("std");

pub const INSTR_MEM_SIZE = 32 * 1024;
pub const DATA_MEM_SIZE = 31 * 1024;

pub var instrmem: [INSTR_MEM_SIZE]u8 = [_]u8{0} ** INSTR_MEM_SIZE; // 0x0000 ~ 0x7FFF
pub var datamem: [DATA_MEM_SIZE]u8 = [_]u8{0} ** DATA_MEM_SIZE; // 0x8000 ~ 0xFBFF

pub const IO_TTY_OUT: u16 = 0xFF00;
pub const IO_TTY_IN: u16 = 0xFF01;
pub const IO_TTY_STATUS: u16 = 0xFF02;

pub var kb_buffer: ?u8 = null;
pub var interrupt_pending: bool = false;

pub fn write_key(byte: u8) void {
    kb_buffer = byte;
    interrupt_pending = true;
}

pub fn has_input() bool {
    return kb_buffer != null;
}

pub fn tty_input() u8 {
    const value = kb_buffer orelse 0;
    kb_buffer = null;
    return value;
}

pub fn tty_output(byte: u8) void {
    std.debug.print("{c}", .{byte});
}

pub fn fetch_instr(addr: u16) u8 {
    return instrmem[addr];
}

pub fn read_data(addr: u16) u8 {
    if (addr < 0xC000) {
        return datamem[addr - 0x8000];
    }
    return switch (addr) {
        IO_TTY_IN => tty_input(),
        IO_TTY_STATUS => if (has_input()) 1 else 0,
        else => 0,
    };
}

pub fn write_data(addr: u16, value: u8) void {
    if (addr < 0xC000) {
        datamem[addr - 0x8000] = value;
        return;
    }
    switch (addr) {
        IO_TTY_OUT => tty_output(value),
        else => {},
    }
}
