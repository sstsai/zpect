const std = @import("std");
const codec = @import("../../codec/bit_packed.zig");
const types = @import("../../meta/schema.zig");

// Import generic types
const U = types.U;
const I = types.I;
const LatLon = types.LatLon;
const Str = types.Str;

pub const MsgType1Schema = struct {
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

pub const MsgType1 = struct {
    message_id: u8,
    repeat_indicator: u8,
    mmsi: u32,
    nav_status: u8,
    rot: i8,
    sog: u16,
    position_accuracy: u8,
    longitude: f64,
    latitude: f64,
    cog: u16,
    true_heading: u16,
    time_stamp: u8,
    maneuver_indicator: u8,
    spare: u8,
    raim: u8,
    radio_status: u32,
};

test "MsgType1 encode/decode" {
    // 168 bits
    var writer = try @import("../../codec/bit_stream.zig").BitWriter.init(std.testing.allocator);
    defer writer.deinit();

    // Fill with dummy data
    const msg = MsgType1{
        .message_id = 1,
        .repeat_indicator = 0,
        .mmsi = 123456789,
        .nav_status = 0,
        .rot = 0,
        .sog = 100,
        .position_accuracy = 1,
        .longitude = 180.0,
        .latitude = 90.0,
        .cog = 0,
        .true_heading = 0,
        .time_stamp = 0,
        .maneuver_indicator = 0,
        .spare = 0,
        .raim = 0,
        .radio_status = 0,
    };

    try codec.encodeStruct(MsgType1Schema, msg, &writer);

    const bits = try writer.bits.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(bits);

    try std.testing.expectEqual(bits.len, 168);

    var reader = @import("../../codec/bit_stream.zig").BitReader{ .bits = bits };
    const decoded = try codec.decodeStruct(MsgType1Schema, MsgType1, &reader);

    try std.testing.expectEqual(msg.mmsi, decoded.mmsi);
    try std.testing.expectApproxEqAbs(msg.latitude, decoded.latitude, 0.00001);
}
