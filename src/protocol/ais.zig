const std = @import("std");
const types = @import("ais_types.zig");

// Import generic types
const U = types.U;
const I = types.I;
const LatLon = types.LatLon;
const Str = types.Str;

pub const MsgType1 = struct {
    message_id: U(6, u8),
    repeat_indicator: U(2, u8),
    mmsi: U(30, u32),
    nav_status: U(4, u8),
    rot: I(8, i8),
    sog: U(10, u16),
    position_accuracy: U(1, u8),
    longitude: LatLon(28),
    latitude: LatLon(27),
    cog: U(12, u16),
    true_heading: U(9, u16),
    time_stamp: U(6, u8),
    maneuver_indicator: U(2, u8),
    spare: U(3, u8),
    raim: U(1, u8),
    radio_status: U(19, u32),
};

pub const MsgType5 = struct {
    message_id: U(6, u8),
    repeat_indicator: U(2, u8),
    mmsi: U(30, u32),
    ais_version: U(2, u8),
    imo_number: U(30, u32),
    call_sign: Str(42),
    vessel_name: Str(120),
    ship_type: U(8, u8),
    dimension_to_bow: U(9, u16),
    dimension_to_stern: U(9, u16),
    dimension_to_port: U(6, u8),
    dimension_to_starboard: U(6, u8),
    position_fix_type: U(4, u8),
    eta: U(20, u32),
    draught: U(8, u8),
    destination: Str(120),
    dte: U(1, u8),
    spare: U(1, u8),
};

pub const AisMessage = union(enum) {
    type1: MsgType1,
    type5: MsgType5,
};

pub fn decode(bits: []const u1) !AisMessage {
    if (bits.len < 6) return error.MessageTooShort;

    var reader = types.BitReader{ .bits = bits };

    // Peek Message ID (first 6 bits)
    const msg_id = try reader.readInt(u8, 6);
    reader.cursor = 0; // Reset

    switch (msg_id) {
        1 => {
            // Handle padding if short
            var padded_bits: [168]u1 = [_]u1{0} ** 168;
            const copy_len = @min(bits.len, 168);
            @memcpy(padded_bits[0..copy_len], bits[0..copy_len]);

            var padded_reader = types.BitReader{ .bits = &padded_bits };
            return AisMessage{ .type1 = try decodeStruct(MsgType1, &padded_reader) };
        },
        5 => {
            var padded_bits: [424]u1 = [_]u1{0} ** 424;
            const copy_len = @min(bits.len, 424);
            @memcpy(padded_bits[0..copy_len], bits[0..copy_len]);

            var padded_reader = types.BitReader{ .bits = &padded_bits };
            return AisMessage{ .type5 = try decodeStruct(MsgType5, &padded_reader) };
        },
        else => return error.UnsupportedMessage,
    }
}

pub fn encode(message: AisMessage, allocator: std.mem.Allocator) ![]const u1 {
    var writer = try types.BitWriter.init(allocator);
    errdefer writer.deinit();

    switch (message) {
        .type1 => |msg| try encodeStruct(msg, &writer),
        .type5 => |msg| try encodeStruct(msg, &writer),
    }

    return try writer.bits.toOwnedSlice(allocator);
}

fn decodeStruct(comptime T: type, reader: *types.BitReader) !T {
    var result: T = undefined;

    // Iterate over fields and decode each
    inline for (std.meta.fields(T)) |field| {
        const F = field.type;

        if (@hasDecl(F, "scale")) {
            @field(result, field.name) = try types.ScaledFloatCodec.decode(F, reader);
        } else if (@hasDecl(F, "is_string")) {
            @field(result, field.name) = try types.StringCodec.decode(F, reader);
        } else if (@hasDecl(F, "signed")) {
            @field(result, field.name) = try types.IntCodec.decode(F, reader);
        } else {
            @compileError("No codec for field " ++ field.name);
        }
    }

    return result;
}

fn encodeStruct(value: anytype, writer: *types.BitWriter) !void {
    const T = @TypeOf(value);
    inline for (std.meta.fields(T)) |field| {
        const field_val = @field(value, field.name);
        const F = field.type;

        if (@hasDecl(F, "scale")) {
            try types.ScaledFloatCodec.encode(F, field_val, writer);
        } else if (@hasDecl(F, "is_string")) {
            try types.StringCodec.encode(F, field_val, writer);
        } else if (@hasDecl(F, "signed")) {
            try types.IntCodec.encode(F, field_val, writer);
        } else {
            @compileError("No codec for field " ++ field.name);
        }
    }
}
