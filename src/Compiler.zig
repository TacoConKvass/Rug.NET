const std = @import("std");
const ms_dos = @import("ms_dos.zig");
const pe = @import("pe.zig");
const Parser = @import("Parser.zig");
const NewParser = @import("NewParser.zig");
const main = @import("main.zig");

pub fn execute(stdout: *std.Io.Writer, alloc: std.mem.Allocator, args: main.BuildFlags) !void {
    const arg_path = args.get(.source_file);
    var file_path: []const u8 = &.{};
    if (arg_path != null and arg_path.?.len > 1) file_path = arg_path.?[0..arg_path.?.len];

    try stdout.print("Parsing {s}\n\n", .{file_path});
    try stdout.flush();

    const file = try std.fs.cwd().openFile(file_path, .{ .mode = .read_only });
    defer file.close();

    const file_stat = try file.stat();

    var file_reader = file.reader(&.{});
    const read_data = try file_reader.interface.readAlloc(std.heap.page_allocator, file_stat.size);

    try stdout.print("{s}\n\n", .{read_data});
    try stdout.flush();

    if (args.get(.@"old-parser") != null) {
        var state = try Parser.execute(read_data, alloc);
        defer state.deinit();

        // Output AST
        if (args.get(.@"show-ast") != null) {
            try state.write(stdout, alloc);
            try stdout.flush();
        }

        return;
    }

    var state = try NewParser.execute(read_data, alloc, null);
    defer state.deinit();

    // Output AST
    if (args.get(.@"show-ast") != null) {
        try state.write(stdout, alloc);
        try stdout.flush();
    }
}

pub fn generateAssembly(writer: *std.Io.Writer) !void {
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
