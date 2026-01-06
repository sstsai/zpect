//! By convention, root.zig is the root source file when making a package.
const std = @import("std");

pub const protocol = struct {
    pub const tag_block = @import("protocol/tag_block.zig");
    pub const nmea = @import("protocol/nmea.zig");
    pub const sixbit = @import("protocol/sixbit.zig");
    pub const ais = @import("protocol/ais.zig");

    // Expose internal codec layers for advanced usage or testing?
    pub const codec = struct {
        pub const bit_stream = @import("protocol/codec/bit_stream.zig");
        pub const types = @import("protocol/codec/types.zig");
        pub const codecs = @import("protocol/codec/codecs.zig");
    };

    // Legacy export for ais_types (now under codec) - remove or alias?
    // Let's remove ais_types as it was requested to be broken up.
};

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}

test "protocol modules" {
    _ = protocol.tag_block;
    _ = protocol.nmea;
    _ = protocol.sixbit;
    _ = protocol.ais;
    _ = protocol.codec.bit_stream;
    _ = protocol.codec.types;
    _ = protocol.codec.codecs;
}
