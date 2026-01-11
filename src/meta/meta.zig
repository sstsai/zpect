const std = @import("std");
const quantity = @import("quantity.zig");

//
// 1. The SI metadata domain
//
pub const SI = struct {
    unit: ?[]const u8 = null,
    dim: ?quantity.Dimensions = null,
    scale: ?f64 = null,

    // Fluent method: behaves like a constructor with named params
    pub fn SI(comptime self: type, comptime args: anytype) type {
        const si = comptime blk: {
            var val: SI = .{};
            const args_fields = std.meta.fields(@TypeOf(args));
            inline for (args_fields) |field| {
                if (@hasField(SI, field.name)) {
                    @field(val, field.name) = @field(args, field.name);
                } else {
                    @compileError("SI does not have field: " ++ field.name);
                }
            }
            break :blk val;
        };
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

        // Expose each metadata struct under its own name
        pub usingnamespace ExposeMetas(metas);

        // Bring fluent methods into this namespace
        pub usingnamespace SI;
    };
}

fn ExposeMetas(comptime metas: anytype) type {
    // Note: Zig's `@Type` builtin allows creating structs with custom fields,
    // but it does not support dynamically generating named *declarations* (pub const ...).
    // Accessing `Speed.SI` where Speed is a type requires `SI` to be a declaration.
    // Therefore, we cannot genericize "Expose each metadata struct under its own name"
    // purely based on the type name without a manual registry or macro system.
    //
    // We implement a manual registry here for known metadata types.

    var found_si: ?SI = null;
    inline for (metas) |m| {
        if (@TypeOf(m) == SI) found_si = m;
    }

    return struct {
        pub usingnamespace if (found_si) |val| struct { pub const SI = val; } else struct {};
    };
}

test "Meta SI usage" {
    // Define Speed using the Meta and SI fluent API
    const Speed = Meta(f64, .{}).SI(.{
        .unit = "m/s",
        .dim = quantity.Dim_Speed,
        .scale = 1.0,
    });

    // Verify metadata values
    try std.testing.expectEqualStrings("m/s", Speed.SI.unit.?);
    try std.testing.expectEqual(1.0, Speed.SI.scale.?);

    // Verify Dimensions
    const dim = Speed.SI.dim.?;
    try std.testing.expectEqual(1, dim.length);
    try std.testing.expectEqual(-1, dim.time);

    // Verify Rep
    try std.testing.expect(Speed.rep == f64);
}
