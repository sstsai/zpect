const std = @import("std");

pub fn unarmor(input: []const u8, output_bits: []u1) !usize {
    var bit_index: usize = 0;

    for (input) |char| {
        // Validation of character range
        if (char < 48 or char > 119) {
            return error.InvalidCharacter;
        }
        if (char >= 88 and char <= 95) {
            return error.InvalidCharacter;
        }

        var val: u8 = char - 48;
        if (val > 40) {
            val -= 8;
        }

        // Each char is 6 bits.
        // AIS data is transmitted MSB-first.
        // "The most significant bit is the first transmitted bit."
        // We pack into u1 array preserving this order (Index 0 = MSB).

        if (bit_index + 6 > output_bits.len) {
            return error.BufferTooSmall;
        }

        // Extract bits from MSB (bit 5) to LSB (bit 0)
        output_bits[bit_index + 0] = @as(u1, @truncate(val >> 5));
        output_bits[bit_index + 1] = @as(u1, @truncate(val >> 4));
        output_bits[bit_index + 2] = @as(u1, @truncate(val >> 3));
        output_bits[bit_index + 3] = @as(u1, @truncate(val >> 2));
        output_bits[bit_index + 4] = @as(u1, @truncate(val >> 1));
        output_bits[bit_index + 5] = @as(u1, @truncate(val));

        bit_index += 6;
    }

    return bit_index;
}
