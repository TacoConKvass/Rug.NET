const std = @import("std");
const pe = @import("pe.zig");
const Compiler = @import("Compiler.zig");

const version = "0.0.1";

pub fn main() !void {
    var args = std.process.args(); // exe args

    const path = args.next() orelse ""; // exe path
    const command_text = args.next() orelse "";

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var cmd = CMD{
        .path = path,
        .command_text = command_text,
        .command = std.meta.stringToEnum(Command, command_text) orelse .null,
        .args = &args,
        .stdout = stdout,
    };

    try switch (cmd.command) {
        .build => cmd.build(),
        .init => {
            try stdout.print("{any}\n", .{cmd.command});
            try stdout.flush();
        },
        .version => cmd.showVersion(),
        .help, .null => cmd.showHelp(),
    };
}

const Command = enum {
    build,
    help,
    init,
    null,
    version,
};

const CMD = struct {
    path: [:0]const u8,
    command_text: [:0]const u8,
    command: Command,
    stdout: *std.Io.Writer,
    args: *std.process.ArgIterator,

    pub fn build(self: *@This()) !void {
        Compiler.execute(self.stdout, self.args);
    }

    pub fn showHelp(self: *@This()) !void {
        if (self.command == .null and !std.mem.eql(u8, self.command_text, "")) {
            try self.stdout.print("Unknown command '{s}'\n", .{self.command_text});
        }

        try self.stdout.print(
            \\cig - A .NET compiler for Cig# 
            \\Usage: cig [command]
            \\
            \\Available commands:
            \\    help - Display this message
            \\    init - Initializes a Cig# project
            \\    version - Show version and executable path
            \\
        , .{});
        try self.stdout.flush(); // Don't forget to flush!
    }

    pub fn showVersion(self: *@This()) !void {
        try self.stdout.print("cig v{s} - {s}\n", .{ version, self.path });
        try self.stdout.flush(); // Don't forget to flush!
    }
};
