const std = @import("std");
const SoC = @import("soc.zig");
const prog = @import("program.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var is_debug = false;
    var is_slow = false;
    var filename: []const u8 = "";
    var initial_pc: ?u16 = null;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var i: usize = 1;
    while (i < args.len) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--debug")) {
            is_debug = true;
        } else if (std.mem.eql(u8, arg, "--slow")) {
            is_slow = true;
        } else if (std.mem.eql(u8, arg, "--pc")) {
            if (i + 1 >= args.len) {
                std.debug.print("Error: --pc option requires a value.\n", .{});
                return error.MissingPCValue;
            }
            const pc_str = args[i + 1];
            initial_pc = try std.fmt.parseInt(u16, pc_str, 0); // 자동 0x 또는 10진수 처리
            i += 1; // 추가 소비
        } else {
            filename = arg;
        }

        i += 1;
    }

    if (filename.len == 0) {
        std.debug.print("Usage: program <binary file> [--debug] [--pc <value>]\n", .{});
        return error.MissingFilename;
    }

    var soc = SoC.sys_on_chip{};
    if (initial_pc) |pc| {
        soc.pc = pc;
    }

    const abs_path = try std.fs.realpathAlloc(allocator, filename);
    defer allocator.free(abs_path);

    try prog.load_bin(&soc, allocator, ".", abs_path);

    if (is_debug) {
        std.debug.print("Debug Mode: true\n", .{});
        std.debug.print("PC = 0x{X:04}, Instr = 0x{X:02} 0x{X:02}\n", .{ soc.pc, soc.instr_mem[soc.pc], soc.instr_mem[soc.pc + 1] });

        for (soc.regfile, 0..) |val, idx| {
            std.debug.print("r{d} = 0x{X:02}\n", .{ idx, val });
        }

        if (soc.pc >= 0xF800) {
            std.debug.print("Notice: PC is in interrupt routine region.\n", .{});
        }
    }

    SoC.SoC_run(&soc, is_debug, is_slow);
}
