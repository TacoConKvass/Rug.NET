const std = @import("std");
const Stack = @import("Stack.zig").Define;

pub fn execute(buffer: []u8, alloc: std.mem.Allocator) !State {
    var index: u64 = 0;
    var line_number: u64 = 1;
    var token_start: u64 = 0;
    var line_start_char: u64 = 0;

    const mode: Mode = .start;

    var state = State {
        .ast = .init(alloc, 2),
        .printed = &.{},
        .allocator = alloc,
    };

    tokenizer: switch (mode) {
        .start => {
            if (index >= buffer.len) break :tokenizer;

            const char = buffer[index];
            token_start = index;
            index += 1;
            switch (char) {
                '0'...'9' => continue :tokenizer .int,
                '\n' => {
                    line_number += 1;
                    line_start_char = index;
                    continue :tokenizer .start;
                },
                'a'...'z', 'A'...'Z', '_' => continue :tokenizer .identifier,
                ' ' => continue :tokenizer .start,
                ';' => {
                    _ = try state.ast.push(Token{ 
                        .tag = .semicolon,
                        .value = &.{},
                        .children = .init(alloc, 0),
                        .line_number = line_number,
                        .start_char = token_start - line_start_char,
                    });
                    continue :tokenizer .start;
                },
                '"' => continue :tokenizer .string,
                '+', '-', '*', '/', '=', '!', '<', '>', '%' => continue :tokenizer .operator,
                '(', ')', '{', '}' , '[', ']' => continue :tokenizer .paren,
                '|' => continue :tokenizer .pipe,
                '&' => continue :tokenizer .ampersand,
                '.' => continue :tokenizer .dot,
                ',' => {
                    _ = try state.ast.push(Token{ 
                        .tag = .comma,
                        .value = &.{},
                        .children = .init(alloc, 0),
                        .line_number = line_number,
                        .start_char = token_start - line_start_char,
                    });
                    continue :tokenizer .start;
                },
                else => continue :tokenizer .start,
            }
        },
        .int => {
            if (index >= buffer.len) {
                _ = try state.ast.push(Token{
                    .tag = .literal_int,
                    .value = buffer[token_start..index - 1],
                    .children = .init(alloc, 1),
                    .line_number = line_number,
                    .start_char = token_start - line_start_char,
                });
                break :tokenizer;
            }

            const char = buffer[index];
            index += 1;
            switch (char) {
                '0'...'9' => continue :tokenizer .int,
                '.' => continue :tokenizer .float,
                else => {
                    _ = try state.ast.push(Token{
                        .tag = .literal_int,
                        .value = buffer[token_start..index - 1],
                        .children = .init(alloc, 1),
                        .line_number = line_number,
                        .start_char = token_start - line_start_char,
                    });
                    continue :tokenizer .start;
                },
            }
        },
        .float => {
            if (index >= buffer.len) {
                _ = try state.ast.push(Token{
                    .tag = .literal_float,
                    .value = buffer[token_start..index - 1],
                    .children = .init(alloc, 1),
                    .line_number = line_number,
                    .start_char = token_start - line_start_char,
                });
                break :tokenizer;
            }
            
            const char = buffer[index];
            index += 1;

            switch (char) {
                '.' => {
                    if (buffer[index - 2] == '.') {
                        continue :tokenizer .range;
                    }
                    continue :tokenizer .float;
                },
                '0'...'9' => continue :tokenizer .float,
                else => {
                    _ = try state.ast.push(Token{
                        .tag = .literal_float,
                        .value = buffer[token_start..index - 1],
                        .children = .init(alloc, 1),
                        .line_number = line_number,
                        .start_char = token_start - line_start_char,
                    });
                    continue :tokenizer .start;
                }
            }
        },
        .range => {
            if (index >= buffer.len) {
                _ = try state.ast.push(Token{
                    .tag = .literal_range,
                    .value = buffer[token_start..index - 1],
                    .children = .init(alloc, 1),
                    .line_number = line_number,
                    .start_char = token_start - line_start_char,
                });
                break :tokenizer;
            }
            
            const char = buffer[index];
            index += 1;

            switch (char) {
                '0'...'9' => continue :tokenizer .range,
                else => {
                    _ = try state.ast.push(Token{
                        .tag = .literal_range,
                        .value = buffer[token_start..index - 1],
                        .children = .init(alloc, 1),
                        .line_number = line_number,
                        .start_char = token_start - line_start_char,
                    });
                    index -= 1;
                    continue :tokenizer .start;
                }
            }
        },
        .identifier => {
            if (index >= buffer.len) {
                _ = try state.ast.push(Token{
                    .tag = Token.keywords.get(buffer[token_start..index - 1]) orelse .identifier,
                    .value = buffer[token_start..index - 1],
                    .children = .init(alloc, 1),
                    .line_number = line_number,
                    .start_char = token_start - line_start_char,
                });
                break :tokenizer;
            }
            
            const char = buffer[index];
            index += 1;
            
            switch (char) {
                'a'...'z', 'A'...'Z', '0'...'9', '_' => continue :tokenizer .identifier,
                else => {
                    _ = try state.ast.push(Token{
                        .tag = Token.keywords.get(buffer[token_start..index - 1]) orelse .identifier,
                        .value = buffer[token_start..index - 1],
                        .children = .init(alloc, 1),
                        .line_number = line_number,
                        .start_char = token_start - line_start_char,
                    });
                    index -= 1;
                    continue :tokenizer .start;
                }
            }
        },
        .string => {
            if (index >= buffer.len) {
                _ = try state.ast.push(Token{
                    .tag = .literal_str,
                    .value = buffer[token_start..index - 1],
                    .children = .init(alloc, 1),
                    .line_number = line_number,
                    .start_char = token_start - line_start_char,
                });
                break :tokenizer;
            }
            
            const char = buffer[index];
            index += 1;

            switch (char) {
                '"' => {
                    if (buffer[index - 2] == '\\') continue :tokenizer .string;

                    _ = try state.ast.push(Token{
                        .tag = .literal_str,
                        .value = buffer[token_start..index],
                        .children = .init(alloc, 1),
                        .line_number = line_number,
                        .start_char = token_start - line_start_char,
                    });
                    continue :tokenizer .start;
                },
                else => continue :tokenizer .string,
            }
        },
        .operator => {
            if (index >= buffer.len) {
                _ = try state.ast.push(Token{
                    .tag = Token.operators.get(buffer[token_start..index - 1]) orelse .operator_unknown,
                    .value = buffer[token_start..index - 1],
                    .children = .init(alloc, 1),
                    .line_number = line_number,
                    .start_char = token_start - line_start_char,
                });
                break :tokenizer;
            }
            
            const char = buffer[index];
            index += 1;

            switch (char) {
                '+', '-', '*', '/', '=', '!', '<', '>', '|', '%', '&' => continue :tokenizer .operator,
                else => {
                    _ = try state.ast.push(Token{
                        .tag = Token.operators.get(buffer[token_start..index - 1]) orelse .operator_unknown,
                        .value = buffer[token_start..index - 1],
                        .children = .init(alloc, 1),
                        .line_number = line_number,
                        .start_char = token_start - line_start_char,
                    });
                    continue :tokenizer .start;
                }
            }
        },
        .ampersand => {
            if (index >= buffer.len) {
                _ = try state.ast.push(Token{
                    .tag = Token.operators.get(buffer[token_start..index - 1]) orelse .operator_unknown,
                    .value = buffer[token_start..index - 1],
                    .children = .init(alloc, 1),
                    .line_number = line_number,
                    .start_char = token_start - line_start_char,
                });
                break :tokenizer;
            }

            const char = buffer[index];
            index += 1;

            switch (char) {
                'a'...'z', 'A'...'Z', '_' => {
                    _ = try state.ast.push(Token{ 
                        .tag = .pointer_ref,
                        .value = &.{},
                        .children = .init(alloc, 1),
                        .line_number = line_number,
                        .start_char = token_start - line_start_char,
                    });

                    continue :tokenizer .start;
                },
                else => continue :tokenizer .operator,
            }
        },
        .pipe => {
            if (index >= buffer.len) {
                _ = try state.ast.push(Token{
                    .tag = Token.operators.get(buffer[token_start..index - 1]) orelse .operator_unknown,
                    .value = buffer[token_start..index - 1],
                    .children = .init(alloc, 1),
                    .line_number = line_number,
                    .start_char = token_start - line_start_char,
                });
                break :tokenizer;
            }

            const char = buffer[index];

            switch (char) {
                'a'...'z', 'A'...'Z', '_' => {
                    _ = try state.ast.push(Token{ 
                        .tag = .capture,
                        .value = &.{},
                        .children = .init(alloc, 1),
                        .line_number = line_number,
                        .start_char = token_start - line_start_char,
                    });

                    continue :tokenizer .start;
                },
                else => {
                    continue :tokenizer .operator;
                },
            }
        },
        .paren => {
            _ = try state.ast.push(Token{
                .tag = Token.parentheses.get(buffer[token_start..index]) orelse .operator_unknown,
                .value = buffer[token_start..index],
                .children = .init(alloc, 1),
                .line_number = line_number,
                .start_char = token_start - line_start_char,
            });

            continue :tokenizer .start;
        },
        .dot => continue :tokenizer .start,
    }
    return state;
}

