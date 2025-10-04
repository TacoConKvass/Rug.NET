const std = @import("std");
const collections = @import("collections.zig");

pub fn execute(stdout: *std.Io.Writer, buffer: []u8) !State {
    var last: u64 = 0;
    var line_number: u64 = 1;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var state = State.init(arena.allocator());
    defer state.deinit();

    var parent = collections.Stack(?u64).init(arena.allocator(), 8);
    defer parent.deinit();

    var i: u64 = 1;
    while (i < buffer.len) {
        var char: SpecialChar = @enumFromInt(buffer[i - 1 .. i][0]);
        switch (char) {
            .space, .colon => {},
            .new_line => {
                line_number += 1;
            },
            .block_open => {
                const token = Token{
                    .child_index_queue = .init(arena.allocator(), 2),
                    .line_number = line_number,
                    .variant = .{ .block = .open },
                };

                try pushAndUpdateParent(&state, token, &parent);
            },
            .block_close => {
                const token = Token{
                    .child_index_queue = .init(arena.allocator(), 2),
                    .line_number = line_number,
                    .variant = .{ .block = .close },
                };

                try pushAndUpdateParent(&state, token, &parent);
                while (parent.count > 0) {
                    const index = parent.pop() catch unreachable;
                    const variant = state.ast[index.?].?.variant;
                    if (variant == .block and variant.block == .open) {
                        if (parent.count > 0) _ = try parent.pop();
                        break;
                    }
                }
            },
            .end_statement => {
                while (parent.count > 0) {
                    const index = parent.pop() catch unreachable;
                    const variant = state.ast[index.?].?.variant;
                    if (variant == .block and variant.block == .open) {
                        _ = try parent.push(index);
                        break;
                    }
                    if (variant == .declaration) {
                        // _ = try parent.push(index);
                        break;
                    }
                }
            },
            .comma => {
                while (parent.count > 0) {
                    const index = parent.pop() catch unreachable;
                    const variant = state.ast[index.?].?.variant;
                    if (variant == .block and variant.block == .open) {
                        _ = try parent.push(index);
                        break;
                    }
                    if (variant == .parameter_list and variant.parameter_list == .open) {
                        // _ = try parent.push(index);
                        break;
                    }
                }
            },
            .equals => {
                var token = Token{
                    .child_index_queue = .init(arena.allocator(), 2),
                    .line_number = line_number,
                    .variant = undefined,
                };

                i += 1;
                char = @enumFromInt(buffer[i - 1 .. i][0]);
                switch (char) {
                    .equals => token.variant = .{ .operator = .equal },
                    .greater => token.variant = .{ .operator = .lambda },
                    else => {
                        i -= 1;
                        token.variant = TokenType.assignment;
                    },
                }

                try pushAndUpdateParent(&state, token, &parent);
            },
            .greater => {
                var token = Token{
                    .child_index_queue = .init(arena.allocator(), 2),
                    .line_number = line_number,
                    .variant = undefined,
                };

                i += 1;
                char = @enumFromInt(buffer[i - 1 .. i][0]);
                switch (char) {
                    .equals => token.variant = .{ .operator = .greater_or_equal },
                    else => {
                        i -= 1;
                        token.variant = .{ .operator = .greater_than };
                    },
                }

                try pushAndUpdateParent(&state, token, &parent);
            },
            .lesser => {
                var token = Token{
                    .child_index_queue = .init(arena.allocator(), 2),
                    .line_number = line_number,
                    .variant = undefined,
                };

                i += 1;
                char = @enumFromInt(buffer[i - 1 .. i][0]);
                switch (char) {
                    .equals => token.variant = .{ .operator = .less_or_equal },
                    else => {
                        i -= 1;
                        token.variant = .{ .operator = .less_than };
                    },
                }

                try pushAndUpdateParent(&state, token, &parent);
            },
            .brace_open => {
                const token = Token{
                    .child_index_queue = .init(arena.allocator(), 2),
                    .line_number = line_number,
                    .variant = .{ .parameter_list = .open },
                };

                try pushAndUpdateParent(&state, token, &parent);
            },
            .brace_close => {
                const token = Token{
                    .child_index_queue = .init(arena.allocator(), 2),
                    .line_number = line_number,
                    .variant = .{ .parameter_list = .close },
                };

                try pushAndUpdateParent(&state, token, &parent);
                while (parent.count > 0) {
                    const index = parent.pop() catch unreachable;
                    const variant = state.ast[index.?].?.variant;
                    if (variant == .parameter_list and variant.parameter_list == .open) {
                        break;
                    }
                }
            },
            .quote => {
                i += 1;
                char = @enumFromInt(buffer[i - 1 .. i][0]);
                while (char != .quote) {
                    i += 1;
                    char = @enumFromInt(buffer[i - 1 .. i][0]);
                }

                const token = Token{
                    .child_index_queue = .init(arena.allocator(), 2),
                    .line_number = line_number,
                    .variant = .{ .literal = .{ .string = buffer[last..i] } },
                };

                try pushAndUpdateParent(&state, token, &parent);
            },
            .none, _ => {
                var token = checkComplexToken(arena.allocator(), buffer, last, &i);
                token.line_number = line_number;

                try pushAndUpdateParent(&state, token, &parent);
            },
        }
        last = i;
        i += 1;
    }

    try state.write(stdout);
    try stdout.flush();
    return state;
}

