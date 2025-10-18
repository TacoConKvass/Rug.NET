const std = @import("std");

// Last in first out queue
pub fn Define(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        buffer: []?T,
        count: u64,

        pub const Error = error{NoElement};

        pub fn init(alloc: std.mem.Allocator, count: u64) @This() {
            return @This(){
                .allocator = alloc,
                .buffer = alloc.alloc(?T, count) catch &.{},
                .count = 0,
            };
        }

        pub fn deinit(this: *@This()) void {
            this.allocator.free(this.buffer);
            this.count = 0;
        }

        pub fn push(this: *@This(), value: T) !u64 {
            const count = this.count;
            if (this.count == this.buffer.len) {
                this.buffer = try this.allocator.realloc(this.buffer, count * 2);
            }

            this.buffer[count] = value;
            this.count += 1;
            return count;
        }

        pub fn peek(this: *@This()) Error!T {
            if (this.count == 0) return error.NoElement;
            return this.buffer[this.count - 1].?;
        }

        pub fn pop(this: *@This()) Error!T {
            if (this.count == 0) return error.NoElement;

            const index = this.count - 1;
            const element = this.buffer[index];
            this.buffer[index] = null;
            this.count = index;

            return element.?;
        }
    };
}
