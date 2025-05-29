const std = @import("std");
const SoC = @import("soc.zig");
const elf = @import("elf_constants.zig");

const ELF_MAGIC = [4]u8{ 'A', 'U', 'R', '8' }; // AUR8 (AuRISC-8)

const MemTarget = enum(u8) {
    instr = 0,
    data = 1,
};

const ELF_header = packed struct {
    magic: [4]u8,
    version: u8,
    section_count: u8,
};

const SectionHeader = packed struct {
    name: [4]u8,
    mem_target: u8,
    mem_offset: u16,
    file_offset: u32,
    size: u16,
};

pub fn load_elf(
    soc: *SoC.sys_on_chip,
    allocator: *const std.mem.Allocator,
    directory: []const u8,
    filename: []const u8,
) !void {
    var dir = try std.fs.cwd().openDir(directory, .{});
    defer dir.close();

    const file = try dir.openFile(filename, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);

    _ = try file.readAll(buffer);

    if (buffer.len < @sizeOf(ELF_header)) return error.InvalidELFHeader;
    const hdr: *const ELF_header = @ptrCast(buffer.ptr);
    if (hdr.magic != ELF_MAGIC) return error.InvalidMagicNumber;

    var sections = buffer[elf.ELF_HEADER_SIZE..];
    for (0..hdr.section_count) |_| {
        if (sections.len < @sizeOf(SectionHeader)) return error.SectionHeaderTooShort;

        const sh: *const SectionHeader = @ptrCast(sections.ptr);
        sections = sections[@sizeOf(SectionHeader)..];

        if (sh.file_offset + sh.size > buffer.len) return error.SectionOutOfBounds;
        const src = buffer[sh.file_offset .. sh.file_offset + sh.size];

        switch (sh.mem_target) {
            MemTarget.instr => {
                if (sh.mem_offset + sh.size > SoC.INSTR_MEM_SIZE) return error.InstrOverflow;
                @memcpy(soc.instr_mem[sh.mem_offset .. sh.mem_offset + sh.size], src);
            },
            MemTarget.data => {
                if (sh.mem_offset + sh.size > SoC.DATA_MEM_SIZE) return error.DataOverflow;
                @memcpy(soc.data_mem[sh.mem_offset .. sh.mem_offset + sh.size], src);
            },
            MemTarget.ivt => {
                if (sh.mem_offset != 0 or sh.size > @sizeOf([16]u16)) return error.InvalidIVTSize;
                @memcpy(std.mem.asBytes(&soc.ivt), src);
            },
            else => return error.UnknownMemTarget,
        }
    }
}
