const std = @import("std");
const bit_stream = @import("bit_stream.zig");
const types = @import("types.zig");

const BitReader = bit_stream.BitReader;
const BitWriter = bit_stream.BitWriter;

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
        const Int = i32;

        const scaled = value.value * scale;
        const raw = @as(Int, @intFromFloat(@round(scaled)));
        try w.writeSigned(raw, bits);
    }

    pub fn decode(comptime T: type, r: *BitReader) !T {
        const bits = @field(T, "bits");
        const scale = @field(T, "scale");
        const Int = i32;

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

pub fn decodeStruct(comptime T: type, reader: *BitReader) !T {
    var result: T = undefined;

    inline for (std.meta.fields(T)) |field| {
        const F = field.type;

        if (@hasDecl(F, "scale")) {
            @field(result, field.name) = try ScaledFloatCodec.decode(F, reader);
        } else if (@hasDecl(F, "is_string")) {
            @field(result, field.name) = try StringCodec.decode(F, reader);
        } else if (@hasDecl(F, "signed")) {
            @field(result, field.name) = try IntCodec.decode(F, reader);
        } else {
            @compileError("No codec for field " ++ field.name);
        }
    }

    return result;
}

pub fn encodeStruct(value: anytype, writer: *BitWriter) !void {
    const T = @TypeOf(value);
    inline for (std.meta.fields(T)) |field| {
        const field_val = @field(value, field.name);
        const F = field.type;

        if (@hasDecl(F, "scale")) {
            try ScaledFloatCodec.encode(F, field_val, writer);
        } else if (@hasDecl(F, "is_string")) {
            try StringCodec.encode(F, field_val, writer);
        } else if (@hasDecl(F, "signed")) {
            try IntCodec.encode(F, field_val, writer);
        } else {
            @compileError("No codec for field " ++ field.name);
        }
    }
}

test "Codecs roundtrip" {
    const TestStruct = struct {
        id: types.U(6, u8),
        temp: types.I(10, i16),
        pos: types.LatLon(27),
        name: types.Str(12), // 2 chars
    };

    var writer = try BitWriter.init(std.testing.allocator);
    defer writer.deinit();

    var ts = TestStruct{
        .id = .{ .value = 63 },
        .temp = .{ .value = -50 },
        .pos = .{ .value = 12.3456 }, // 12.3456 * 600000 = 7407360
        .name = .{ .value = undefined },
    };
    // Initialize bounded array manually
    var name_ba = types.Str(12).Underlying.init(0);
    try name_ba.append('A');
    try name_ba.append('B');
    ts.name.value = name_ba;

    try encodeStruct(ts, &writer);

    const bits = try writer.bits.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(bits);

    var reader = BitReader{ .bits = bits };
    const decoded = try decodeStruct(TestStruct, &reader);

    try std.testing.expectEqual(@as(u8, 63), decoded.id.value);
    try std.testing.expectEqual(@as(i16, -50), decoded.temp.value);
    try std.testing.expectApproxEqAbs(ts.pos.value, decoded.pos.value, 0.00001);
    try std.testing.expectEqualStrings("AB", decoded.name.value.constSlice());
}
