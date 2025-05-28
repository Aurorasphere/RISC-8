const std = @import("std");
const SoC = @import("soc.zig");

pub fn load_program(
    soc: *SoC.sys_on_chip,
    allocator: *const std.mem.Allocator,
    directory: []const u8, // ← 여기에 추가
    filename: []const u8,
) !void {
    var programs_dir_val = try std.fs.cwd().openDir(directory, .{});
    var programs_dir = &programs_dir_val;
    defer (@constCast(programs_dir)).close();

    const file = try programs_dir.openFile(filename, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    if (file_size > SoC.INSTR_MEM_SIZE + SoC.DATA_MEM_SIZE) {
        return error.ProgramTooLarge;
    }

    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);

    _ = try file.readAll(buffer);

    const instr_size = @min(file_size, SoC.INSTR_MEM_SIZE);
    @memcpy(soc.instr_mem[0..instr_size], buffer[0..instr_size]);

    const data_offset: usize = SoC.INSTR_MEM_SIZE;
    if (file_size > data_offset) {
        const data_size = file_size - data_offset;
        const data_copy_size = @min(data_size, SoC.DATA_MEM_SIZE);
        @memcpy(soc.data_mem[0..data_copy_size], buffer[data_offset .. data_offset + data_copy_size]);
    }
}
