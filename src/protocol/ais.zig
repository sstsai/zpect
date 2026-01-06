const std = @import("std");
const bit_stream = @import("codec/bit_stream.zig");
const codec = @import("codec/codecs.zig");

// Import Message Types
const type_1 = @import("ais/type_1.zig");
const type_5 = @import("ais/type_5.zig");

pub const MsgType1 = type_1.MsgType1;
pub const MsgType5 = type_5.MsgType5;

pub const AisMessage = union(enum) {
    type1: MsgType1,
    type5: MsgType5,
};

pub fn decode(bits: []const u1) !AisMessage {
    if (bits.len < 6) return error.MessageTooShort;

    var reader = bit_stream.BitReader{ .bits = bits };

    // Peek Message ID (first 6 bits)
    const msg_id = try reader.readInt(u8, 6);
    reader.cursor = 0; // Reset

    switch (msg_id) {
        1 => {
            // Handle padding if short
            var padded_bits: [168]u1 = [_]u1{0} ** 168;
            const copy_len = @min(bits.len, 168);
            @memcpy(padded_bits[0..copy_len], bits[0..copy_len]);

            var padded_reader = bit_stream.BitReader{ .bits = &padded_bits };
            return AisMessage{ .type1 = try codec.decodeStruct(MsgType1, &padded_reader) };
        },
        5 => {
            var padded_bits: [424]u1 = [_]u1{0} ** 424;
            const copy_len = @min(bits.len, 424);
            @memcpy(padded_bits[0..copy_len], bits[0..copy_len]);

            var padded_reader = bit_stream.BitReader{ .bits = &padded_bits };
            return AisMessage{ .type5 = try codec.decodeStruct(MsgType5, &padded_reader) };
        },
        else => return error.UnsupportedMessage,
    }
}

pub fn encode(message: AisMessage, allocator: std.mem.Allocator) ![]const u1 {
    var writer = try bit_stream.BitWriter.init(allocator);
    errdefer writer.deinit();

    switch (message) {
        .type1 => |msg| try codec.encodeStruct(MsgType1, msg, &writer),
        .type5 => |msg| try codec.encodeStruct(MsgType5, msg, &writer),
    }

    return try writer.bits.toOwnedSlice(allocator);
}
