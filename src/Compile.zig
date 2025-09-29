const std = @import("std");
const ms_dos = @import("ms_dos.zig");
const pe = @import("pe.zig");
const Compile = @This();

pub fn generate_assembly(writer: *std.Io.Writer) !void {
    var ms_dos_header = ms_dos.Header{
        .pe_signature_offset = 0x00000080, // Immedaitely after DOS stub
    };
    try writer.print("\nDOS Header:         {any} bytes\n", .{ms_dos.Header.total_bytes});
    try ms_dos_header.write(writer);

    var pe_header = pe.Header{
        .date_stamp = @truncate(std.time.timestamp()),
        .number_of_sections = 0,
        .optional_header_size = 0,
        .characteristics = pe.FileCharacteristics.executable_image | pe.FileCharacteristics.dll,
    };
    try writer.print("\nPE Header:          {any} bytes\n", .{pe.Header.total_bytes});

    try pe_header.write(writer);

    _ = pe.OptionalHeader{
        .standard_fields = pe.OptionalHeader.StandardFields{
            .code_size = 0,
            .initialized_data_size = 0,
            .uninitialized_data_size = 0,
            .entry_point_rva = 0,
            .base_of_data = 0,
            .base_of_code = 0,
        },
        .nt_specific = undefined,
        .data_directories = undefined,
    };

    try writer.print("\nPE Optional Header: {any} bytes\n", .{pe.OptionalHeader.total_bytes});
    // try optional_pe.write();

    try writer.flush(); // Don't forget to flush!
}
