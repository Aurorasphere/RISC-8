const std = @import("std");
const SoC = @import("soc.zig");
const prog = @import("program.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var soc = SoC.sys_on_chip{};

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: program <binary file>\n", .{});
        return error.MissingFilename;
    }

    const filename = args[1]; // 예: "hello.bin"
    try prog.load_program(&soc, &allocator, ".", filename);

    SoC.SoC_run(&soc);
}
