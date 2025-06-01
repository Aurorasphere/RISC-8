const std = @import("std");
const SoC = @import("soc.zig");
const prog = @import("program.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var is_debug = false;
    var filename: []const u8 = "";

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--debug")) {
            is_debug = true;
        } else {
            filename = arg;
        }
    }

    if (filename.len == 0) {
        std.debug.print("Usage: program <binary file> [--debug]\n", .{});
        return error.MissingFilename;
    }

    var soc = SoC.sys_on_chip{};

    try prog.load_bin(&soc, allocator, ".", filename);

    if (is_debug) {
        std.debug.print("Debug Mode: true\n", .{});
        std.debug.print("PC = 0x{X:04}, Instr = 0x{X:02} 0x{X:02}\n", .{ soc.pc, soc.instr_mem[soc.pc], soc.instr_mem[soc.pc + 1] });

        for (soc.regfile, 0..) |val, i| {
            std.debug.print("r{d} = 0x{X:02}\n", .{ i, val });
        }

        if (soc.pc >= 0xF800) {
            std.debug.print("Notice: PC is in interrupt routine region.\n", .{});
        }
    }

    SoC.SoC_run(&soc, is_debug);
}