pub const Mode = enum {
    start,
    int,
    float,
    range,
    identifier,
    string,
    operator,
    pipe,
    ampersand,
    dot,
    paren,
};

pub const Token = struct {
    tag: Type,
    value: []u8,
    children: Stack(u64),
    line_number: u64,
    start_char: u64,

    pub const Type = enum {
        declaration_const,
        declaration_var,
        operator_add,
        operator_add_assign,
        operator_sub,
        operator_sub_assign,
        operator_mult,
        operator_mult_assign,
        operator_div,
        operator_div_assign,
        operator_mod,
        operator_mod_assign,
        operator_eql,
        operator_not_eql,
        operator_assign,
        operator_gt,
        operator_gt_eql,
        operator_ls,
        operator_ls_eql,
        operator_shift_l,
        operator_shift_r,
        operator_bit_and,
        operator_bit_or,
        operator_negate,
        operator_unknown,
        block_open,
        block_close,
        paren_open,
        paren_close,
        index_open,
        index_close,
        identifier,
        literal_str,
        literal_char,
        literal_int,
        literal_float,
        literal_range,
        keyword_fn,
        keyword_struct,
        keyword_pub,
        keyword_for,
        keyword_while,
        keyword_if,
        keyword_break,
        keyword_and,
        keyword_or,
        pointer_ref,
        pointer_deref,
        capture,
        comma,
        type_hint,
        semicolon,
        drop_value,
    };
    
    pub const keywords = std.StaticStringMap(Type).initComptime(.{
        .{ "const", .declaration_const },
        .{ "var", .declaration_var },
        .{ "struct", .keyword_struct },
        .{ "fn", .keyword_fn },
        .{ "for", .keyword_for },
        .{ "while", .keyword_while },
        .{ "if", .keyword_if },
        .{ "and", .keyword_and },
        .{ "or", .keyword_or },
    });

    pub const operators = std.StaticStringMap(Type).initComptime(.{
        .{ "_", .drop_value },
        .{ "=", .operator_assign },
        .{ "-", .operator_sub },
        .{ "+", .operator_add },
        .{ "/", .operator_div },
        .{ "*", .operator_mult },
        .{ "%", .operator_mod },
        .{ "|", .operator_bit_or },
        .{ "&", .operator_bit_or },
        .{ "!", .operator_negate },
        .{ "<<", .operator_shift_l },
        .{ ">>", .operator_shift_r },
        .{ "==", .operator_eql },
        .{ "!=", .operator_not_eql },
    });

    pub const parentheses = std.StaticStringMap(Type).initComptime(.{
        .{ "(", .paren_open },
        .{ ")", .paren_close },
        .{ "{", .block_open },
        .{ "}", .block_close },
        .{ "[", .index_open },
        .{ "]", .index_close },
    });
};

