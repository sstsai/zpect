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

test "BitStream basic usage" {
    // Write 1010 (10 decimal) as 4 bits
    var writer = try BitWriter.init(std.testing.allocator);
    defer writer.deinit();

    try writer.writeInt(10, 4);
    try writer.writeSigned(@as(i8, -1), 4); // 1111

    const bits = try writer.bits.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(bits);

    var reader = BitReader{ .bits = bits };
    const u = try reader.readInt(u8, 4);
    try std.testing.expectEqual(@as(u8, 10), u);

    const i = try reader.readSigned(i8, 4);
    try std.testing.expectEqual(@as(i8, -1), i);
}
