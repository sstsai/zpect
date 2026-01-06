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

    pub fn readSigned(self: *BitReader, comptime T: type, bit_width: usize) !T {
        // Read as unsigned container of same size
        const U_Type = std.meta.Int(.unsigned, @bitSizeOf(T));
        const raw = try self.readInt(U_Type, bit_width);

        // Sign extension
        // If the MSB (width-1) is set, we must set all bits from width to @bitSizeOf(T)
        const msb = (raw >> @intCast(bit_width - 1)) & 1;
        var val: T = 0;

        if (msb == 1) {
            // Negative
            var mask: U_Type = 0;
            if (bit_width == @bitSizeOf(T)) {
                mask = std.math.maxInt(U_Type);
            } else {
                mask = (@as(U_Type, 1) << @intCast(bit_width)) - 1;
            }
            const sign_ext = ~mask;
            const extended = raw | sign_ext;
            val = @bitCast(extended);
        } else {
            val = @intCast(raw);
        }
        return val;
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
            // Handle comptime_int vs runtime int
            const ValueType = @TypeOf(value);
            if (@typeInfo(ValueType) == .comptime_int) {
                const v_u128: u128 = @intCast(value);
                const bit_val = (v_u128 >> @intCast(shift_amt)) & 1;
                try self.bits.append(self.allocator, @intCast(bit_val));
            } else {
                 const bit_val = (value >> @intCast(shift_amt)) & 1;
                 try self.bits.append(self.allocator, @intCast(bit_val));
            }
        }
    }

    pub fn writeSigned(self: *BitWriter, value: anytype, bit_width: usize) !void {
        // Write lower 'bit_width' bits of the signed value.
        // Bit cast to unsigned of same size.
        const T = @TypeOf(value);
        const U_Type = std.meta.Int(.unsigned, @bitSizeOf(T));
        const raw = @as(U_Type, @bitCast(value));
        try self.writeInt(raw, bit_width);
    }
};

// --- Types ---

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

// --- Codecs ---

pub const IntCodec = struct {
    pub fn encode(comptime T: type, value: T, w: *BitWriter) !void {
        const bits = @field(T, "bits");
        if (@field(T, "signed")) {
            try w.writeSigned(value.value, bits);
        } else {
            try w.writeInt(value.value, bits);
        }
    }

    pub fn decode(comptime T: type, r: *BitReader) !T {
        const bits = @field(T, "bits");
        const Underlying = @field(T, "Underlying");
        if (@field(T, "signed")) {
            const val = try r.readSigned(Underlying, bits);
            return T{ .value = val };
        } else {
            const val = try r.readInt(Underlying, bits);
            return T{ .value = val };
        }
    }
};

pub const ScaledFloatCodec = struct {
    pub fn encode(comptime T: type, value: T, w: *BitWriter) !void {
        const bits = @field(T, "bits");
        const scale = @field(T, "scale");
        // We need an int type large enough to hold bits
        // Let's use i32 as standard for lat/lon (27/28 bits)
        const Int = i32;

        const scaled = value.value * scale;
        const raw = @as(Int, @intFromFloat(@round(scaled)));
        try w.writeSigned(raw, bits);
    }

    pub fn decode(comptime T: type, r: *BitReader) !T {
        const bits = @field(T, "bits");
        const scale = @field(T, "scale");
        const Int = i32; // Assuming fit

        const raw = try r.readSigned(Int, bits);
        const deg = @as(f64, @floatFromInt(raw)) / scale;
        return T{ .value = deg };
    }
};

pub const StringCodec = struct {
    pub fn encode(comptime T: type, value: T, w: *BitWriter) !void {
        const bit_len = @field(T, "bits");
        const char_count = bit_len / 6;

        // Encode chars
        for (value.value.constSlice()) |c| {
            var code: u8 = c;
            if (c >= 64) {
                code = c - 64;
            }
            try w.writeInt(code & 0x3F, 6);
        }
        // Padding
        const padding = char_count - value.value.len;
        for (0..padding) |_| {
            try w.writeInt(0, 6);
        }
    }

    pub fn decode(comptime T: type, r: *BitReader) !T {
        const bit_len = @field(T, "bits");
        const char_count = bit_len / 6;
        const Underlying = @field(T, "Underlying");

        var ba = Underlying.init(0);

        for (0..char_count) |_| {
            const char_code = try r.readInt(u8, 6);
            const ascii = if (char_code < 32) (char_code + 64) else (char_code);
            try ba.append(ascii);
        }

        // Trim @ and space
        const trimmed = std.mem.trimEnd(u8, ba.slice(), "@ ");
        ba.len = @intCast(trimmed.len);

        return T{ .value = ba };
    }
};