pub const State = struct {
    ast: Stack(Token),
    printed: []bool,
    allocator: std.mem.Allocator,

    pub const Error = std.mem.Allocator.Error || std.Io.Writer.Error;

    pub fn deinit(this: *@This()) void {
        this.ast.deinit();
        this.allocator.free(this.printed);
    }

    pub fn write(this: *@This(), writer: *std.Io.Writer, alloc: std.mem.Allocator) Error!void {
        this.printed = try this.allocator.alloc(bool, this.ast.count + 1);
        defer this.allocator.free(this.printed);

        for (0..this.ast.count) |index| {
            try this.printToken(writer, index, 0, alloc);
        }
    }

    fn printToken(this: *@This(), writer: *std.Io.Writer, token_index: u64, level: u64, alloc: std.mem.Allocator) !void {
        if (this.printed[token_index]) return;
        const token = this.ast.buffer[token_index].?;

        for (0..level) |_|
            _ = try writer.write(&.{' '});
        
        if (token.children.count == 0) {
            try writer.print("|- Token {any}: .{{ {any}, {s}, .child = {any} }}\n", .{
                token_index,
                token.tag,
                token.value,
                &.{},
            });
            this.printed[token_index] = true;
            return;
        }

        try writer.print("|- Token {any}: .{{ {any}, {s}, .child = {any} }}\n", .{
            token_index,
            token.tag,
            token.value,
            token.children.buffer[0..token.children.count],
        });
        this.printed[token_index] = true;

        for (0..token.children.count) |i|
            try this.printToken(writer, token.children.buffer[i].?, level + 1, alloc);
    }
};

