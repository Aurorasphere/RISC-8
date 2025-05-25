const MEM_SIZE: usize = 32 * 1024; // 32KiB
pub var memory: [MEM_SIZE]u8 = .{0};

const IO_TTY_OUT: u16 = 0xFF00;
const IO_TTY_IN: u16 = 0xFF01;
const IO_TTY_STATUS: u16 = 0xFF02;
