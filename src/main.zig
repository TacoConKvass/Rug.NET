const std = @import("std");
const builtin = @import("builtin");
const pe = @import("pe.zig");
const Compiler = @import("Compiler.zig");

const version = "0.0.1";

pub fn main() !void {
    var debug_alloc = std.heap.DebugAllocator(.{}).init;
    var gpa: std.mem.Allocator = undefined;
    var debug: bool = undefined;
    switch (builtin.mode) {
        .Debug, .ReleaseSafe => {
            gpa = debug_alloc.allocator();
            debug = true;
        },
        .ReleaseFast, .ReleaseSmall => {
            gpa = std.heap.smp_allocator;
            debug = false;
        }
    }
    defer if (debug) {
        std.debug.print("\n{any}", .{ debug_alloc.deinit() });
    };

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    var args = std.process.args();

    const path = args.next() orelse unreachable; // exe path
    const command_text = args.next() orelse "help";

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var cmd = CMD{
        .path = path,
        .command_text = command_text,
        .command = std.meta.stringToEnum(Command, command_text) orelse .help,
        .args = &args,
        .stdout = stdout,
    };

    try switch (cmd.command) {
        .build => cmd.build(arena.allocator()),
        .init => {
            try stdout.print("{any}\n", .{cmd.command});
            try stdout.flush();
        },
        .version => cmd.showVersion(),
        .help => cmd.showHelp(),
    };
}

const Command = enum {
    build,
    help,
    init,
    version,
};

const CMD = struct {
    path: [:0]const u8,
    command_text: [:0]const u8,
    command: Command,
    stdout: *std.Io.Writer,
    args: *std.process.ArgIterator,

    pub fn build(self: *@This(), alloc: std.mem.Allocator) !void {
        try Compiler.execute(self.stdout, alloc, self.args);
    }

    pub fn showHelp(self: *@This()) !void {
        if (!std.mem.eql(u8, self.command_text, "help")) {
            try self.stdout.print("Unknown command '{s}'\n\n", .{self.command_text});
        }

        try self.stdout.print(
            \\Rug.NET - A .NET compiler for Rug 
            \\Usage: rug [command]
            \\
            \\Available commands:
            \\    help - Display this message
            \\    init - Initializes a Rug project
            \\    version - Show version and executable path
            \\
        , .{});
        try self.stdout.flush(); // Don't forget to flush!
    }

    pub fn showVersion(self: *@This()) !void {
        try self.stdout.print("rug v{s} - {s}\n", .{ version, self.path });
        try self.stdout.flush(); // Don't forget to flush!
    }
};
