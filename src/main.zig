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
        },
    }
    defer if (debug) {
        std.debug.print("\n{any}", .{debug_alloc.deinit()});
    };

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    const alloc = arena.allocator();

    const arg_list = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, arg_list);

    const path = arg_list[0];
    const command_text = if (arg_list.len >= 2) arg_list[1] else "help";
    const command = std.meta.stringToEnum(Command, command_text) orelse .help;

    var build_args = BuildFlags.init(alloc);
    defer build_args.deinit();

    if (arg_list.len >= 3) {
        switch (command) {
            .build => {
                for (arg_list[2..]) |arg| { // Skip rug exe path and command
                    if (arg.len < 2) {
                        try build_args.put(.invalid, arg);
                        break;
                    }

                    if (arg[0] == '-') {
                        const index: u64 = if (arg[1] == '-') 2 else 1;
                        const eql_inndex = retireved: {
                            for (arg[index..], index..) |char, i| {
                                if (char == '=') break :retireved i;
                            }

                            break :retireved arg.len;
                        };
                        const key = std.meta.stringToEnum(BuildArgs, arg[index..eql_inndex]) orelse .invalid;
                        std.debug.print("{s} {any}\n", .{ arg[index..eql_inndex], key });
                        try build_args.put(key, arg[eql_inndex..]);
                        if (key == .invalid) break;

                        continue;
                    }

                    try build_args.put(.source_file, arg);
                }
            },
            else => {},
        }
    }

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const cmd_args = CmdArgs{
        .build = build_args,
        .help = HelpArgs.help,
    };

    var cmd = Cmd{
        .path = path,
        .command_text = command_text,
        .command = command,
        .stdout = stdout,
        .cmd_args = cmd_args,
    };

    try switch (cmd.command) {
        .build => cmd.build(alloc),
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

pub const BuildFlags = std.AutoHashMap(BuildArgs, [:0]const u8);

const CmdArgs = struct {
    build: BuildFlags,
    help: HelpArgs,
};

pub const BuildArgs = enum {
    @"show-ast",
    @"new-parser",
    source_file,
    invalid,
};

const HelpArgs = Command;

const Cmd = struct {
    path: [:0]const u8,
    command_text: [:0]const u8,
    command: Command,
    stdout: *std.Io.Writer,
    cmd_args: CmdArgs,

    pub fn build(self: *@This(), alloc: std.mem.Allocator) !void {
        try Compiler.execute(self.stdout, alloc, self.cmd_args.build);
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
