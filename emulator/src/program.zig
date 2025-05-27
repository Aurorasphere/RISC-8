const std = @import("std");
const mem = @import("memory.zig");

pub fn load_program(path: []const u8) !void {
    const allocator = std.heap.page_allocator;
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const contents = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(contents);

    // ── 헤더(4B) ──────────────────────────────────────
    if (contents.len < 4) return error.InvalidProgram;
    const data_size = std.mem.readInt(u32, contents[0..4], .little);

    if (data_size > mem.DATA_MEM_SIZE) return error.DataTooLarge;
    const code_size = contents.len - 4 - data_size;
    if (code_size > mem.INSTR_MEM_SIZE) return error.CodeTooLarge;

    // ── 데이터 세그먼트 → RAM ─────────────────────────
    std.mem.copyForwards(u8, mem.datamem[0..data_size], contents[4 .. 4 + data_size]);

    // ── 코드  세그먼트 → ROM ─────────────────────────
    std.mem.copyForwards(u8, mem.instrmem[0..code_size], contents[4 + data_size .. 4 + data_size + code_size]);

    std.debug.print("로드 완료: 데이터 {d} 바이트, 코드 {d} 바이트\n", .{ data_size, code_size });
}
