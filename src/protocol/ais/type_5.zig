const std = @import("std");
const codec = @import("../codec/codecs.zig");
const types = @import("../codec/types.zig");

// Import generic types
const U = types.U;
const I = types.I;
const LatLon = types.LatLon;
const Str = types.Str;

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

test "MsgType5 encode/decode" {
    // 424 bits
    var writer = try @import("../codec/bit_stream.zig").BitWriter.init(std.testing.allocator);
    defer writer.deinit();

    // Fill with dummy data
    var msg = MsgType5{
        .message_id = .{ .value = 5 },
        .repeat_indicator = .{ .value = 0 },
        .mmsi = .{ .value = 987654321 },
        .ais_version = .{ .value = 0 },
        .imo_number = .{ .value = 0 },
        .call_sign = .{ .value = undefined },
        .vessel_name = .{ .value = undefined },
        .ship_type = .{ .value = 0 },
        .dimension_to_bow = .{ .value = 0 },
        .dimension_to_stern = .{ .value = 0 },
        .dimension_to_port = .{ .value = 0 },
        .dimension_to_starboard = .{ .value = 0 },
        .position_fix_type = .{ .value = 0 },
        .eta = .{ .value = 0 },
        .draught = .{ .value = 0 },
        .destination = .{ .value = undefined },
        .dte = .{ .value = 0 },
        .spare = .{ .value = 0 },
    };

    var cs = types.Str(42).Underlying.init(0);
    try cs.append('A'); try cs.append('B'); try cs.append('C');
    msg.call_sign.value = cs;

    var vn = types.Str(120).Underlying.init(0);
    try vn.append('Z'); try vn.append('I'); try vn.append('G');
    msg.vessel_name.value = vn;

    const dest = types.Str(120).Underlying.init(0);
    msg.destination.value = dest;

    try codec.encodeStruct(msg, &writer);

    const bits = try writer.bits.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(bits);

    try std.testing.expectEqual(bits.len, 424);

    var reader = @import("../codec/bit_stream.zig").BitReader{ .bits = bits };
    const decoded = try codec.decodeStruct(MsgType5, &reader);

    try std.testing.expectEqual(msg.mmsi.value, decoded.mmsi.value);
    try std.testing.expectEqualStrings("ABC", decoded.call_sign.value.constSlice());
    try std.testing.expectEqualStrings("ZIG", decoded.vessel_name.value.constSlice());
}
