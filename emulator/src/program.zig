const std = @import("std");
const SoC = @import("soc.zig");

pub fn load_bin(
    soc: *SoC.sys_on_chip,
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    filename: []const u8,
) !void {
    const full_path = if (std.fs.path.isAbsolute(filename)) filename else try std.fs.path.join(allocator, &[_][]const u8{ dir_path, filename });
    defer if (!std.fs.path.isAbsolute(filename)) allocator.free(full_path);

    const file = try std.fs.openFileAbsolute(full_path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    if (file_size != 128 * 1024) {
        std.debug.print("Error: Expected 128KB binary, got {} bytes\n", .{file_size});
        return error.InvalidFileSize;
    }

    var buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);

    _ = try file.readAll(buffer);

    @memcpy(soc.instr_mem[0..0x10000], buffer[0..0x10000]);
    @memcpy(soc.data_mem[0..0x10000], buffer[0x10000..0x20000]);
}
