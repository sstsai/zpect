const std = @import("std");

/// Unsigned Integer Type
pub fn U(comptime width: usize, comptime T: type) type {
    return struct {
        value: T,
        pub const bits = width;
        pub const signed = false;
        pub const Underlying = T;
    };
}

/// Signed Integer Type
pub fn I(comptime width: usize, comptime T: type) type {
    return struct {
        value: T,
        pub const bits = width;
        pub const signed = true;
        pub const Underlying = T;
    };
}

/// Coordinate (Latitude/Longitude)
pub fn LatLon(comptime width: usize) type {
    return struct {
        value: f64,
        pub const bits = width;
        pub const scale = 600000.0;
        pub const Underlying = f64;
    };
}

/// Simple Bounded Array implementation since std.BoundedArray is missing in this env
pub fn BoundedArray(comptime T: type, comptime capacity: usize) type {
    return struct {
        buffer: [capacity]T,
        len: usize = 0,

        const Self = @This();

        pub fn init(len: usize) Self {
             return Self{
                 .buffer = [_]T{0} ** capacity,
                 .len = len,
             };
        }

        pub fn slice(self: *Self) []T {
            return self.buffer[0..self.len];
        }

        pub fn constSlice(self: Self) []const T {
            return self.buffer[0..self.len];
        }

        pub fn append(self: *Self, item: T) !void {
            if (self.len >= capacity) return error.Overflow;
            self.buffer[self.len] = item;
            self.len += 1;
        }
    };
}

/// AIS String
pub fn Str(comptime bit_len: usize) type {
    const char_count = bit_len / 6;
    return struct {
        value: BoundedArray(u8, char_count),
        pub const bits = bit_len;
        pub const is_string = true;
        pub const Underlying = BoundedArray(u8, char_count);
    };
}

test "Types compilation" {
    const TypeU = U(6, u8);
    const u = TypeU{ .value = 10 };
    try std.testing.expectEqual(@as(u8, 10), u.value);
    try std.testing.expect(TypeU.bits == 6);
}
