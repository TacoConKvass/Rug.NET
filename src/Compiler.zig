const std = @import("std");
const main = @import("main.zig");
const Tokenizer = @import("Tokenizer.zig");

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
    const read_data = try file_reader.interface.readAlloc(alloc, file_stat.size);

    try stdout.print("{s}\n\n", .{read_data});
    try stdout.flush();

    var state = try Tokenizer.execute(read_data, alloc, null);
    defer state.deinit();

    // Output AST
    if (args.get(.@"show-ast") != null) {
        try state.write(stdout, alloc);
        try stdout.flush();
    }
}
