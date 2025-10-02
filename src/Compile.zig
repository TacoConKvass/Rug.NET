const std = @import("std");
const ms_dos = @import("ms_dos.zig");
const pe = @import("pe.zig");
const Parser = @import("Parser.zig");

pub fn parse_file(stdout: *std.Io.Writer, args: *std.process.ArgIterator) void {
    const arg_path = args.next();
    var file_path: []const u8 = &.{};
    if (arg_path != null and arg_path.?.len > 1) file_path = arg_path.?[0..arg_path.?.len];
    stdout.print("Parsing {any} {s}\n", .{ std.fs.cwd(), file_path }) catch @panic("Failed to print");
    stdout.flush() catch @panic("Flush failed");

    const file = std.fs.cwd().openFile(file_path, .{ .mode = .read_only }) catch @panic("Failed to access file");
    defer file.close();

    var buffer: [256]u8 = undefined;
    var file_reader = file.reader(&buffer);
    const read = file_reader.read(&buffer) catch @panic("Failed to read!");
    stdout.print("File size {any}\n{s}", .{ read, buffer[0..read] }) catch @panic("Failed to print");
    Parser.parse(stdout, buffer[0..read]);
    stdout.flush() catch @panic("Flush failed");
}

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
