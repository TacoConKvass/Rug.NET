const std = @import("std");

pub fn execute(stdout: *std.Io.Writer, buffer: []u8) void {
    var last: u64 = 0;
    var line_number: u64 = 1;
    var parent: ?u64 = null;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var state = State.init(arena.allocator());
    defer state.deinit();

    for (1..buffer.len) |i| {
        const char: SpecialChar = @enumFromInt(buffer[i - 1..i][0]);
        const current = buffer[last..i];
        switch (char) {
            .space => {
                // stdout.print("New token started\n", .{ }) catch unreachable;
            },
            .new_line => {
                // stdout.print("End of line {any}\n", .{ line_number }) catch unreachable;
                line_number += 1;
            },
            .block_open => {
                // stdout.print("New block started on line: {any}\n", .{ line_number }) catch unreachable;
                const token = Token {
                    .child_index = null,
                    .line_number = line_number,
                    .variant = .block_open,
                };
                const index = state.push(token);
                if (parent != null) state.ast[parent.?].?.child_index = index;
                parent = index;
            },
            .block_close => {
                // stdout.print("Block ended on line: {any}\n", .{ line_number }) catch unreachable;
                const token = Token {
                    .child_index = null,
                    .line_number = line_number,
                    .variant = .block_close,
                };
                const index = state.push(token);
                if (parent != null) state.ast[parent.?].?.child_index = index;
                parent = null;
            },
            .end_statement => {
                // stdout.print("Statement ended on line: {any}\n", .{ line_number }) catch unreachable;
            },
            _ => check_identifier(current, stdout)
        }
        last = i;
    }

    state.write(stdout) catch @panic("Parser failed to print AST: {any}");
    stdout.flush() catch @panic("Parser failed to flush");
}

fn check_identifier(word: []u8, stdout: *std.Io.Writer) void {
   if (std.mem.eql(u8, word, "const"))
       stdout.print("Found const in line\n", .{}) catch unreachable;
}

fn unexpected(stdout: *std.Io.Writer, char: u8, line_number: u64) void {
    stdout.print("Unexpected `{c}` at line {any}\n", .{ char, line_number }) catch unreachable;
}

const State = struct {
    allocator: std.mem.Allocator,
    ast: []?Token,
    count: u64 = 0,

    const Errors = error {
        None
    };

    pub fn init(alloc: std.mem.Allocator) @This() {
        return @This() {
            .allocator = alloc,
            .ast = alloc.alloc(?Token, 16) catch @panic("State failed to allocate\n"),
        };
    }

    pub fn deinit(this: *@This()) void {
        this.allocator.free(this.ast);
    }

    pub fn push(this: *@This(), state: Token) u64 {
        if (this.count == this.ast.len + 1) {
            this.ast = this.allocator.realloc(this.ast, this.count * 2) catch @panic("State failed to reallocate\n");
        }
        this.ast[this.count] = state;
        this.count += 1;
        return this.count - 1;
    }

    pub fn write(this: *@This(), writer: *std.Io.Writer) !void {
        const printed = this.allocator.alloc(bool, this.count + 1) catch return Error.AllocationFailure;
        defer this.allocator.free(printed);
        const middle = 512;

        for (0..this.count) |index| {
            var token = this.ast[index] orelse continue;
            if (printed[index]) continue;
            var level: u64 = 0;
            var depth = this.allocator.alloc(u8, 1025) catch return Error.AllocationFailure;
            defer this.allocator.free(depth);

            depth[middle] = '|';
            try writer.print("\nToken: {any}\n", .{ token });
            try writer.flush();

            while (token.child_index != null) {
                level += 1;
                if (level >= 512) return Error.AstTooDeep;

                depth[middle + level] = '-';
                depth[middle - level] = ' ';
                const child_index = token.child_index orelse continue;
                token = this.ast[child_index].?;
                printed[child_index] = true;
                try writer.print("{s} Token: {any}\n", .{ depth[middle - level..middle + level + 1], token });
            }
        }
    }

    const Error = error {
        AstTooDeep,
        AllocationFailure,
    };
};

pub const Token = struct {
    variant: TokenType,
    line_number: u64,
    child_index: ?u64 = null,
};

pub const TokenType = enum {
    declaration,
    identifier,
    assignement,
    block_open,
    block_close,
};

const SpecialChar = enum(u8) {
    space = ' ',
    new_line = '\n',
    block_open = '{',
    block_close = '}',
    end_statement = ';',
    _
};
