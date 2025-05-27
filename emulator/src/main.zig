const std = @import("std");
const program = @import("program.zig");
const cpu = @import("cpu.zig");

pub fn main() !void {
    var main_cpu: cpu.CPU = .{};

    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("사용법: {s} <program.bin>\n", .{args[0]});
        return;
    }

    const program_path = args[1];
    try program.load_program(program_path);
    cpu.CPU_run(false, &main_cpu);
}
