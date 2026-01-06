const std = @import("std");

pub const MsgType1 = packed struct {
    message_id: u6,
    repeat_indicator: u2,
    mmsi: u30,
    nav_status: u4,
    rot: u8,
    sog: u10,
    position_accuracy: u1,
    longitude: u28,
    latitude: u27,
    cog: u12,
    true_heading: u9,
    time_stamp: u6,
    maneuver_indicator: u2,
    spare: u3,
    raim: u1,
    radio_status: u19,

    /// Returns longitude in degrees.
    /// Internal representation: 1/10000 minute, signed 28-bit.
    pub fn getLongitude(self: MsgType1) f64 {
        const val = @as(i28, @bitCast(self.longitude));
        return @as(f64, @floatFromInt(val)) / 10000.0 / 60.0;
    }

    /// Returns latitude in degrees.
    /// Internal representation: 1/10000 minute, signed 27-bit.
    pub fn getLatitude(self: MsgType1) f64 {
        const val = @as(i27, @bitCast(self.latitude));
        return @as(f64, @floatFromInt(val)) / 10000.0 / 60.0;
    }
}; // 168 bits

pub const MsgType5 = packed struct {
    message_id: u6,
    repeat_indicator: u2,
    mmsi: u30,
    ais_version: u2,
    imo_number: u30,
    call_sign: u42,
    vessel_name: u120,
    ship_type: u8,
    dimension_to_bow: u9,
    dimension_to_stern: u9,
    dimension_to_port: u6,
    dimension_to_starboard: u6,
    position_fix_type: u4,
    eta: u20,
    draught: u8,
    destination: u120,
    dte: u1,
    spare: u1,

    pub fn getCallSign(self: MsgType5, buffer: []u8) []const u8 {
        return decodeString(u42, self.call_sign, buffer);
    }

    pub fn getVesselName(self: MsgType5, buffer: []u8) []const u8 {
        return decodeString(u120, self.vessel_name, buffer);
    }
}; // 424 bits

pub const AisMessage = union(enum) {
    type1: MsgType1,
    type5: MsgType5,
};

// Helper to decode 6-bit ASCII string packed in integer.
// 6-bit ASCII mapping (Table 44 in ITU-R M.1371):
// 0-31: @, A-Z, [, \, ], ^, _
// 32-63: space, !, ", #, ..., ?
fn decodeString(comptime T: type, value: T, buffer: []u8) []const u8 {
    const bit_len = @bitSizeOf(T);
    const char_count = bit_len / 6;
    if (buffer.len < char_count) return "";

    // The packed integer `value` has characters packed.
    // Which order?
    // "Strings are sent MSB first."
    // Our `castBits` constructed the integer MSB first.
    // So the most significant 6 bits of `value` correspond to the FIRST character.
    // e.g. "ABC" -> A(MSB)..C(LSB).

    var idx: usize = 0;
    for (0..char_count) |i| {
        // Shift to get the i-th character from MSB.
        // i=0 -> shift right by (N-1)*6
        const shift = (char_count - 1 - i) * 6;
        const char_code = @as(u8, @truncate(value >> @intCast(shift))) & 0x3F;

        // Map 6-bit code to ASCII
        const ascii = if (char_code < 32) (char_code + 64) else (char_code);

        // Strip trailing @ (which is padding) usually?
        // Spec says "@" (0) is used for padding.
        // But usually we convert all and trim?
        // Let's convert all.

        buffer[idx] = ascii;
        idx += 1;
    }

    // Trim trailing '@' (padding) and spaces
    const full = buffer[0..idx];
    return std.mem.trimEnd(u8, full, "@ ");
}

pub fn decode(bits: []const u1) !AisMessage {
    if (bits.len < 6) return error.MessageTooShort;

    // First 6 bits are Message ID
    var message_id: u6 = 0;
    for (bits[0..6], 0..) |bit, i| {
        if (bit == 1) {
            message_id |= @as(u6, 1) << @intCast(5 - i);
        }
    }

    switch (message_id) {
        1 => {
            // Standard length is 168 bits.
            var padded_bits: [168]u1 = [_]u1{0} ** 168;
            const copy_len = @min(bits.len, 168);
            @memcpy(padded_bits[0..copy_len], bits[0..copy_len]);

            return AisMessage{ .type1 = try castBits(MsgType1, &padded_bits) };
        },
        5 => {
             // Standard length is 424 bits.
            var padded_bits: [424]u1 = [_]u1{0} ** 424;
            const copy_len = @min(bits.len, 424);
            @memcpy(padded_bits[0..copy_len], bits[0..copy_len]);

            return AisMessage{ .type5 = try castBits(MsgType5, &padded_bits) };
        },
        else => return error.UnsupportedMessage,
    }
}

fn castBits(comptime T: type, bits: []const u1) !T {
    var result: T = undefined;
    var bit_offset: usize = 0;

    // Use comptime reflection to iterate over fields
    inline for (std.meta.fields(T)) |field| {
        const field_bits_len = @bitSizeOf(field.type);
        var field_val: field.type = 0;

        // Extract bits for this field.
        // AIS data is transmitted MSB-first (Network Bit Order).
        // The bit stream `bits` is ordered such that index 0 is the first received bit (MSB of the first field).

        // Zig `packed struct` layout is technically LSB-first in memory, but here we use the struct
        // only as a schema to define field types and order. We manually construct the integer value
        // for each field by shifting bits in from MSB to LSB.

        for (0..field_bits_len) |i| {
            if (bits[bit_offset + i] == 1) {
                // Determine which bit in the integer this corresponds to.
                // Since the stream is MSB first, the first bit we read (i=0) is the MSB of the field.
                // So bit `i` (0 to N-1) corresponds to bit `N-1-i` in the constructed integer value.
                field_val |= @as(field.type, 1) << @intCast(field_bits_len - 1 - i);
            }
        }

        @field(result, field.name) = field_val;
        bit_offset += field_bits_len;
    }

    return result;
}
