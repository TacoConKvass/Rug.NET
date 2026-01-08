const std = @import("std");
const cli = @import("cli.zig");

pub fn main(init: std.process.Init) !void {
    const alloc = init.arena.allocator();
    var writer = std.Io.File.stdout().writer(init.io, &.{});
    const out = &writer.interface;

    const args = try cli.parse(Args, alloc, init.minimal.args, .{
        .exit = true,
        .writer = out,
    });

    try out.print("Hello, World, mode: {any}!\n", .{args.mode});
    try out.flush();
    _ = .{ alloc, out };
}

pub const Args = struct {
    pub const arg0 = "rug";
    pub const description = "Rug compiler for the dotnet CLR";

    verbose: bool = false,
    @"--": void,
    mode: enum { build, init },

    pub const help = .{
        .mode = "a",
        .verbose = "aha",
    };
};
