//! By convention, root.zig is the root source file when making a package.
const std = @import("std");

pub const io = struct {
    pub const gateway = @import("io/gateway.zig");
};

pub const protocol = struct {
    pub const nmea = @import("protocol/nmea.zig");
    pub const sixbit = @import("protocol/sixbit.zig");
    pub const ais = @import("protocol/ais.zig");
};

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}

test "protocol modules" {
    _ = protocol.nmea;
    _ = protocol.sixbit;
    _ = protocol.ais;
}
