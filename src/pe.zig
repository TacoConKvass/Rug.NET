const std = @import("std");

pub const FileCharacteristics = struct {
    pub const relocs_stripped: u16 = 0x0000;
    pub const executable_image: u16 = 0x0002;
    pub const x32_bit: u16 = 0x0100;
    pub const dll: u16 = 0x2000;
};

pub const Header = struct {
    pub const total_bytes: u64 = 24;

    signature: [4]u8 = [4]u8{ 0x50, 0x45, 0x00, 0x00 }, // PE + 2 null byte
    machine: u16 = 0x14c,
    number_of_sections: u16,
    date_stamp: i32,
    pointer_to_symbol_table: u32 = 0,
    number_of_symbol_tables: u32 = 0,
    optional_header_size: u16,
    characteristics: u16,

    pub fn write(self: *@This(), writer: *std.Io.Writer) !void {
        // zig fmt: off
        _ = try writer.write(
            &self.signature ++ 
            bytes(2, self.machine) ++ 
            bytes(2, self.number_of_sections) ++ 
            bytes(4, self.date_stamp) ++ 
            bytes(4, self.pointer_to_symbol_table) ++ 
            bytes(4, self.number_of_symbol_tables) ++ 
            bytes(2, self.optional_header_size) ++ 
            bytes(2, self.characteristics)
        );
        // zig fmt: on
    }
};

pub const SubsystemType = enum(u16) {
    cui = 0x3,
    gui = 0x2,
};

pub const OptionalHeader = struct {
    pub const StandardFields = struct {
        pub const total_bytes: u64 = 28;

        magic: u16 = 0x010B,
        lmajor: u8 = 6,
        lminor: u8 = 0,
        code_size: u32,
        initialized_data_size: u32,
        uninitialized_data_size: u32,
        entry_point_rva: u32,
        base_of_code: u32,
        base_of_data: u32,

        pub fn write(self: *@This()) [StandardFields.total_bytes]u8 {
            // zig fmt: off
            return
                bytes(2, self.magic) ++
                bytes(1, self.lmajor) ++
                bytes(1, self.lminor) ++
                bytes(4, self.code_size) ++
                bytes(4, self.initialized_data_size) ++
                bytes(4, self.uninitialized_data_size) ++
                bytes(4, self.entry_point_rva) ++
                bytes(4, self.base_of_code) ++
                bytes(4, self.base_of_data)
            ;
            // zig fmt: on
        }
    };

    pub const NT_Specific = struct {
        pub const total_bytes: u64 = 68;

        image_base: u32,
        section_alignement: u32,
        file_alignement: u32,
        os_major: u16 = 5,
        os_minor: u16 = 0,
        user_major: u16 = 0,
        user_minor: u16 = 0,
        sub_sys_major: u16 = 5,
        sub_sys_minor: u16 = 0,
        reserved: u32 = 0,
        image_size: u32,
        header_size: u32,
        file_checksum: u32 = 0,
        sub_system: SubsystemType,
        dll_flags: u16 = 0,
        stack_reserve_size: u32 = 0x00100000, // 1Mb
        stack_commit_size: u32 = 0x00001000, // 4Kb
        heap_reserve_size: u32 = 0x00100000, // 1Mb
        heap_commit_size: u32 = 0x00001000, // 4Kb
        loader_flags: u32 = 0,
        number_of_data_directories: u32 = 0x00000010,

        pub fn all_bytes(self: *@This()) [NT_Specific.total_bytes]u8 {
            // zig fmt: off
            return 
                bytes(4, self.image_base) ++
                bytes(4, self.section_alignement) ++
                bytes(4, self.file_alignement) ++
                bytes(2, self.os_major) ++
                bytes(2, self.os_minor) ++
                bytes(2, self.user_major) ++
                bytes(2, self.user_minor) ++
                bytes(2, self.sub_sys_major) ++
                bytes(2, self.sub_sys_minor) ++
                bytes(4, self.reserved) ++
                bytes(4, self.image_size) ++
                bytes(4, self.header_size) ++
                bytes(4, self.file_checksum) ++
                bytes(2, @intFromEnum(self.sub_system)) ++
                bytes(2, self.dll_flags) ++
                bytes(4, self.stack_reserve_size) ++
                bytes(4, self.stack_commit_size) ++
                bytes(4, self.heap_reserve_size) ++
                bytes(4, self.heap_commit_size) ++
                bytes(4, self.loader_flags) ++
                bytes(4, self.number_of_data_directories)
            ;
            // zig fmt: on
        }
    };

    pub const DataDirectiories = struct {
        pub const total_bytes: u64 = 128;
        // pub fn write(self: *@This(), stdout: std.Io.Writer) !void {
        // zig fmt: off
            // _ = try stdout.write(
                
            // );
            // zig fmt: on
        // }
    };

    pub const total_bytes: u64 = StandardFields.total_bytes + NT_Specific.total_bytes + DataDirectiories.total_bytes;

    standard_fields: StandardFields,
    nt_specific: NT_Specific,
    data_directories: DataDirectiories,

    // pub fn write(self: *@This(), stdout: std.Io.Writer) !void { }
};

fn bytes(comptime size: u64, value: anytype) [size]u8 {
    return @bitCast(value);
}
