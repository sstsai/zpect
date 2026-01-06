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
}; // 424 bits

pub const AisMessage = union(enum) {
    type1: MsgType1,
    type5: MsgType5,
};

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
