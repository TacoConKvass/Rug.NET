const std = @import("std");
const Stack = @import("Stack.zig").Define;

pub fn execute(alloc: std.mem.Allocator, data: []u8, previous_state: ?State) !State {
    var state = previous_state orelse State{
        .tokens = .init(alloc, 16),
    };

    const mode: Mode = .start;
    var start: u64 = 0;
    var current: u64 = 0;
    var line_num: u64 = 0;
    tokenizer: switch (mode) {
        .start => {
            current += 1;
            if (current - 1 >= data.len) break :tokenizer;
            start = current - 1;
            const char = data[start];
            switch (char) {
                'a'...'z', 'A'...'Z', '_', '@' => {
                    continue :tokenizer .identifier;
                },
                '{', '}', '(', ')', '.', ';' => {
                    const value = data[start..current];
                    _ = try state.push(Token{
                        .tag = string_to_tag.get(value).?,
                        .value = value,
                        .line_number = line_num,
                    });
                    continue :tokenizer .start;
                },
                '=' => {
                    continue :tokenizer .operator;
                },
                '\"' => {
                    continue :tokenizer .string;
                },
                '\n' => {
                    line_num += 1;
                    continue :tokenizer .start;
                },
                else => continue :tokenizer .start,
            }
        },
        .identifier => {
            current += 1;
            if (current - 1 >= data.len) {
                const value = data[start .. current - 1];
                try state.push(Token{
                    .tag = string_to_tag.get(value) orelse .identifier,
                    .value = value,
                    .line_number = line_num,
                });
                continue :tokenizer .start;
            }
            const char = data[current - 1];

            switch (char) {
                'a'...'z', 'A'...'Z', '_', '@' => {
                    continue :tokenizer .identifier;
                },
                else => {
                    const value = data[start .. current - 1];
                    try state.push(Token{
                        .tag = string_to_tag.get(value) orelse .identifier,
                        .value = value,
                        .line_number = line_num,
                    });
                    current -= 1;
                    continue :tokenizer .start;
                },
            }
        },
        .string => {
            current += 1;
            if (current - 1 >= data.len) {
                const value = data[start .. current - 1];
                try state.push(Token{
                    .tag = .str_literal,
                    .value = value,
                    .line_number = line_num,
                });
                continue :tokenizer .start;
            }
            const char = data[current - 1];

            switch (char) {
                '\"' => {
                    if (data[current - 2] == '\\') continue :tokenizer .string;
                    const value = data[start..current];
                    try state.push(Token{
                        .tag = .str_literal,
                        .value = value,
                        .line_number = line_num,
                    });

                    continue :tokenizer .start;
                },
                else => {
                    continue :tokenizer .string;
                },
            }
        },
        .operator => {
            current += 1;
            if (current - 1 >= data.len) {
                const value = data[start .. current - 1];
                try state.push(Token{
                    .tag = string_to_tag.get(value) orelse .unknown_op,
                    .value = value,
                    .line_number = line_num,
                });
                continue :tokenizer .start;
            }
            const char = data[current - 1];
            switch (char) {
                else => {
                    const value = data[start .. current - 1];
                    try state.push(Token{
                        .tag = string_to_tag.get(value) orelse .unknown_op,
                        .value = value,
                        .line_number = line_num,
                    });
                    continue :tokenizer .start;
                },
            }
        },
        // else => {
        //     continue :tokenizer .start;
        // },
    }

    return state;
}

const Mode = enum {
    start,
    identifier,
    string,
    operator,
};

pub const State = struct {
    tokens: Stack(Token),

    pub fn deinit(this: *@This()) void {
        this.tokens.deinit();
    }

    pub fn push(this: *@This(), token: Token) !void {
        _ = try this.tokens.push(token);
    }

    pub fn write(this: *@This(), alloc: std.mem.Allocator, writer: *std.Io.Writer) !void {
        _ = alloc;
        const count = this.tokens.count;
        for (0..count, this.tokens.buffer[0..count]) |i, token| {
            try writer.print("{any}\t| {any}\t| {s}\n", .{ i, token.tag, token.value });
        }
    }
};

pub const Token = struct {
    tag: Tag,
    value: []const u8,
    line_number: u64,

    pub const Tag = enum {
        declaration,
        identifier,
        assign_op,
        unknown_op,
        builtin,
        visibility,
        str_literal,
        key_func,
        field_acc,
        block_open,
        block_close,
        paren_open,
        paren_close,
        semicolon,
    };
};

const string_to_tag: std.StaticStringMap(Token.Tag) = .initComptime(&.{
    .{ "@namespace", .builtin },
    .{ "@import", .builtin },
    .{ "const", .declaration },
    .{ "var", .declaration },
    .{ "pub", .visibility },
    .{ "fn", .key_func },
    .{ "{", .block_open },
    .{ "}", .block_close },
    .{ "(", .paren_open },
    .{ ")", .paren_close },
    .{ ".", .field_acc },
    .{ ";", .semicolon },
    .{ "=", .assign_op },
});
