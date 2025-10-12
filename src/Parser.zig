const std = @import("std");
const collections = @import("collections.zig");

pub fn execute(buffer: []u8, alloc: std.mem.Allocator) !State {
    var last: u64 = 0;
    var line_number: u64 = 1;
    var state = State.init(alloc);

    var parent = collections.Stack(?u64).init(alloc, 8);
    defer parent.deinit();

    var i: u64 = 1;
    while (i < buffer.len) {
        var char: SpecialChar = @enumFromInt(buffer[i - 1 .. i][0]);
        switch (char) {
            .space, .colon, .dot, .quote => {},
            .new_line => {
                line_number += 1;
            },
            .block_open => {
                if (parent.count > 0) {
                    var index = parent.pop() catch break;
                    if (state.ast[index.?].?.variant == .capture) capture_check: {
                        index = parent.pop() catch break :capture_check;
                        while (parent.count > 0 and state.ast[index.?].?.variant != .capture) {
                            index = parent.pop() catch break :capture_check;
                        }
                        // _ = try parent.pop();
                    } else {
                        _ = try parent.push(index);
                    }
                }

                const token = Token{
                    .child_index_queue = .init(alloc, 2),
                    .line_number = line_number,
                    .variant = .{ .block = .open },
                };

                try pushAndUpdateParent(&state, token, &parent);
            },
            .block_close => {
                const token = Token{
                    .child_index_queue = .init(alloc, 2),
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
                        break;
                    }
                    if (variant == .capture) {
                        break;
                    }
                }
            },
            .equals => {
                var token = Token{
                    .child_index_queue = .init(alloc, 2),
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
                    .child_index_queue = .init(alloc, 2),
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
                    .child_index_queue = .init(alloc, 2),
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
                    .child_index_queue = .init(alloc, 2),
                    .line_number = line_number,
                    .variant = .{ .parameter_list = .open },
                };

                try pushAndUpdateParent(&state, token, &parent);
            },
            .brace_close => {
                const token = Token{
                    .child_index_queue = .init(alloc, 2),
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
            .double_quote => {
                i += 1;
                char = @enumFromInt(buffer[i - 1 .. i][0]);
                while (char != .double_quote) {
                    i += 1;
                    char = @enumFromInt(buffer[i - 1 .. i][0]);
                }

                const token = Token{
                    .child_index_queue = .init(alloc, 2),
                    .line_number = line_number,
                    .variant = .{ .literal = .{ .string = buffer[last..i] } },
                };

                try pushAndUpdateParent(&state, token, &parent);
            },
            .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine => {
                var token = checkNumberLiteral(alloc, buffer, last, &i);
                token.line_number = line_number;

                try pushAndUpdateParent(&state, token, &parent);
            },
            .capture => {
                const token_capture_open = Token{
                    .child_index_queue = .init(alloc, 2),
                    .variant = .capture,
                    .line_number = line_number,
                };

                try pushAndUpdateParent(&state, token_capture_open, &parent);
            },
            .underscore, _ => {
                var token = checkComplexToken(alloc, buffer, last, &i);
                token.line_number = line_number;

                try pushAndUpdateParent(&state, token, &parent);
            },
        }
        last = i;
        i += 1;
    }

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
            _,
            .zero,
            .one,
            .two,
            .three,
            .four,
            .five,
            .six,
            .seven,
            .eight,
            .nine,
            .underscore,
            => {},
            else => {
                found = true;
                break;
            },
        }
        index.* += 1;
    }

    const word = buf[last..index.*];

    return Token{
        .child_index_queue = .init(alloc, 1),
        .variant = keywords.get(word) orelse TokenType{ .identifier = word },
    };
}

