const std = @import("std");
const codec = @import("../codec/codecs.zig");
const types = @import("../codec/types.zig");

// Import generic types
const U = types.U;
const I = types.I;
const LatLon = types.LatLon;
const Str = types.Str;

pub const MsgType5Schema = struct {
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

pub const MsgType5 = struct {
    message_id: u8,
    repeat_indicator: u8,
    mmsi: u32,
    ais_version: u8,
    imo_number: u32,
    call_sign: types.BoundedArray(u8, 7), // 42/6
    vessel_name: types.BoundedArray(u8, 20), // 120/6
    ship_type: u8,
    dimension_to_bow: u16,
    dimension_to_stern: u16,
    dimension_to_port: u8,
    dimension_to_starboard: u8,
    position_fix_type: u8,
    eta: u32,
    draught: u8,
    destination: types.BoundedArray(u8, 20),
    dte: u8,
    spare: u8,
};

test "MsgType5 encode/decode" {
    // 424 bits
    var writer = try @import("../codec/bit_stream.zig").BitWriter.init(std.testing.allocator);
    defer writer.deinit();

    // Fill with dummy data
    var msg = MsgType5{
        .message_id = 5,
        .repeat_indicator = 0,
        .mmsi = 987654321,
        .ais_version = 0,
        .imo_number = 0,
        .call_sign = undefined,
        .vessel_name = undefined,
        .ship_type = 0,
        .dimension_to_bow = 0,
        .dimension_to_stern = 0,
        .dimension_to_port = 0,
        .dimension_to_starboard = 0,
        .position_fix_type = 0,
        .eta = 0,
        .draught = 0,
        .destination = undefined,
        .dte = 0,
        .spare = 0,
    };

    var cs = types.BoundedArray(u8, 7).init(0);
    try cs.append('A'); try cs.append('B'); try cs.append('C');
    msg.call_sign = cs;

    var vn = types.BoundedArray(u8, 20).init(0);
    try vn.append('Z'); try vn.append('I'); try vn.append('G');
    msg.vessel_name = vn;

    const dest = types.BoundedArray(u8, 20).init(0);
    msg.destination = dest;

    try codec.encodeStruct(MsgType5Schema, msg, &writer);

    const bits = try writer.bits.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(bits);

    try std.testing.expectEqual(bits.len, 424);

    var reader = @import("../codec/bit_stream.zig").BitReader{ .bits = bits };
    const decoded = try codec.decodeStruct(MsgType5Schema, MsgType5, &reader);

    try std.testing.expectEqual(msg.mmsi, decoded.mmsi);
    try std.testing.expectEqualStrings("ABC", decoded.call_sign.constSlice());
    try std.testing.expectEqualStrings("ZIG", decoded.vessel_name.constSlice());
}
