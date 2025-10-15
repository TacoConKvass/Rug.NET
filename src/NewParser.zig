const std = @import("std");
const Stack = @import("Stack.zig").Define;

pub fn execute(buffer: []u8, alloc: std.mem.Allocator) !State {
    std.debug.print("{s}", .{ buffer });
    return State {
        .ast = .init(alloc, 0),
    };
}

pub const Token = struct {
    tag: Type,
    value: []u8,
    children: ?Stack(u64),

    pub const Type = enum {
        declaration_const,
        declaration_var,
        operator_add,
        operator_sub,
        operator_mult,
        operator_div,
        operator_mod,
        operator_assign,
        operator_shift_l,
        operator_shift_r,
        block_open,
        block_close,
        paren_open,
        paren_close,
        identifier,
        literal_str,
        literal_int,
        literal_float,
        literal_range,
        keyword_fn,
        keyword_struct,
        keyword_pub,
        type_hint,
    };
};

pub const State = struct {
    ast: Stack(Token),
};