fn checkNumberLiteral(alloc: std.mem.Allocator, buffer: []u8, last: u64, i: *u64) Token {
    i.* += 1;
    var char: SpecialChar = @enumFromInt(buffer[i.* - 1 .. i.*][0]);
    var is_float = false;
    var is_range = false;
    while (true) {
        switch (char) {
            .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine => {},
            .dot => {
                if (is_range or is_float) continue; // Invalid but this is going to be detected in the next phase
                i.* += 1;
                char = @enumFromInt(buffer[i.* - 1 .. i.*][0]);
                switch (char) {
                    .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine => is_float = true,
                    .dot => is_range = true,
                    else => break,
                }
            },
            else => break,
        }
        i.* += 1;
        char = @enumFromInt(buffer[i.* - 1 .. i.*][0]);
    }

    i.* -= 1;
    const word = buffer[last..i.*];

    return Token{
        .child_index_queue = .init(alloc, 2),
        // zig fmt: off
        .variant = .{ .literal =
            if (is_float) .{ .float = word }
            else if (is_range) .{ .range = word }
            else .{ .integer = word },
        },
        // zig fmt: on
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
        for (this.ast) |*token| {
            if (token.* == null) continue;
            token.*.?.child_index_queue.?.deinit();
        }
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

    pub fn write(this: *@This(), writer: *std.Io.Writer, alloc: std.mem.Allocator) Error!void {
        this.printed = this.allocator.alloc(bool, this.count + 1) catch return error.OutOfMemory;
        defer this.allocator.free(this.printed);

        for (0..this.count) |index| {
            try this.printToken(writer, index, 0, alloc);
        }
    }

    fn printToken(this: *@This(), writer: *std.Io.Writer, token_index: u64, level: u64, alloc: std.mem.Allocator) !void {
        if (this.printed[token_index]) return;
        const token = this.ast[token_index].?;

        if (token.child_index_queue == null or token.child_index_queue.?.count == 0) {
            for (0..level) |_|
                _ = try writer.write(&.{' '}); // indent

            try writer.print("|- Token {any}: .{{ {s} .line = {any}, .child = {any} }}\n", .{
                token_index,
                token.variantName(alloc) catch "",
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
            token.variantName(alloc) catch "",
            token.line_number,
            children_stack.buffer[0..children_stack.count],
        });
        this.printed[token_index] = true;

        for (0..children_stack.count) |i|
            try this.printToken(writer, children_stack.buffer[i].?.?, level + 1, alloc);
    }
};

pub const Token = struct {
    variant: TokenType,
    line_number: u64 = 0,
    child_index_queue: ?collections.Stack(?u64),

    pub fn variantName(this: *const @This(), alloc: std.mem.Allocator) ![]u8 {
        return try switch (this.variant) {
            .identifier => |id| std.fmt.allocPrint(alloc, ".{{ .identifier = {s} }}", .{id}),
            .assignment => std.fmt.allocPrint(alloc, ".{{ .assignement }}", .{}),
            .literal => |literal| switch (this.variant.literal) {
                .string => std.fmt.allocPrint(alloc, ".{{ .string_literal = {s} }}", .{literal.string}),
                .integer => std.fmt.allocPrint(alloc, ".{{ .int_literal = {s} }}", .{literal.integer}),
                .float => std.fmt.allocPrint(alloc, ".{{ .float_literal = {s} }}", .{literal.float}),
                .range => std.fmt.allocPrint(alloc, ".{{ .range_literal = {s} }}", .{literal.range}),
                .boolean => std.fmt.allocPrint(alloc, ".{{ .bool_literal = {any} }}", .{literal.boolean}),
            },
            .capture => std.fmt.allocPrint(alloc, ".{{ .capture }}", .{}),
            else => std.fmt.allocPrint(alloc, "{any}", .{this.variant}),
        };
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
    capture,
};

pub const LiteralVariant = enum {
    string,
    integer,
    float,
    boolean,
    range,
};

pub const TokenType = union(TokenVariant) {
    declaration: enum { constant, variable },
    identifier: []u8,
    assignment,
    block: enum { open, close },
    operator: enum {
        equal,
        not_equal,
        less_than,
        greater_than,
        less_or_equal,
        greater_or_equal,
        lambda,
    },
    keyword: enum {
        structure,
        function,
        if_statement,
        for_loop,
        while_loop,
    },
    literal: union(LiteralVariant) {
        string: []u8,
        integer: []u8,
        float: []u8,
        boolean: bool,
        range: []u8,
    },
    parameter_list: enum { open, close },
    capture,
};

pub const keywords = std.StaticStringMap(TokenType).initComptime(.{
    .{ "const", TokenType{ .declaration = .constant } },
    .{ "var", TokenType{ .declaration = .variable } },
    .{ "struct", TokenType{ .keyword = .structure } },
    .{ "fn", TokenType{ .keyword = .function } },
    .{ "for", TokenType{ .keyword = .for_loop } },
    .{ "while", TokenType{ .keyword = .while_loop } },
    .{ "if", TokenType{ .keyword = .if_statement } },
});

const SpecialChar = enum(u8) {
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
    quote = '\'',
    double_quote = '"',
    comma = ',',
    dot = '.',
    underscore = '_',
    capture = '|',
    zero = '0',
    one = '1',
    two = '2',
    three = '3',
    four = '4',
    five = '5',
    six = '6',
    seven = '7',
    eight = '8',
    nine = '9',
    _,
};
