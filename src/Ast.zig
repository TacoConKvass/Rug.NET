const std = @import("std");
const Tokenizer = @import("Tokenizer.zig");
const Stack = @import("Stack.zig").Define;

built: bool,
errors: [][]const u8,

pub fn from(alloc: std.mem.Allocator, tokens: []Tokenizer.Token) !@This() {
    var current_id: u64 = 0;
    if (current_id >= tokens.len) return @This(){
        .built = false,
        .errors = &.{},
    };
    var token = tokens[current_id];
    var prev_token_line: u64 = 0;

    const scope: Scope = .top_level;
    var errorStack: Stack([]const u8) = .init(alloc, 8);
    var definition_meta: DefinitionMeta = undefined;

    ast_scope: switch (scope) {
        .top_level => {
            current_id += 1;
            if (current_id - 1 >= tokens.len) break :ast_scope;
            prev_token_line = token.line_number;
            token = tokens[current_id - 1];
            switch (token.tag) {
                .declaration => {
                    definition_meta = DefinitionMeta{
                        .public = false,
                        .name = "",
                        .type_hint = "",
                    };
                    continue :ast_scope .definition;
                },
                .visibility => {
                    continue :ast_scope .publicize;
                },
                else => {
                    continue :ast_scope .top_level;
                },
            }
        },
        .publicize => {
            definition_meta = DefinitionMeta{
                .public = true,
                .name = "",
                .type_hint = "",
            };
            current_id += 1;
            if (current_id - 1 >= tokens.len) {
                _ = try add_error(&errorStack, "Line {}:\n\tExpected 'const' or 'var', found 'EOF'", .{prev_token_line});
                break :ast_scope;
            }

            prev_token_line = token.line_number;
            token = tokens[current_id - 1];
            if (token.tag != .declaration) {
                _ = try add_error(&errorStack, "Line {}:\n\tExpected 'const' or 'var', found '{s}'", .{ prev_token_line, token.value });
                continue :ast_scope .top_level;
            }
            continue :ast_scope .definition;
        },
        .definition => {
            current_id += 1;
            if (current_id - 1 >= tokens.len) {
                _ = try add_error(&errorStack, "Line {}:\n\tExpected identifier, found 'EOF'", .{prev_token_line});
                break :ast_scope;
            }

            prev_token_line = token.line_number;
            token = tokens[current_id - 1];
            if (token.tag != .identifier) {
                _ = try add_error(&errorStack, "Line {}:\n\tExpected identifier, found '{s}'", .{ prev_token_line, token.value });
                continue :ast_scope .top_level;
            }
            definition_meta.name = token.value;

            current_id += 1;
            if (current_id - 1 >= tokens.len) {
                _ = try add_error(&errorStack, "Line {}:\n\tExpected '=', found 'EOF'", .{prev_token_line});
                break :ast_scope;
            }

            prev_token_line = token.line_number;
            token = tokens[current_id - 1];
            if (token.tag != .assign_op) {
                _ = try add_error(&errorStack, "Line {}:\n\tExpected identifier, found '{s}'", .{ prev_token_line, token.value });
                continue :ast_scope .top_level;
            }

            current_id += 1;
            if (current_id - 1 >= tokens.len) {
                _ = try add_error(&errorStack, "Line {}:\n\tExpected expression, found 'EOF'", .{prev_token_line});
                break :ast_scope;
            }

            prev_token_line = token.line_number;
            token = tokens[current_id - 1];
            switch (token.tag) {
                .key_func => {
                    continue :ast_scope .function;
                },
                .builtin => {},
                else => {
                    _ = try add_error(&errorStack, "Line {}:\n\tExpected expression, found '{s}'", .{ prev_token_line, token.value });
                },
            }
            continue :ast_scope .top_level;
        },
        .end_definition => {
            current_id += 1;
            if (current_id - 1 >= tokens.len) {
                _ = try add_error(&errorStack, "Line {}:\n\tExpected ';', found 'EOF'", .{prev_token_line});
                break :ast_scope;
            }

            prev_token_line = token.line_number;
            token = tokens[current_id - 1];
            if (token.tag != .semicolon) {
                _ = try add_error(&errorStack, "Line {}:\n\tExpected ';', found '{s}'", .{ prev_token_line, token.value });
            }
            continue :ast_scope .top_level;
        },
        .function => {
            current_id += 1;
            if (current_id - 1 >= tokens.len) {
                _ = try add_error(&errorStack, "Line {}:\n\tExpected '(', found 'EOF'", .{prev_token_line});
                break :ast_scope;
            }

            prev_token_line = token.line_number;
            token = tokens[current_id - 1];
            if (token.tag != .paren_open) {
                _ = try add_error(&errorStack, "Line {}:\n\tExpected '(', found '{s}'", .{ prev_token_line, token.value });
                continue :ast_scope .top_level;
            }

            _ = parse_params();

            current_id += 1;
            if (current_id - 1 >= tokens.len) {
                _ = try add_error(&errorStack, "Line {}:\n\tExpected ')', found 'EOF'", .{prev_token_line});
                break :ast_scope;
            }

            prev_token_line = token.line_number;
            token = tokens[current_id - 1];
            if (token.tag != .paren_close) {
                _ = try add_error(&errorStack, "Line {}:\n\tExpected ')', found '{s}'", .{ prev_token_line, token.value });
                continue :ast_scope .top_level;
            }

            current_id += 1;
            if (current_id - 1 >= tokens.len) {
                _ = try add_error(&errorStack, "Line {}:\n\tExpected return type, found 'EOF'", .{prev_token_line});
                break :ast_scope;
            }

            prev_token_line = token.line_number;
            token = tokens[current_id - 1];
            if (token.tag != .identifier) {
                _ = try add_error(&errorStack, "Line {}:\n\tExpected return type, found '{s}'", .{ prev_token_line, token.value });
                continue :ast_scope .top_level;
            }

            current_id += 1;
            if (current_id - 1 >= tokens.len) {
                _ = try add_error(&errorStack, "Line {}:\n\tExpected '{{', found 'EOF'", .{prev_token_line});
                break :ast_scope;
            }

            prev_token_line = token.line_number;
            token = tokens[current_id - 1];
            if (token.tag != .block_open) {
                _ = try add_error(&errorStack, "Line {}:\n\tExpected '{{', found '{s}'", .{ prev_token_line, token.value });
                continue :ast_scope .top_level;
            }

            current_id += 1;
            if (current_id - 1 >= tokens.len) {
                _ = try add_error(&errorStack, "Line {}:\n\tExpected '}}', found 'EOF'", .{prev_token_line});
                break :ast_scope;
            }

            prev_token_line = token.line_number;
            token = tokens[current_id - 1];
            var block_depth: u16 = 1;
            func_body: switch (token.tag) {
                .block_close => {
                    block_depth -= 1;
                    if (block_depth == 0) break :func_body;

                    current_id += 1;
                    if (current_id - 1 >= tokens.len) {
                        _ = try add_error(&errorStack, "Line {}:\n\tExpected statement or '}}', found 'EOF'", .{prev_token_line});
                        break :ast_scope;
                    }

                    continue :func_body tokens[current_id - 1].tag;
                },
                .block_open => {
                    block_depth += 1;

                    current_id += 1;
                    if (current_id - 1 >= tokens.len) {
                        _ = try add_error(&errorStack, "Line {}:\n\tExpected statement or '}}', found 'EOF'", .{prev_token_line});
                        break :ast_scope;
                    }

                    continue :func_body tokens[current_id - 1].tag;
                },
                else => {
                    current_id += 1;
                    if (current_id - 1 >= tokens.len) {
                        break :ast_scope;
                    }
                    continue :func_body tokens[current_id - 1].tag;
                },
            }

            continue :ast_scope .end_definition;
        },
    }

    return @This(){
        .built = errorStack.count == 0,
        .errors = errorStack.buffer[0..errorStack.count],
    };
}

pub fn parse_params() u64 {
    return 0;
}

fn add_error(stack: *Stack([]const u8), comptime fmt: []const u8, values: anytype) !void {
    const errorMessage = try std.fmt.allocPrint(stack.allocator, "\x1b[31mError:\x1b[0m " ++ fmt ++ "\n", values);
    _ = try stack.*.push(errorMessage);
}

const Scope = enum {
    top_level,
    publicize,
    definition,
    function,
    end_definition,
};

const DefinitionMeta = struct {
    public: bool,
    name: []const u8,
    type_hint: []const u8,
};
