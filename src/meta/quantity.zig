const std = @import("std");

/// Represents the exponents of the 7 SI base quantities + Angle.
/// Used for Dimensional Analysis.
pub const Dimensions = struct {
    length: i8 = 0,
    mass: i8 = 0,
    time: i8 = 0,
    current: i8 = 0,
    temperature: i8 = 0,
    amount: i8 = 0,
    luminous: i8 = 0,
    angle: i8 = 0, // Treated as a dimension for safety in maritime context

    pub fn eq(a: Dimensions, b: Dimensions) bool {
        return a.length == b.length and
               a.mass == b.mass and
               a.time == b.time and
               a.current == b.current and
               a.temperature == b.temperature and
               a.amount == b.amount and
               a.luminous == b.luminous and
               a.angle == b.angle;
    }

    pub fn mul(a: Dimensions, b: Dimensions) Dimensions {
        return .{
            .length = a.length + b.length,
            .mass = a.mass + b.mass,
            .time = a.time + b.time,
            .current = a.current + b.current,
            .temperature = a.temperature + b.temperature,
            .amount = a.amount + b.amount,
            .luminous = a.luminous + b.luminous,
            .angle = a.angle + b.angle,
        };
    }

    pub fn div(a: Dimensions, b: Dimensions) Dimensions {
        return .{
            .length = a.length - b.length,
            .mass = a.mass - b.mass,
            .time = a.time - b.time,
            .current = a.current - b.current,
            .temperature = a.temperature - b.temperature,
            .amount = a.amount - b.amount,
            .luminous = a.luminous - b.luminous,
            .angle = a.angle - b.angle,
        };
    }
};

/// Represents a scalar conversion factor as a Ratio.
/// Uses f64 to allow representing irrational constants like Pi (for Degrees).
pub const Ratio = struct {
    num: f64,
    den: f64,

    pub fn value(self: Ratio) f64 {
        return self.num / self.den;
    }
};

/// Base Dimensions
pub const Dim_Length = Dimensions{ .length = 1 };
pub const Dim_Mass   = Dimensions{ .mass = 1 };
pub const Dim_Time   = Dimensions{ .time = 1 };
pub const Dim_Angle  = Dimensions{ .angle = 1 };
pub const Dim_Temp   = Dimensions{ .temperature = 1 };
pub const Dim_Freq   = Dimensions{ .time = -1 };
pub const Dim_Speed  = Dim_Length.div(Dim_Time);

/// Defines a Unit with a Dimension and a Scale relative to the Base Unit.
/// The Base Unit for a dimension has scale 1.0 (1/1).
fn DefineUnit(
    comptime dim: Dimensions,
    comptime scale_ratio: Ratio,
    comptime name_str: []const u8,
    comptime symbol_str: []const u8
) type {
    return struct {
        pub const dimension = dim;
        pub const scale = scale_ratio;
        pub const name = name_str;
        pub const symbol = symbol_str;
    };
}

// ============================================================================
// Base Units (Scale 1/1)
// ============================================================================

pub const Meter  = DefineUnit(Dim_Length, .{ .num = 1, .den = 1 }, "Meter", "m");
pub const Second = DefineUnit(Dim_Time,   .{ .num = 1, .den = 1 }, "Second", "s");
pub const Radian = DefineUnit(Dim_Angle,  .{ .num = 1, .den = 1 }, "Radian", "rad");
pub const Kelvin = DefineUnit(Dim_Temp,   .{ .num = 1, .den = 1 }, "Kelvin", "K");

// ============================================================================
// Derived Units
// ============================================================================

// Speed
pub const MetersPerSecond = DefineUnit(Dim_Speed, .{ .num = 1, .den = 1 }, "Meters Per Second", "m/s");
// 1 Knot = 1852 meters / 3600 seconds
pub const Knot = DefineUnit(Dim_Speed, .{ .num = 1852, .den = 3600 }, "Knot", "kn");
// 1 km/h = 1000 meters / 3600 seconds
pub const KilometersPerHour = DefineUnit(Dim_Speed, .{ .num = 1000, .den = 3600 }, "Kilometers Per Hour", "km/h");

// Angle
// 1 Degree = Pi / 180 Radians
pub const Degree = DefineUnit(Dim_Angle, .{ .num = std.math.pi, .den = 180.0 }, "Degree", "deg");

// Length
pub const Kilometer    = DefineUnit(Dim_Length, .{ .num = 1000, .den = 1 }, "Kilometer", "km");
pub const NauticalMile = DefineUnit(Dim_Length, .{ .num = 1852, .den = 1 }, "Nautical Mile", "NM");

// Time
pub const Minute = DefineUnit(Dim_Time, .{ .num = 60,   .den = 1 }, "Minute", "min");
pub const Hour   = DefineUnit(Dim_Time, .{ .num = 3600, .den = 1 }, "Hour",   "h");

// Frequency
pub const Hertz = DefineUnit(Dim_Freq, .{ .num = 1, .den = 1 }, "Hertz", "Hz");


// ============================================================================
// Wrapper
// ============================================================================
// Used by meta.zig for SI metadata

/// Wraps a Schema type with a Unit Type.
pub fn Quantity(comptime Schema: type, comptime UnitType: type) type {
    return struct {
        pub usingnamespace Schema;
        pub const unit = UnitType;
    };
}

test "Dimensional Analysis and Ratios" {
    // Check Speed Dimension
    const S = Dim_Speed;
    try std.testing.expectEqual(1, S.length);
    try std.testing.expectEqual(-1, S.time);
    try std.testing.expectEqual(0, S.mass);

    // Check Knot Scale
    const k_scale = Knot.scale.value();
    const expected = 1852.0 / 3600.0; // 0.514444...
    try std.testing.expectApproxEqAbs(expected, k_scale, 0.000001);

    // Check Degree Scale
    const d_scale = Degree.scale.value();
    const rads = std.math.pi / 180.0;
    try std.testing.expectApproxEqAbs(rads, d_scale, 0.0000001);

    // Wrapper check
    const MockSchema = struct { pub const bits = 10; };
    const Q = Quantity(MockSchema, Knot);
    try std.testing.expectEqual(1, Q.unit.dimension.length);
    try std.testing.expectEqual(-1, Q.unit.dimension.time);
}
