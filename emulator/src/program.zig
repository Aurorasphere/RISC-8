const std = @import("std");
const SoC = @import("soc.zig");

const ELF_MAGIC = [4]u8{ 'A', 'U', 'R', '8' }; // AUR8 (AuRISC-8)

const SECTION_HEADER_SIZE = 13;
const MAX_SECTION_COUNT = 8;

const ELF_HEADER_BASE = 0;
const ELF_HEADER_SIZE = 6;
const SECTION_HEADERS_SIZE = SECTION_HEADER_SIZE * 4; // 13 * 4 = 52;

const SECTION_HEADERS_BASE = ELF_HEADER_BASE + ELF_HEADER_SIZE; // 0x0000 + 6 = 0x0006
const SECTION_DATA_BASE = SECTION_HEADERS_BASE + SECTION_HEADERS_SIZE; // 0x0006 + 0x0034 = 0x003A

const INST_SECTION_FILE_OFFSET = 0x0040; // 0x0040
const IVR_SECTION_FILE_OFFSET = INST_SECTION_FILE_OFFSET + 0xF800; // 0x0040 + 0xF800 = 0xF840
const DATA_SECTION_FILE_OFFSET = INST_SECTION_FILE_OFFSET + SoC.INSTR_MEM_SIZE; // 0x0040 + 0x10000 = 0x10040
const RODATA_SECTION_FILE_OFFSET = DATA_SECTION_FILE_OFFSET + 0xFF00; // 0x10040 + 0xFF00 = 0x1FF40
const TOTAL_ELF_SIZE = DATA_SECTION_FILE_OFFSET + SoC.DATA_MEM_SIZE; // 0x10040 + 0x10000 = 0x20040

const MemTarget = enum(u8) {
    instr = 0,
    ivr1 = 1,
    ivr2 = 2,
    ivr3 = 3,
    ivr4 = 4,
    ivr5 = 5,
    ivr6 = 6,
    ivr7 = 7,
    ivr8 = 8,
    ivr9 = 9,
    ivr10 = 10,
    ivr11 = 11,
    ivr12 = 12,
    ivr13 = 13,
    ivr14 = 14,
    ivr15 = 15,
    ivr16 = 16,
    data = 17,
    rodata = 18,
};

const ELF_header = packed struct {
    magic1: u8,
    magic2: u8,
    magic3: u8,
    magic4: u8,
    version: u8,
    section_count: u8,
};

const SectionHeader = packed struct {
    name1: u8,
    name2: u8,
    name3: u8,
    name4: u8,
    mem_target: u8,
    mem_offset: u16,
    file_offset: u32,
    size: u16,
};
fn parseELFHeader(buffer: []const u8) !*const ELF_header {
    if (buffer.len < @sizeOf(ELF_header)) return error.InvalidELFHeader;

    // 단순히 정렬만 보장하고 포인터 캐스트를 한 번에 수행
    const hdr: *const ELF_header = @ptrCast(@alignCast(buffer.ptr));

    const magic = [4]u8{ hdr.magic1, hdr.magic2, hdr.magic3, hdr.magic4 };
    if (!std.mem.eql(u8, &magic, &ELF_MAGIC)) return error.InvalidMagicNumber;

    return hdr;
}

fn parseSectionHeader(ptr: [*]const u8) *const SectionHeader {
    const raw_ptr: *const u8 = @ptrCast(ptr);
    const aligned: *align(@alignOf(SectionHeader)) const u8 = @alignCast(raw_ptr);
    return @ptrCast(aligned);
}

fn loadIVRSection(soc: *SoC.sys_on_chip, target: MemTarget, src: []const u8) !void {
    const ivr_index = @intFromEnum(target) - @intFromEnum(MemTarget.ivr1);
    if (ivr_index >= 16) return error.InvalidIVRIndex;
    if (src.len > 0x80) return error.IVRSectionTooLarge;

    const addr = soc.ivt[ivr_index];
    @memcpy(soc.instr_mem[addr .. addr + src.len], src);
}

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

    const hdr = try parseELFHeader(buffer);
    var sections = buffer[@sizeOf(ELF_header)..];

    for (0..hdr.section_count) |_| {
        if (sections.len < @sizeOf(SectionHeader)) return error.SectionHeaderTooShort;

        const sh = parseSectionHeader(sections.ptr);
        sections = sections[@sizeOf(SectionHeader)..];

        if (sh.file_offset + sh.size > buffer.len) return error.SectionOutOfBounds;
        const src = buffer[sh.file_offset .. sh.file_offset + sh.size];

        const mem_target: MemTarget = @enumFromInt(sh.mem_target);
        switch (mem_target) {
            MemTarget.instr => {
                if (sh.mem_offset + sh.size > SoC.INSTR_MEM_SIZE) return error.InstrOverflow;
                @memcpy(soc.instr_mem[sh.mem_offset .. sh.mem_offset + sh.size], src);
            },
            MemTarget.data => {
                if (sh.mem_offset + sh.size > SoC.DATA_MEM_SIZE) return error.DataOverflow;
                @memcpy(soc.data_mem[sh.mem_offset .. sh.mem_offset + sh.size], src);
            },
            MemTarget.rodata => {
                if (sh.mem_offset + sh.size > SoC.DATA_MEM_SIZE) return error.RodataOverflow;
                @memcpy(soc.data_mem[sh.mem_offset .. sh.mem_offset + sh.size], src);
            },
            MemTarget.ivr1, MemTarget.ivr2, MemTarget.ivr3, MemTarget.ivr4, MemTarget.ivr5, MemTarget.ivr6, MemTarget.ivr7, MemTarget.ivr8, MemTarget.ivr9, MemTarget.ivr10, MemTarget.ivr11, MemTarget.ivr12, MemTarget.ivr13, MemTarget.ivr14, MemTarget.ivr15, MemTarget.ivr16 => {
                try loadIVRSection(soc, mem_target, src);
            },
        }
    }
}
