const std = @import("std");
const quantity = @import("quantity.zig");

//
// 1. The SI metadata domain (Data Structure)
//
pub const SI = struct {
    unit: ?[]const u8 = null,
    dim: ?quantity.Dimensions = null,
    scale: ?quantity.Ratio = null,
};

//
// 2. Meta: returns a complete strong type at every step
//

/// Entry point: wraps a representation type with empty metadata.
pub fn Meta(comptime Rep: type) type {
    return MetaInternal(Rep, .{});
}

fn MetaInternal(comptime Rep: type, comptime metas: anytype) type {

    // Check if SI metadata is already present in the tuple
    var si_val: ?SI = null;
    inline for (metas) |m| {
        if (@TypeOf(m) == SI) si_val = m;
    }

    // Define the Fluent API Mixin
    // This captures `Rep` and `metas` from the `MetaInternal` scope.
    const FluentMixin = struct {
        pub fn SI(comptime args: anytype) type {
            var si = SI{};
            const fields = std.meta.fields(@TypeOf(args));
            inline for (fields) |f| {
                if (@hasField(SI, f.name)) {
                    @field(si, f.name) = @field(args, f.name);
                } else {
                    @compileError("SI metadata does not have field: '" ++ f.name ++ "'");
                }
            }
            // Recursively call MetaInternal with the new metadata appended
            return MetaInternal(Rep, metas ++ .{ si });
        }
    };

    return struct {
        pub const rep = Rep;
        pub const meta = metas;

        // Smart exposure:
        // If SI metadata exists, expose it as `SI` constant.
        // Otherwise, expose the FluentMixin (which contains the `SI` builder method).
        pub usingnamespace if (si_val) |v|
            struct { pub const SI = v; }
        else
            FluentMixin;
    };
}

//
// 3. Example usage
//
test "Meta SI usage" {
    // Usage 1: Define Speed using fluent API
    const Speed =
        Meta(f64)
            .SI(.{
                .unit = "m/s",
                .dim = quantity.Dim_Speed,
                .scale = .{ .num = 1.0, .den = 1.0 },
            });

    try std.testing.expectEqualStrings("m/s", Speed.SI.unit.?);
    try std.testing.expectEqual(1.0, Speed.SI.scale.?.value());
    try std.testing.expectEqual(1, Speed.SI.dim.?.length);

    // Usage 2: Custom Dimensions
    const Accel = Meta(f64).SI(.{
        .unit = "m/s^2",
        .dim = .{ .length = 1, .time = -2 },
        .scale = .{ .num = 1, .den = 1 }
    });

    try std.testing.expectEqual(-2, Accel.SI.dim.?.time);
}