fn pushAndUpdateParent(state: *State, token: Token, parent: *collections.Stack(?u64)) !void {
    const index = state.push(token);

    const parent_index = parent.*.peek() catch null;
    if (parent_index != null and state.ast[parent_index.?].?.child_index_queue != null)
        _ = try state.ast[parent_index.?].?.child_index_queue.?.push(index);
    _ = try parent.*.push(index);
}

fn checkComplexToken(alloc: std.mem.Allocator, buf: []u8, last: u64, index: *u64) Token {
    var found = false;

    while (!found and index.* < buf.len - 1) {
        const char: SpecialChar = @enumFromInt(buf[index.* .. index.* + 1][0]);
        switch (char) {
            _ => {},
            else => {
                found = true;
                break;
            },
        }
        index.* += 1;
    }

    const word = buf[last..index.*];
    var token_type: TokenVariant = undefined;

    var is_const = false;
    var is_struct = false;
    var is_fn = false;
    var is_if = false;

    if (std.mem.eql(u8, word, "const")) {
        is_const = true;
        token_type = TokenVariant.declaration;
    } else if (std.mem.eql(u8, word, "var")) {
        token_type = TokenVariant.declaration;
    } else if (std.mem.eql(u8, word, "struct")) {
        is_struct = true;
        token_type = TokenVariant.keyword;
    } else if (std.mem.eql(u8, word, "fn")) {
        is_fn = true;
        token_type = TokenVariant.keyword;
    } else if (std.mem.eql(u8, word, "if")) {
        is_if = true;
        token_type = TokenVariant.keyword;
    } else token_type = TokenVariant.identifier;

    return Token{
        .child_index_queue = .init(alloc, 1),
        .variant = switch (token_type) {
            .declaration => TokenType{ .declaration = if (is_const) .constant else .variable },
            .identifier => TokenType{ .identifier = word },
            // zig fmt: off
            .keyword => TokenType{
                .keyword =
                    if (is_struct) .structure 
                    else if (is_fn) .function
                    else if (is_if) .if_statement
                    else .structure
            },
            // zig fmt: on
            else => unreachable,
        },
    };
}

