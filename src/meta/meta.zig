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

// Mixin Generator for the fluent API
fn SI_Fluent(comptime Rep: type, comptime metas: anytype) type {
    return struct {
        pub fn SI(comptime args: anytype) type {
            var si = SI{};
            const fields = std.meta.fields(@TypeOf(args));
            inline for (fields) |f| {
                if (@hasField(SI, f.name)) {
                    @field(si, f.name) = @field(args, f.name);
                }
            }
            return MetaInternal(Rep, metas ++ .{ si });
        }
    };
}

//
// 2. Meta: returns a complete strong type at every step
//

/// Entry point: wraps a representation type with an empty metadata set.
pub fn Meta(comptime Rep: type) type {
    return MetaInternal(Rep, .{});
}

fn MetaInternal(comptime Rep: type, comptime metas: anytype) type {
    return struct {
        pub const rep = Rep;
        pub const meta = metas;

        // Smart exposure: If SI metadata exists, expose it as `SI` constant.
        // Otherwise, expose `SI` namespace (which contains the `SI` fluent method).
        pub usingnamespace Expose(Rep, metas);
    };
}

fn Expose(comptime Rep: type, comptime metas: anytype) type {
    var si_val: ?SI = null;
    inline for (metas) |m| {
        if (@TypeOf(m) == SI) si_val = m;
    }

    if (si_val) |v| {
        return struct { pub const SI = v; };
    } else {
        // Expose the fluent method which captures Rep and metas context
        return SI_Fluent(Rep, metas);
    }
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
                // "Reads like an SI dim" - using standard Dimensions struct
                .dim = quantity.Dim_Speed,
                // "Scale is a ratio"
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
