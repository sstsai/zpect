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
        .message_id = .{ ._ = 1 },
        .repeat_indicator = .{ ._ = 0 },
        .mmsi = .{ ._ = 123456789 },
        .nav_status = .{ ._ = 0 },
        .rot = .{ ._ = 0 },
        .sog = .{ ._ = 100 },
        .position_accuracy = .{ ._ = 1 },
        .longitude = .{ ._ = 180.0 },
        .latitude = .{ ._ = 90.0 },
        .cog = .{ ._ = 0 },
        .true_heading = .{ ._ = 0 },
        .time_stamp = .{ ._ = 0 },
        .maneuver_indicator = .{ ._ = 0 },
        .spare = .{ ._ = 0 },
        .raim = .{ ._ = 0 },
        .radio_status = .{ ._ = 0 },
    };

    try codec.encodeStruct(MsgType1, msg, &writer);

    const bits = try writer.bits.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(bits);

    try std.testing.expectEqual(bits.len, 168);

    var reader = @import("../codec/bit_stream.zig").BitReader{ .bits = bits };
    const decoded = try codec.decodeStruct(MsgType1, &reader);

    try std.testing.expectEqual(msg.mmsi._, decoded.mmsi._);
    try std.testing.expectApproxEqAbs(msg.latitude._, decoded.latitude._, 0.00001);
}
