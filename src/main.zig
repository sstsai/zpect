const std = @import("std");
const zpect = @import("zpect");

const tag_block = zpect.protocol.tag_block;
const nmea = zpect.protocol.nmea;
const sixbit = zpect.protocol.sixbit;
const ais = zpect.protocol.ais;
const codec = zpect.protocol.codec;

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
             const lat = msg.latitude;
             const lon = msg.longitude;
             // Just verify they are reasonable floating point numbers (not NaN)
             try std.testing.expect(!std.math.isNan(lat));
             try std.testing.expect(!std.math.isNan(lon));
        },
        else => return error.WrongMessageType,
    }
}

test "AIS Type 5 semantic access (Mock)" {
    // Using BitWriter to create the mock stream!
    var writer = try codec.bit_stream.BitWriter.init(std.testing.allocator);
    defer writer.deinit();

    // Msg 5 Fields (Subset for test)
    try writer.writeInt(5, 6); // message_id
    try writer.writeInt(0, 2); // repeat
    try writer.writeInt(123456789, 30); // mmsi
    try writer.writeInt(0, 2); // version
    try writer.writeInt(0, 30); // imo

    // CallSign: "ABC" -> 1, 2, 3
    try writer.writeInt(1, 6); // A
    try writer.writeInt(2, 6); // B
    try writer.writeInt(3, 6); // C
    try writer.writeInt(0, 6); // @
    try writer.writeInt(0, 6); // @
    try writer.writeInt(0, 6); // @
    try writer.writeInt(0, 6); // @

    // VesselName: "ZIG" -> 26, 9, 7
    try writer.writeInt(26, 6); // Z
    try writer.writeInt(9, 6); // I
    try writer.writeInt(7, 6); // G
    // Fill rest of 120 bits (17 chars) with 0
    for (0..17) |_| {
         try writer.writeInt(0, 6);
    }

    // Fill remaining to 424 bits
    // 6+2+30+2+30 + 42 + 120 = 232.
    const remaining = 424 - 232;
    for (0..remaining) |_| {
        try writer.bits.append(writer.allocator, 0);
    }

    const bits_slice = try writer.bits.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(bits_slice);

    const message = try ais.decode(bits_slice);

    switch (message) {
        .type5 => |msg| {
            try std.testing.expectEqualStrings("ABC", msg.call_sign.constSlice());
            try std.testing.expectEqualStrings("ZIG", msg.vessel_name.constSlice());
        },
        else => return error.WrongMessageType,
    }
}

test "Round-trip Encoding" {
    // Decode -> Encode -> Decode -> Compare
    const input = "\\s:source*54\\!AIVDM,1,1,,B,15MwkT1P37G?fl0EJbR0OwT0@MS,0*0E";
    const result = try tag_block.parse(input);
    const frame = try nmea.NmeaFrame.parse(std.testing.allocator, result.rest);
    defer frame.deinit(std.testing.allocator);

    var bits: [1024]u1 = undefined;
    const bit_count = try sixbit.unarmor(frame.payload, &bits);
    const original_bits = bits[0..bit_count];

    const msg1 = try ais.decode(original_bits);

    // Encode back
    const encoded_bits = try ais.encode(msg1, std.testing.allocator);
    defer std.testing.allocator.free(encoded_bits);

    const msg2 = try ais.decode(encoded_bits);

    switch (msg1) {
        .type1 => |m1| {
            switch (msg2) {
                .type1 => |m2| {
                    try std.testing.expectEqual(m1.mmsi, m2.mmsi);
                    try std.testing.expectEqual(m1.latitude, m2.latitude);
                },
                else => return error.WrongMessageType,
            }
        },
        else => return error.WrongMessageType,
    }
}
