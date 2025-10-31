const Tokenizer = @import("Tokenizer.zig");

pub fn from(tokens: []Tokenizer.Token) void {
    if (tokens.len == 0) return;

    var token_id = 0;
    var token = tokens[token_id];
}

pub const Node = struct {
    variant: Variant,
    line_number: u64,

    pub const Variant = union(Type) {
        type_def: Def.Type,
        func_def: Def.Function,
        field_def: Def.Field,
        decl_def: Def.Declaration,
    };

    pub const Type = enum {
        type_def,
        func_def,
        field_def,
        decl_def,
    };
};

pub const Def = struct {
    pub const Type = struct {
        visibility: Visibility,
        name: []u8,
        fields: []Field,
    };

    pub const Field = struct {
        visibility: Visibility,
        name: []u8,
        type_name: []u8,
        default_value: []u8,
    };

    pub const Function = struct {
        visibility: Visibility,
        force_inline: Inline,
        name: []u8,
        parameters: []Parameter,
        return_type_name: []u8,
        body: []union { exp: Expression, decl: Declaration },

        pub const Parameter = struct {
            name: []u8,
            type_name: []u8,
        };
    };

    pub const Declaration = struct {
        mutability: Mutability,
        name: []u8,
        value: []u8,
    };

    pub const Expression = struct {
        target: []u8,
        value: []u8,
    };

    pub const Statement = []u8;
};

pub const Mutability = enum(u1) { @"const", @"var" };

pub const Visibility = enum(u1) { internal, public };

pub const Inline = enum(u1) { yes, no };
