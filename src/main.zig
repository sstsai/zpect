const std = @import("std");
const zpect = @import("zpect");

const tag_block = zpect.protocol.tag_block;
const nmea = zpect.protocol.nmea;
const sixbit = zpect.protocol.sixbit;
const ais = zpect.protocol.ais;

pub fn main() !void {
    std.debug.print("Zpect Maritime Telemetry System\n", .{});
}

test "pipeline with tag block and AIS" {
    // Input: \s:source*54\!AIVDM,1,1,,B,15MwkT1P37G?fl0EJbR0OwT0@MS,0*0E
    const input = "\\s:source*54\\!AIVDM,1,1,,B,15MwkT1P37G?fl0EJbR0OwT0@MS,0*0E";

    // 1. Tag Block Layer
    const result = try tag_block.parse(input);
    const tb = result.tag_block.?;

    var it = tb.iterator();
    const tag1 = it.next().?;
    try std.testing.expectEqualStrings("s", tag1[0]);
    try std.testing.expectEqualStrings("source", tag1[1]);

    // 2. NMEA Layer
    const frame = try nmea.NmeaFrame.parse(std.testing.allocator, result.rest);
    defer frame.deinit(std.testing.allocator);

    // 3. AIS Layer
    var bits: [1024]u1 = undefined;
    const bit_count = try sixbit.unarmor(frame.payload, &bits);
    const message = try ais.decode(bits[0..bit_count]);

    switch (message) {
        .type1 => |msg| {
             // 366998416
             try std.testing.expectEqual(@as(u32, 366998416), msg.mmsi);
             // Coordinates
             const lat = msg.getLatitude();
             const lon = msg.getLongitude();
             // Just verify they are reasonable floating point numbers (not NaN)
             try std.testing.expect(!std.math.isNan(lat));
             try std.testing.expect(!std.math.isNan(lon));
        },
        else => return error.WrongMessageType,
    }
}

test "AIS Type 5 semantic access" {
    // !AIVDM,2,1,0,A,542M8?@2<5?0l4=E:1000000000000000000000000000000000000000000,0*10
    // !AIVDM,2,2,0,A,00000000000,2*23
    // Combined payload needed for Type 5 usually.
    // Let's use a single part Message 5 if possible? No, Msg 5 is long (424 bits > 360 bits in 1 sentence).
    // It requires multi-part.

    // My parser supports single sentence logic so far.
    // I will mock the payload directly for this test to verify `getVesselName` and `getCallSign`.

    // Construct bits for a known Type 5 message.
    // Or just manually populate the struct to test the accessors?
    // Accessors work on the packed fields.

    var msg5 = ais.MsgType5{
        .message_id = 5,
        .repeat_indicator = 0,
        .mmsi = 123456789,
        .ais_version = 0,
        .imo_number = 0,
        .call_sign = 0, // Set below
        .vessel_name = 0, // Set below
        .ship_type = 0,
        .dimension_to_bow = 0,
        .dimension_to_stern = 0,
        .dimension_to_port = 0,
        .dimension_to_starboard = 0,
        .position_fix_type = 0,
        .eta = 0,
        .draught = 0,
        .destination = 0,
        .dte = 0,
        .spare = 0,
    };

    // Set Call Sign "ABC"
    // A=1, B=2, C=3.
    // packed u42 (7 chars). MSB first.
    // A(1) B(2) C(3) @(0) @(0) @(0) @(0)
    // 000001 000010 000011 000000 ...
    var cs: u42 = 0;
    cs |= @as(u42, 1) << 36; // A
    cs |= @as(u42, 2) << 30; // B
    cs |= @as(u42, 3) << 24; // C
    msg5.call_sign = cs;

    var buf: [20]u8 = undefined;
    const call_sign = msg5.getCallSign(&buf);
    try std.testing.expectEqualStrings("ABC", call_sign);

    // Set Vessel Name "ZIG"
    // Z=26, I=9, G=7?
    // A=1... Z=26.
    // I: A=1, B=2, C=3, D=4, E=5, F=6, G=7, H=8, I=9. Correct.
    // G: 7.
    var vn: u120 = 0;
    vn |= @as(u120, 26) << (114); // Z (20 chars * 6 = 120. First char is bits 114..119?)
    // 120 bits. Char 0: 114..119.
    vn |= @as(u120, 9) << (108); // I
    vn |= @as(u120, 7) << (102); // G
    msg5.vessel_name = vn;

    const name = msg5.getVesselName(&buf);
    try std.testing.expectEqualStrings("ZIG", name);
}
