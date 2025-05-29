const std = @import("std");
const SoC = @import("soc.zig");
const prog = @import("program.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var is_debug: bool = true;
    var soc = SoC.sys_on_chip{};

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    std.debug.print("Debug Mode: {}\n", .{is_debug});
    var filename: []const u8 = "";
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

    try prog.load_program(&soc, &allocator, ".", filename);
    std.debug.print("Loaded PC: 0x{X:04}, First Instruction: 0x{X:02} 0x{X:02}\n", .{ soc.pc, soc.instr_mem[0], soc.instr_mem[1] });

    SoC.SoC_run(&soc, is_debug);
}
