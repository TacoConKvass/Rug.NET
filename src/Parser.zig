const std = @import("std");

pub fn parse(stdout: *std.Io.Writer, buffer: []u8) void {
    var last: u64 = 0;
    var line_number: u64 = 1;
    for (0..buffer.len - 1) |i| {
        if (std.mem.eql(u8, buffer[i..i+1], "\n")) {
            line_number += 1;
            last = i+1;
        }
        else if (std.mem.eql(u8, buffer[last..i], "const")) {
            stdout.print("const found on line {any}\n", .{ line_number }) catch unreachable;
            last = i;
        }
    }

    stdout.flush() catch @panic("Parser failed to flush");
}

pub const Token = union {
    declaration: enum { _const, },
    identifier: []u8,
    type_hint: []u8,
    asignement: u8,
};
