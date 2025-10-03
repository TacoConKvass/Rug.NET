const std = @import("std");

pub fn parse(stdout: *std.Io.Writer, buffer: []u8) void {
    var last: u64 = 0;
    var line_number: u64 = 1;
    for (1..buffer.len) |i| {
        const char: Symbol = @enumFromInt(buffer[i - 1..i][0]);
        const current = buffer[last..i];
        switch (char) {
            .space => {
                stdout.print("New token started\n", .{ }) catch unreachable;
                last = i;
            },
            .new_line => {
                stdout.print("End of line {any}\n", .{ line_number }) catch unreachable;
                line_number += 1;
                last = i;
            },
            .block_open => {
                stdout.print("New block started on line: {any}\n", .{ line_number }) catch unreachable;
                last = i;
            },
            .block_close => {
                stdout.print("Block ended on line: {any}\n", .{ line_number }) catch unreachable;
                last = i;
            },
            .end_statement => {
                stdout.print("Statement ended on line: {any}\n", .{ line_number }) catch unreachable;
                last = i;
            },
            _ => check_word(current, stdout)
        }
    }

    stdout.flush() catch @panic("Parser failed to flush");
}

fn check_word(word: []u8, stdout: *std.Io.Writer) void {
   if (std.mem.eql(u8, word, "const"))
       stdout.print("Found const in line\n", .{}) catch unreachable;
}

const Symbol = enum(u8) {
    space = " "[0],
    new_line = "\n"[0],
    block_open = "{"[0],
    block_close = "}"[0],
    end_statement = ";"[0],
    _
};

pub const Token = union {
    declaration: enum { _const, },
    label: []u8,
    identifier: []u8,
    type_hint: []u8,
    asignement: u8,
};