const State = struct {
    allocator: std.mem.Allocator,
    ast: []?Token,
    count: u64 = 0,
    printed: []bool,

    const Error = error{
        AstTooDeep,
        OutOfMemory,
    } || std.Io.Writer.Error || std.mem.Allocator.Error;

    pub fn init(alloc: std.mem.Allocator) @This() {
        return @This(){
            .allocator = alloc,
            .ast = alloc.alloc(?Token, 16) catch @panic("State failed to allocate\n"),
            .printed = undefined,
        };
    }

    pub fn deinit(this: *@This()) void {
        this.allocator.free(this.ast);
    }

    pub fn push(this: *@This(), state: Token) u64 {
        if (this.count == this.ast.len) {
            this.ast = this.allocator.realloc(this.ast, this.count * 2) catch @panic("State failed to reallocate\n");
        }

        this.ast[this.count] = state;
        this.count += 1;
        return this.count - 1;
    }

    pub fn write(this: *@This(), writer: *std.Io.Writer) Error!void {
        this.printed = this.allocator.alloc(bool, this.count + 1) catch return error.OutOfMemory;
        defer this.allocator.free(this.printed);

        for (0..this.count) |index| {
            try this.printToken(writer, index, 0);
        }
    }

    fn printToken(this: *@This(), writer: *std.Io.Writer, token_index: u64, level: u64) !void {
        if (this.printed[token_index]) return;
        const token = this.ast[token_index].?;

        if (token.child_index_queue == null or token.child_index_queue.?.count == 0) {
            for (0..level) |_|
                _ = try writer.write(&.{' '}); // indent

            try writer.print("|- Token {any}: .{{ {s} .line = {any}, .child = {any} }}\n", .{
                token_index,
                token.variantName() catch "",
                token.line_number,
                &.{},
            });
            this.printed[token_index] = true;
            return;
        }

        var children_stack = token.child_index_queue.?;
        for (0..level) |_|
            _ = try writer.write(&.{' '}); // indent
        try writer.print("|- Token {any}: .{{ {s} .line = {any}, .child = {any} }}\n", .{
            token_index,
            token.variantName() catch "",
            token.line_number,
            children_stack.buffer[0..children_stack.count],
        });
        this.printed[token_index] = true;

        for (0..children_stack.count) |i|
            try this.printToken(writer, children_stack.buffer[i].?.?, level + 1);
    }
};

pub const Token = struct {
    variant: TokenType,
    line_number: u64 = 0,
    child_index_queue: ?collections.Stack(?u64),

    pub fn variantName(this: *const @This()) ![]u8 {
        var buffer: [256]u8 = undefined;
        if (this.variant == .identifier) {
            return std.fmt.bufPrint(&buffer, ".{{ .identifier = {s} }}", .{this.variant.identifier});
        }
        if (this.variant == .assignment) {
            return std.fmt.bufPrint(&buffer, ".{{ .assignement }}", .{});
        }
        if (this.variant == .literal) {
            if (this.variant.literal == .string) {
                return std.fmt.bufPrint(&buffer, ".{{ .string_literal = {s} }}", .{this.variant.literal.string});
            } else return std.fmt.bufPrint(&buffer, ".{{ .int_literal = {s} }}", .{this.variant.literal.integer});
        } else return std.fmt.bufPrint(&buffer, "{any}", .{this.variant});
    }
};

pub const TokenVariant = enum {
    declaration,
    identifier,
    assignment,
    block,
    operator,
    keyword,
    literal,
    parameter_list,
};

pub const LiteralVariant = enum { string, integer };

pub const TokenType = union(TokenVariant) {
    declaration: enum { constant, variable },
    identifier: []u8,
    assignment,
    block: enum { open, close },
    operator: enum { equal, not_equal, less_than, greater_than, less_or_equal, greater_or_equal, lambda },
    keyword: enum { structure, function, if_statement },
    literal: union(LiteralVariant) { string: []u8, integer: []u8 },
    parameter_list: enum { open, close },
};

const SpecialChar = enum(u8) {
    none = 0,
    space = ' ',
    new_line = '\n',
    block_open = '{',
    block_close = '}',
    end_statement = ';',
    equals = '=',
    lesser = '<',
    greater = '>',
    brace_open = '(',
    brace_close = ')',
    colon = ':',
    quote = '"',
    comma = ',',
    _,
};
