const std = @import("std");

/// Physical Dimensions / Categories
pub const Category = enum {
    // SI Base Dimensions
    Length,
    Mass,
    Time,
    ElectricCurrent,
    ThermodynamicTemperature,
    AmountOfSubstance,
    LuminousIntensity,

    // Derived / Common Dimensions
    Angle,
    Speed,
    AngularVelocity,
    Frequency,
    Pressure,
    Voltage,
    Ratio,
};

/// Helper to create a distinct Unit type.
/// Each unit is a type that carries its definition as compile-time constants.
fn DefineUnit(
    comptime cat: Category,
    comptime scale_val: f64,
    comptime name_str: []const u8,
    comptime symbol_str: []const u8
) type {
    return struct {
        pub const category = cat;
        pub const scale = scale_val;
        pub const name = name_str;
        pub const symbol = symbol_str;
    };
}

// ============================================================================
// SI Base Units
// ============================================================================

pub const Meter    = DefineUnit(.Length,                   1.0, "Meter",    "m");
pub const Kilogram = DefineUnit(.Mass,                     1.0, "Kilogram", "kg");
pub const Second   = DefineUnit(.Time,                     1.0, "Second",   "s");
pub const Ampere   = DefineUnit(.ElectricCurrent,          1.0, "Ampere",   "A");
pub const Kelvin   = DefineUnit(.ThermodynamicTemperature, 1.0, "Kelvin",   "K");
pub const Mole     = DefineUnit(.AmountOfSubstance,        1.0, "Mole",     "mol");
pub const Candela  = DefineUnit(.LuminousIntensity,        1.0, "Candela",  "cd");

// ============================================================================
// Common Derived & Domain-Specific Units
// ============================================================================

// Angle (Base: Radian usually, but some consider it dimensionless)
pub const Radian = DefineUnit(.Angle, 1.0, "Radian", "rad");
pub const Degree = DefineUnit(.Angle, std.math.pi / 180.0, "Degree", "deg");

// Speed (Base: Meters per Second)
pub const MetersPerSecond = DefineUnit(.Speed, 1.0,      "Meters Per Second", "m/s");
pub const Knot            = DefineUnit(.Speed, 0.514444, "Knot",              "kn");
pub const KilometersPerHour = DefineUnit(.Speed, 0.277778, "Kilometers Per Hour", "km/h");

// Length Variants
pub const Kilometer    = DefineUnit(.Length, 1000.0, "Kilometer",     "km");
pub const NauticalMile = DefineUnit(.Length, 1852.0, "Nautical Mile", "NM");

// Time Variants
pub const Minute = DefineUnit(.Time, 60.0,   "Minute", "min");
pub const Hour   = DefineUnit(.Time, 3600.0, "Hour",   "h");

// Frequency
pub const Hertz = DefineUnit(.Frequency, 1.0, "Hertz", "Hz");

// Pressure
pub const Pascal = DefineUnit(.Pressure, 1.0, "Pascal", "Pa");
pub const Bar    = DefineUnit(.Pressure, 100000.0, "Bar", "bar");

// Temperature Variants
// Note: Celsius scale is 1.0 relative to Kelvin (interval), but has an offset.
// This definition captures the scalar magnitude.
pub const Celsius = DefineUnit(.ThermodynamicTemperature, 1.0, "Celsius", "°C");

// ============================================================================
// Wrapper
// ============================================================================

/// Wraps a Schema type with a Unit Type.
///
/// Usage:
/// const Speed = Quantity(U(10, u16), Knot);
pub fn Quantity(comptime Schema: type, comptime UnitType: type) type {
    return struct {
        // Expose all declarations from the underlying Schema
        pub usingnamespace Schema;
        // Add the unit type metadata
        pub const unit = UnitType;
    };
}

test "Quantity wrapper with distinct unit types" {
    // Mock Schema
    const U10 = struct {
        pub const bits = 10;
        pub const signed = false;
        pub const Underlying = u16;
    };

    const ShipSpeed = Quantity(U10, Knot);

    try std.testing.expectEqual(10, ShipSpeed.bits);
    try std.testing.expectEqual(Category.Speed, ShipSpeed.unit.category);
    try std.testing.expectApproxEqAbs(0.514444, ShipSpeed.unit.scale, 0.000001);
    try std.testing.expectEqualStrings("Knot", ShipSpeed.unit.name);
    try std.testing.expectEqualStrings("kn", ShipSpeed.unit.symbol);

    // Verify distinction
    const CarSpeed = Quantity(U10, KilometersPerHour);
    try std.testing.expect(ShipSpeed.unit != CarSpeed.unit);
}
