//! By convention, root.zig is the root source file when making a package.
const std = @import("std");

pub const protocol = struct {
    pub const ais = @import("protocol/ais.zig");
    // Codecs are internals, but exposed for advanced usage if needed.
    pub const codec = struct {
        pub const bit_stream = @import("codec/bit_stream.zig");
        pub const bit_packed = @import("codec/bit_packed.zig");
        pub const nmea = @import("codec/nmea.zig");
        pub const tag_block = @import("codec/tag_block.zig");
        pub const ais_sixbit = @import("codec/ais_sixbit.zig");
    };

    // Convenience aliases
    pub const tag_block = codec.tag_block;
    pub const nmea = codec.nmea;
    pub const sixbit = codec.ais_sixbit;
};

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}

test "protocol modules" {
    _ = protocol.ais;
    _ = protocol.codec.bit_stream;
    _ = protocol.codec.bit_packed;
    _ = protocol.codec.nmea;
    _ = protocol.codec.tag_block;
    _ = protocol.codec.ais_sixbit;
}
