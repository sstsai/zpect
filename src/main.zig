const std = @import("std");

fn printFields(comptime T: type) void {
    const info = @typeInfo(T);
    switch (info) {
        .Struct => |struct_info| {
            inline for (struct_info.fields) |field| {
                std.debug.print("Field: {s}, Type: {s}\n", .{ field.name, @typeName(field.type) });
            }
        },
        else => {
            @compileError("printFields requires a struct type.");
        },
    }
}

pub fn main() !void {
    const MyStruct = struct {
        foo: i32,
        bar: bool,
    };

    printFields(MyStruct);
}