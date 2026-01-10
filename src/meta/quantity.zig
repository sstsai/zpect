const std = @import("std");

/// Common units used in maritime and telemetry contexts.
pub const Unit = enum {
    None,
    Degrees,        // Angle
    Knots,          // Speed
    Meters,         // Distance
    Seconds,        // Time
    Hertz,          // Frequency
    Celsius,        // Temperature
    Pascal,         // Pressure
    Percent,        // Ratio
    RPM,            // Angular Velocity
};

/// Wraps a Schema type with a Unit.
/// This preserves all properties of the underlying Schema type (via usingnamespace)
/// and adds a `unit` declaration.
///
/// Usage:
/// const Speed = Quantity(U(10, u16), .Knots);
pub fn Quantity(comptime Schema: type, comptime unit_val: Unit) type {
    return struct {
        // Expose all declarations from the underlying Schema (bits, signed, scale, Underlying, etc.)
        pub usingnamespace Schema;
        // Add the unit metadata
        pub const unit = unit_val;
    };
}

test "Quantity wrapper preserves schema properties" {
    // Mock Schema type similar to what U(10, u16) produces
    const MockSchema = struct {
        pub const bits = 10;
        pub const signed = false;
        pub const Underlying = u16;
    };

    const Q = Quantity(MockSchema, .Knots);

    try std.testing.expectEqual(10, Q.bits);
    try std.testing.expectEqual(false, Q.signed);
    try std.testing.expectEqual(u16, Q.Underlying);
    try std.testing.expectEqual(Unit.Knots, Q.unit);
}
