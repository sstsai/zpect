const std = @import("std");
const bit_stream = @import("bit_stream.zig");
const types = @import("types.zig");

const BitReader = bit_stream.BitReader;
const BitWriter = bit_stream.BitWriter;

pub const IntCodec = struct {
    pub fn encode(comptime T: type, value: T, w: *BitWriter) !void {
        const bits = @field(T, "bits");
        if (@field(T, "signed")) {
            try w.writeSigned(value._, bits);
        } else {
            try w.writeInt(value._, bits);
        }
    }

    pub fn decode(comptime T: type, r: *BitReader) !T {
        const bits = @field(T, "bits");
        const Underlying = @field(T, "Underlying");
        if (@field(T, "signed")) {
            const val = try r.readSigned(Underlying, bits);
            return T{ ._ = val };
        } else {
            const val = try r.readInt(Underlying, bits);
            return T{ ._ = val };
        }
    }
};

pub const ScaledFloatCodec = struct {
    pub fn encode(comptime T: type, value: T, w: *BitWriter) !void {
        const bits = @field(T, "bits");
        const scale = @field(T, "scale");
        const Int = i32;

        const scaled = value._ * scale;
        const raw = @as(Int, @intFromFloat(@round(scaled)));
        try w.writeSigned(raw, bits);
    }

    pub fn decode(comptime T: type, r: *BitReader) !T {
        const bits = @field(T, "bits");
        const scale = @field(T, "scale");
        const Int = i32;

        const raw = try r.readSigned(Int, bits);
        const deg = @as(f64, @floatFromInt(raw)) / scale;
        return T{ ._ = deg };
    }
};

pub const StringCodec = struct {
    pub fn encode(comptime T: type, value: T, w: *BitWriter) !void {
        const bit_len = @field(T, "bits");
        const char_count = bit_len / 6;

        // Encode chars
        for (value._.constSlice()) |c| {
            var code: u8 = c;
            if (c >= 64) {
                code = c - 64;
            }
            try w.writeInt(code & 0x3F, 6);
        }
        // Padding
        const padding = char_count - value._.len;
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

        return T{ ._ = ba };
    }
};

pub fn decodeStruct(comptime T: type, reader: *BitReader) !T {
    var result: T = undefined;

    inline for (std.meta.fields(T)) |field| {
        const F = field.type; // Wrapper Type

        if (@hasDecl(F, "scale")) {
            @field(result, field.name) = try ScaledFloatCodec.decode(F, reader);
        } else if (@hasDecl(F, "is_string")) {
            @field(result, field.name) = try StringCodec.decode(F, reader);
        } else if (@hasDecl(F, "signed")) {
            @field(result, field.name) = try IntCodec.decode(F, reader);
        } else {
            const wrapper = try IntCodec.decode(F, reader);
            @field(result, field.name) = wrapper;
        }
    }

    return result;
}

pub fn encodeStruct(comptime T: type, value: T, writer: *BitWriter) !void {
    inline for (std.meta.fields(T)) |field| {
        const field_val = @field(value, field.name);
        const F = field.type; // Wrapper Type

        if (@hasDecl(F, "scale")) {
            try ScaledFloatCodec.encode(F, field_val, writer);
        } else if (@hasDecl(F, "is_string")) {
            try StringCodec.encode(F, field_val, writer);
        } else if (@hasDecl(F, "signed")) {
            try IntCodec.encode(F, field_val, writer);
        } else {
            try IntCodec.encode(F, field_val, writer);
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
        .id = .{ ._ = 63 },
        .temp = .{ ._ = -50 },
        .pos = .{ ._ = 12.3456 },
        .name = undefined,
    };
    // Initialize bounded array manually
    var name_ba = types.Str(12).Underlying.init(0);
    try name_ba.append('A');
    try name_ba.append('B');
    ts.name._ = name_ba;

    try encodeStruct(TestStruct, ts, &writer);

    const bits = try writer.bits.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(bits);

    var reader = BitReader{ .bits = bits };
    const decoded = try decodeStruct(TestStruct, &reader);

    try std.testing.expectEqual(@as(u8, 63), decoded.id._);
    try std.testing.expectEqual(@as(i16, -50), decoded.temp._);
    try std.testing.expectApproxEqAbs(ts.pos._, decoded.pos._, 0.00001);
    try std.testing.expectEqualStrings("AB", decoded.name._.constSlice());
}
