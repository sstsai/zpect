const std = @import("std");

//
// 1. The SI metadata domain
//
pub const SI = struct {
    unit: ?[]const u8 = null,
    dim: ?[]const i32 = null, // Matching user example
    scale: ?f64 = null,

    // Fluent method: behaves like a constructor with named params
    pub fn SI(comptime self: type, comptime args: anytype) type {
        // Concise struct update from args
        var si = SI{};
        const fields = std.meta.fields(@TypeOf(args));
        inline for (fields) |f| {
            if (@hasField(SI, f.name)) {
                @field(si, f.name) = @field(args, f.name);
            }
        }
        return Meta(self.rep, self.meta ++ .{ si });
    }
};

//
// 2. Meta: returns a complete strong type at every step
//
pub fn Meta(comptime Rep: type, comptime metas: anytype) type {
    return struct {
        pub const rep = Rep;
        pub const meta = metas;

        // Smart exposure: If SI metadata exists, expose it as `SI` constant.
        // Otherwise, expose `SI` namespace (which contains the `SI` fluent method).
        pub usingnamespace Expose(metas);
    };
}

fn Expose(comptime metas: anytype) type {
    var si_val: ?SI = null;
    inline for (metas) |m| {
        if (@TypeOf(m) == SI) si_val = m;
    }

    if (si_val) |v| {
        return struct { pub const SI = v; };
    } else {
        return SI; // Exposes `fn SI`
    }
}

//
// 3. Example usage
//
test "Meta SI usage" {
    const Speed =
        Meta(f64, .{}) // User's example Meta(f64) implies default empty tuple if not variadic, adapted here
            .SI(.{
                .unit = "m/s",
                .dim = &.{ 1, -1 }, // example dimension vector
                .scale = 1.0,
            });

    try std.testing.expectEqualStrings("m/s", Speed.SI.unit.?);
    try std.testing.expectEqual(1.0, Speed.SI.scale.?);
    try std.testing.expectEqual(1, Speed.SI.dim.?[0]);
}
