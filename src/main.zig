const std = @import("std");

const version = "0.0.1";

pub fn main() !void {
    var args = std.process.args(); // exe args
    
    const path = args.next() orelse ""; // exe path
    const command_text = args.next() orelse "";
    
    var context = ExecutionContext {
        .path = path,
        .command_text = command_text,
        .command = std.meta.stringToEnum(Command, command_text) orelse .null
    };

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try switch (context.command) {
        .init => stdout.print("{any}\n", .{ context.command }),
        .version => context.show_version(stdout),
        .help, .null => context.show_help(stdout),
    };

}

const Command = enum {
    help,
    init,
    null,
    version,
};

const ExecutionContext = struct {
    path: [:0]const u8,
    command_text: [:0]const u8,
    command: Command,
    
    pub fn show_help(self: *@This(), stdout: *std.Io.Writer) !void {
        if (self.command == .null and !std.mem.eql(u8, self.command_text, "")) {
            try stdout.print("Unknown command '{s}'\n", .{ self.command_text });
        }
        
        try stdout.print(
            \\cig - A .NET compiler for Cig# 
            \\Usage: cig [command]
            \\
            \\Available commands:
            \\    init - Initializes a Cig# project
            \\    version - Show version and executable path
            \\
        , .{ });
        try stdout.flush(); // Don't forget to flush!
    } 

    pub fn show_version(self: *@This(), stdout: *std.Io.Writer) !void {
        try stdout.print("cig v{s} - {s}\n", .{ version, self.path });
        try stdout.flush(); // Don't forget to flush!
    }
};
