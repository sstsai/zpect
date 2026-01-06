const std = @import("std");

pub const BitReader = struct {
    bits: []const u1,
    cursor: usize = 0,

    pub fn readInt(self: *BitReader, comptime T: type, bit_width: usize) !T {
        if (self.cursor + bit_width > self.bits.len) {
            return error.EndOfStream;
        }

        var result: T = 0;
        const bits_slice = self.bits[self.cursor..][0..bit_width];

        // AIS: MSB first
        for (bits_slice, 0..) |bit, i| {
            if (bit == 1) {
                result |= @as(T, 1) << @intCast(bit_width - 1 - i);
            }
        }

        self.cursor += bit_width;
        return result;
    }
};

pub const BitWriter = struct {
    bits: std.ArrayList(u1),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !BitWriter {
        return BitWriter{
            .bits = try std.ArrayList(u1).initCapacity(allocator, 256),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BitWriter) void {
        self.bits.deinit(self.allocator);
    }

    pub fn writeInt(self: *BitWriter, value: anytype, bit_width: usize) !void {
        // value can be any integer type
        // MSB first
        for (0..bit_width) |i| {
            const shift_amt = bit_width - 1 - i;
            // Ensure shift_amt is treated as a runtime integer suitable for shifting.
            // We use @intCast which should work if value type is determined.
            // The issue might be that `value` is `anytype` and inferred as `comptime_int` in some calls,
            // making the compiler expect `shift_amt` to be `comptime_int`.

            // Force value to be a runtime integer if possible?
            // Or explicitly cast shift_amt to u6 or log2 type?
            // If value is u128, shift can be u7.

            // Let's deduce the type of shift amount needed for @TypeOf(value).
            const ValueType = @TypeOf(value);
            // If ValueType is comptime_int, we have a problem if shift_amt is runtime.

            // Solution: If value is comptime_int, we should cast it to a large enough runtime integer first?
            // But we don't know the max size needed.
            // However, typical usage passes explicit types from `encode`.
            // But the test passes literals `try writer.writeInt(5, 6)`. 5 is comptime_int.

            if (@typeInfo(ValueType) == .comptime_int) {
                // Cast to u128 to handle up to 128 bits?
                const v_u128: u128 = @intCast(value);
                const bit_val = (v_u128 >> @intCast(shift_amt)) & 1;
                try self.bits.append(self.allocator, @intCast(bit_val));
            } else {
                 const bit_val = (value >> @intCast(shift_amt)) & 1;
                 try self.bits.append(self.allocator, @intCast(bit_val));
            }
        }
    }
};

/// Generic Unsigned Integer Type
pub fn U(comptime width: usize, comptime T: type) type {
    return struct {
        value: T,

        const Self = @This();
        pub const bit_width = width;

        pub fn decode(reader: *BitReader) !Self {
            const val = try reader.readInt(T, width);
            return Self{ .value = val };
        }

        pub fn encode(self: Self, writer: *BitWriter) !void {
            try writer.writeInt(self.value, width);
        }
    };
}

/// Generic Signed Integer Type
pub fn I(comptime width: usize, comptime T: type) type {
    return struct {
        value: T,

        const Self = @This();
        pub const bit_width = width;

        pub fn decode(reader: *BitReader) !Self {
            // Read as unsigned then cast/extend
            // We use a container unsigned type of same size as T
            const U_Type = std.meta.Int(.unsigned, @bitSizeOf(T));
            const raw = try reader.readInt(U_Type, width);

            // Sign extension
            // If the MSB (width-1) is set, we must set all bits from width to @bitSizeOf(T)
            const msb = (raw >> (width - 1)) & 1;
            var val: T = 0;

            if (msb == 1) {
                // Negative
                // Create mask for lower 'width' bits
                // If width is same as T bitsize, we can't shift by width.
                // But U(8, i8): width=8. bitSizeOf(i8)=8.
                // 1 << 8 is UB for u8.
                // If width == @bitSizeOf(T), we don't need sign extension (it's already correct size).
                var mask: U_Type = 0;
                if (width == @bitSizeOf(T)) {
                    mask = std.math.maxInt(U_Type);
                } else {
                    mask = (@as(U_Type, 1) << @intCast(width)) - 1;
                }

                const sign_ext = ~mask;
                // Combine
                const extended = raw | sign_ext;
                val = @bitCast(extended);
            } else {
                val = @intCast(raw);
            }

            return Self{ .value = val };
        }

        pub fn encode(self: Self, writer: *BitWriter) !void {
            // Write strictly the lower 'width' bits
            try writer.writeInt(@as(std.meta.Int(.unsigned, @bitSizeOf(T)), @bitCast(self.value)), width);
        }
    };
}

/// Coordinate (Latitude/Longitude)
/// Reads signed integer of `width`, converts to degrees (1/10000 minute precision).
pub fn LatLon(comptime width: usize) type {
    return struct {
        value: f64,

        const Self = @This();
        pub const bit_width = width;

        pub fn decode(reader: *BitReader) !Self {
            // Use the I() logic to get the integer
            const IntType = I(width, i32); // Assuming i32 is enough for u28/u27
            const int_val = (try IntType.decode(reader)).value;

            // Convert to degrees
            const deg = @as(f64, @floatFromInt(int_val)) / 10000.0 / 60.0;
            return Self{ .value = deg };
        }

        pub fn encode(self: Self, writer: *BitWriter) !void {
            // Convert degrees back to 1/10000 minutes
            const mins = self.value * 60.0 * 10000.0;
            const int_val = @as(i32, @intFromFloat(mins));

            const IntType = I(width, i32);
            try (IntType{ .value = int_val }).encode(writer);
        }
    };
}

/// Simple Bounded Array implementation since std.BoundedArray is missing in this env
pub fn BoundedArray(comptime T: type, comptime capacity: usize) type {
    return struct {
        buffer: [capacity]T,
        len: usize = 0,

        const Self = @This();

        pub fn init(len: usize) Self {
             // Init buffer to undefined or 0
             return Self{
                 .buffer = [_]T{0} ** capacity, // Init with 0
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
/// Fixed bit width, 6 bits per char.
pub fn Str(comptime bit_len: usize) type {
    const char_count = bit_len / 6;
    return struct {
        value: BoundedArray(u8, char_count),

        const Self = @This();
        pub const bit_width = bit_len;

        pub fn decode(reader: *BitReader) !Self {
            // Read char by char.
            var ba = BoundedArray(u8, char_count).init(0);

            for (0..char_count) |_| {
                const char_code = try reader.readInt(u8, 6);
                const ascii = if (char_code < 32) (char_code + 64) else (char_code);
                try ba.append(ascii);
            }

            // Trim @ and space
            const trimmed = std.mem.trimEnd(u8, ba.slice(), "@ ");
            ba.len = @intCast(trimmed.len);

            return Self{ .value = ba };
        }

        pub fn encode(self: Self, writer: *BitWriter) !void {
            // Encode chars
            for (self.value.constSlice()) |c| {
                var code: u8 = c;
                if (c >= 64) {
                    code = c - 64;
                }
                // Check valid range?
                try writer.writeInt(code & 0x3F, 6);
            }
            // Padding
            const padding = char_count - self.value.len;
            for (0..padding) |_| {
                // @ -> 0
                try writer.writeInt(0, 6);
            }
        }
    };
}
