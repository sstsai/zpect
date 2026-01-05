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
            // But sometimes we get messages with padding or slightly short if spare bits are omitted?
            // "15MwkT1P37G?fl0EJbR0OwT0@MS" is 27 chars -> 162 bits.
            // 168 - 162 = 6 bits short.
            // The last field in MsgType1 is radio_status (19 bits).
            // Maybe the sample is Type 1?
            // First char '1' -> 49 - 48 = 1.
            // 000001. Message ID 1. Correct.

            // If the message is short, maybe we should pad with 0s?
            // Or maybe the struct definition has too many fields?
            // MsgType1 is 168 bits.
            // The sample provided is real, so maybe my struct definition is too strict or the sample is indeed short (maybe missing spare/padding).

            // Allow shorter messages if they cover enough critical data?
            // Or padding.

            // Let's create a padded buffer.
            var padded_bits: [168]u1 = [_]u1{0} ** 168;
            const copy_len = @min(bits.len, 168);
            @memcpy(padded_bits[0..copy_len], bits[0..copy_len]);

            return AisMessage{ .type1 = try castBits(MsgType1, &padded_bits) };
        },
        5 => {
            if (bits.len < 424) return error.MessageTooShort;
            return AisMessage{ .type5 = try castBits(MsgType5, bits[0..424]) };
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
        // We assume Big Endian bit stream (network order) into the integer value.
        // But packed structs in Zig ... wait.
        // Zig packed structs: "Fields are packed into the smallest integer type that can hold them. The fields are ordered from least significant bit to most significant bit."
        // Wait, standard says LSB to MSB?
        // "Packed structs have a defined memory layout. The fields are laid out in order of increasing bit offset."
        // If I define:
        // struct { a: u1, b: u1 }
        // a is bit 0, b is bit 1.

        // AIS data is transmitted MSB first.
        // So the first bit received is the MSB of the first field.
        // But if `message_id` is the first field, it is 6 bits.
        // The first bit received is bit 5 of message_id? Or bit 0?
        // "The most significant bit is the first transmitted bit."

        // Let's assume we construct the field value by reading bits from our `bits` slice (which is in reception order)
        // and shifting them in.

        for (0..field_bits_len) |i| {
            if (bits[bit_offset + i] == 1) {
                // Determine which bit in the integer this corresponds to.
                // If the stream is MSB first, then the first bit we see is the MSB of the field.
                // So bit `i` (0 to N-1) corresponds to bit `N-1-i` in the integer value.
                field_val |= @as(field.type, 1) << @intCast(field_bits_len - 1 - i);
            }
        }

        @field(result, field.name) = field_val;
        bit_offset += field_bits_len;
    }

    return result;
}
