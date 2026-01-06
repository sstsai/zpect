const std = @import("std");
const bit_stream = @import("bit_stream.zig");
const types = @import("types.zig");

const BitReader = bit_stream.BitReader;
const BitWriter = bit_stream.BitWriter;

pub const IntCodec = struct {
    pub fn encode(comptime MetaT: type, value: anytype, w: *BitWriter) !void {
        const bits = @field(MetaT, "bits");
        if (@field(MetaT, "signed")) {
            try w.writeSigned(value, bits);
        } else {
            try w.writeInt(value, bits);
        }
    }

    pub fn decode(comptime MetaT: type, r: *BitReader) !@field(MetaT, "Underlying") {
        const bits = @field(MetaT, "bits");
        const Underlying = @field(MetaT, "Underlying");
        if (@field(MetaT, "signed")) {
            return try r.readSigned(Underlying, bits);
        } else {
            return try r.readInt(Underlying, bits);
        }
    }
};

pub const ScaledFloatCodec = struct {
    pub fn encode(comptime MetaT: type, value: anytype, w: *BitWriter) !void {
        const bits = @field(MetaT, "bits");
        const scale = @field(MetaT, "scale");
        const Int = i32;

        const scaled = value * scale;
        const raw = @as(Int, @intFromFloat(@round(scaled)));
        try w.writeSigned(raw, bits);
    }

    pub fn decode(comptime MetaT: type, r: *BitReader) !@field(MetaT, "Underlying") {
        const bits = @field(MetaT, "bits");
        const scale = @field(MetaT, "scale");
        const Int = i32;

        const raw = try r.readSigned(Int, bits);
        const deg = @as(f64, @floatFromInt(raw)) / scale;
        return deg;
    }
};

pub const StringCodec = struct {
    pub fn encode(comptime MetaT: type, value: anytype, w: *BitWriter) !void {
        const bit_len = @field(MetaT, "bits");
        const char_count = bit_len / 6;

        // Encode chars
        for (value.constSlice()) |c| {
            var code: u8 = c;
            if (c >= 64) {
                code = c - 64;
            }
            try w.writeInt(code & 0x3F, 6);
        }
        // Padding
        const padding = char_count - value.len;
        for (0..padding) |_| {
            try w.writeInt(0, 6);
        }
    }

    pub fn decode(comptime MetaT: type, r: *BitReader) !@field(MetaT, "Underlying") {
        const bit_len = @field(MetaT, "bits");
        const char_count = bit_len / 6;
        const Underlying = @field(MetaT, "Underlying");

        var ba = Underlying.init(0);

        for (0..char_count) |_| {
            const char_code = try r.readInt(u8, 6);
            const ascii = if (char_code < 32) (char_code + 64) else (char_code);
            try ba.append(ascii);
        }

        // Trim @ and space
        const trimmed = std.mem.trimEnd(u8, ba.slice(), "@ ");
        ba.len = @intCast(trimmed.len);

        return ba;
    }
};

pub fn decodeStruct(comptime Schema: type, comptime ValueType: type, reader: *BitReader) !ValueType {
    var result: ValueType = undefined;

    inline for (std.meta.fields(Schema)) |field| {
        const F = field.type; // Metadata type

        if (@hasDecl(F, "scale")) {
            @field(result, field.name) = try ScaledFloatCodec.decode(F, reader);
        } else if (@hasDecl(F, "is_string")) {
            @field(result, field.name) = try StringCodec.decode(F, reader);
        } else if (@hasDecl(F, "signed")) {
            @field(result, field.name) = try IntCodec.decode(F, reader);
        } else {
            // Default fallback
            @field(result, field.name) = try IntCodec.decode(F, reader);
        }
    }

    return result;
}

pub fn encodeStruct(comptime Schema: type, value: anytype, writer: *BitWriter) !void {
    inline for (std.meta.fields(Schema)) |field| {
        const field_val = @field(value, field.name);
        const F = field.type; // Metadata type

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
    const TestSchema = struct {
        id: types.U(6, u8),
        temp: types.I(10, i16),
        pos: types.LatLon(27),
        name: types.Str(12), // 2 chars
    };

    // Manual Value struct
    const TestStruct = struct {
        id: u8,
        temp: i16,
        pos: f64,
        name: types.BoundedArray(u8, 2),
    };

    var writer = try BitWriter.init(std.testing.allocator);
    defer writer.deinit();

    var ts = TestStruct{
        .id = 63,
        .temp = -50,
        .pos = 12.3456,
        .name = undefined,
    };
    // Initialize bounded array manually
    var name_ba = types.BoundedArray(u8, 2).init(0);
    try name_ba.append('A');
    try name_ba.append('B');
    ts.name = name_ba;

    try encodeStruct(TestSchema, ts, &writer);

    const bits = try writer.bits.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(bits);

    var reader = BitReader{ .bits = bits };
    const decoded = try decodeStruct(TestSchema, TestStruct, &reader);

    try std.testing.expectEqual(@as(u8, 63), decoded.id);
    try std.testing.expectEqual(@as(i16, -50), decoded.temp);
    try std.testing.expectApproxEqAbs(ts.pos, decoded.pos, 0.00001);
    try std.testing.expectEqualStrings("AB", decoded.name.constSlice());
}
