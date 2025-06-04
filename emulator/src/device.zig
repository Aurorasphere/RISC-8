const std = @import("std");
const SoC = @import("soc.zig");
const print = std.debug.print;

pub const MAX_DEVICE = 16;
pub const IO_BASE: u16 = 0xFFF0;

pub const keyboard_irq_num: u4 = 0x0;
pub const timer_irq_num: u4 = 0x1;

pub const DeviceID = enum(u4) {
    keyboard = 0,
    timer = 1,
    reserved_input1 = 2,
    reserved_input2 = 3,
    tty_out = 4,
    tty_status = 5,
    reserved_output1 = 6,
    reserved_output2 = 7,
    reserved_output3 = 8,
    reserved_output4 = 9,
    reserved_output5 = 10,
    reserved_output6 = 11,
    reserved_output7 = 12,
    reserved_output8 = 13,
    reserved_output9 = 14,
    reserved_output10 = 15,
};

pub const Device = struct {
    id: DeviceID,
    readable: bool,

    read: ?*const fn () u8 = null,
    write: ?*const fn (data: u8) void = null,
    is_interrupting: ?*const fn () bool = null,
};

pub var devices: []const Device = &[_]Device{
    .{ .id = .keyboard, .readable = true, .read = keyboard_read, .write = null, .is_interrupting = keyboard_interrupting },
    .{ .id = .timer, .readable = true, .read = timer_read, .write = null, .is_interrupting = timer_interrupting },
    .{ .id = .reserved_input1, .readable = true, .read = null, .write = null, .is_interrupting = null },
    .{ .id = .reserved_input2, .readable = true, .read = null, .write = null, .is_interrupting = null },

    .{ .id = .tty_out, .readable = false, .read = null, .write = tty_out_write, .is_interrupting = null },
    .{ .id = .tty_status, .readable = false, .read = null, .write = null, .is_interrupting = null },
    .{ .id = .reserved_output1, .readable = false, .read = null, .write = null, .is_interrupting = null },
    .{ .id = .reserved_output2, .readable = false, .read = null, .write = null, .is_interrupting = null },
    .{ .id = .reserved_output3, .readable = false, .read = null, .write = null, .is_interrupting = null },
    .{ .id = .reserved_output4, .readable = false, .read = null, .write = null, .is_interrupting = null },
    .{ .id = .reserved_output5, .readable = false, .read = null, .write = null, .is_interrupting = null },
    .{ .id = .reserved_output6, .readable = false, .read = null, .write = null, .is_interrupting = null },
    .{ .id = .reserved_output7, .readable = false, .read = null, .write = null, .is_interrupting = null },
    .{ .id = .reserved_output8, .readable = false, .read = null, .write = null, .is_interrupting = null },
    .{ .id = .reserved_output9, .readable = false, .read = null, .write = null, .is_interrupting = null },
    .{ .id = .reserved_output10, .readable = false, .read = null, .write = null, .is_interrupting = null },
};

// Keyboard
var keyboard_buffer: ?u8 = null;

pub fn keyboard_read() u8 {
    return keyboard_buffer orelse 0;
}

pub fn keyboard_interrupting() bool {
    return keyboard_buffer != null;
}

pub fn poll_keyboard_with_irq(soc: *SoC.sys_on_chip) void {
    const stdin = std.io.getStdIn().reader();
    var buf: [1]u8 = undefined;
    if (stdin.read(&buf)) |_| {
        keyboard_buffer = buf[0];
        soc.irq = true; // IRQ 요청 발생
    } else |_| {
        keyboard_buffer = null;
    }
}

pub fn clear_keyboard_buffer() void {
    keyboard_buffer = null;
}

// TTY output
pub fn tty_out_write(data: u8) void {
    std.debug.print("{c}", .{data});
}

// TTY status
pub fn tty_status_read() u8 {
    return 1;
}

// Timer
var tick_count: u8 = 0;
var tick_threshold: u8 = 60;
var tick_pending: bool = false;

pub fn timer_interrupting() bool {
    return tick_pending;
}

pub fn timer_read() u8 {
    return tick_count;
}

pub fn poll_timer_with_irq(soc: *SoC.sys_on_chip) void {
    tick_count += 1;
    if (tick_count >= tick_threshold) {
        tick_pending = true;
        tick_count = 0;
        soc.irq = true; // 인터럽트 요청
    }
}

pub fn clear_timer_interrupt() void {
    tick_pending = false;
}
