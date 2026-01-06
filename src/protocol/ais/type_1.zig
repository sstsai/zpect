const std = @import("std");
const codec = @import("../codec/codecs.zig");
const types = @import("../codec/types.zig");

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

test "MsgType1 encode/decode" {
    // 168 bits
    var writer = try @import("../codec/bit_stream.zig").BitWriter.init(std.testing.allocator);
    defer writer.deinit();

    // Fill with dummy data
    const msg = MsgType1{
        .message_id = .{ .value = 1 },
        .repeat_indicator = .{ .value = 0 },
        .mmsi = .{ .value = 123456789 },
        .nav_status = .{ .value = 0 },
        .rot = .{ .value = 0 },
        .sog = .{ .value = 100 },
        .position_accuracy = .{ .value = 1 },
        .longitude = .{ .value = 180.0 },
        .latitude = .{ .value = 90.0 },
        .cog = .{ .value = 0 },
        .true_heading = .{ .value = 0 },
        .time_stamp = .{ .value = 0 },
        .maneuver_indicator = .{ .value = 0 },
        .spare = .{ .value = 0 },
        .raim = .{ .value = 0 },
        .radio_status = .{ .value = 0 },
    };

    try codec.encodeStruct(msg, &writer);

    const bits = try writer.bits.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(bits);

    try std.testing.expectEqual(bits.len, 168);

    var reader = @import("../codec/bit_stream.zig").BitReader{ .bits = bits };
    const decoded = try codec.decodeStruct(MsgType1, &reader);

    try std.testing.expectEqual(msg.mmsi.value, decoded.mmsi.value);
    try std.testing.expectApproxEqAbs(msg.latitude.value, decoded.latitude.value, 0.00001);
}
