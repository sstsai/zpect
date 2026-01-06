const std = @import("std");

pub const TagBlock = struct {
    // For now, we store raw key-value pairs as slices.
    // In a real system, we might want a hash map or specific fields.
    // Given the constraints, a simple iterator or list of pairs is good.
    // But we need to return something usable.
    // Let's store the raw text of the tag block content for further parsing if needed,
    // or parse into a simple HashMap-like structure if allocator is provided.

    // Minimal implementation: Just validate and strip.
    // But user asked to "handle" it.
    // Let's provide an iterator over tags.

    raw_content: []const u8, // Content inside \...\ excluding checksum

    pub const TagIterator = struct {
        it: std.mem.SplitIterator(u8, .scalar),

        pub fn next(self: *TagIterator) ?std.meta.Tuple(&.{[]const u8, []const u8}) {
            const part = self.it.next() orelse return null;
            if (part.len == 0) return self.next(); // Skip empty if any

            // Split by :
            var kv_it = std.mem.splitScalar(u8, part, ':');
            const key = kv_it.next() orelse return null; // Should not happen if part len > 0
            const value = kv_it.next() orelse "";

            return .{key, value};
        }
    };

    pub fn iterator(self: TagBlock) TagIterator {
        return TagIterator{ .it = std.mem.splitScalar(u8, self.raw_content, ',') };
    }
};

pub fn parse(line: []const u8) !struct { tag_block: ?TagBlock, rest: []const u8 } {
    if (line.len == 0) return error.EmptyLine;

    if (line[0] != '\\') {
        // No tag block
        return .{ .tag_block = null, .rest = line };
    }

    // Find end of tag block
    // Format: \ ... *hh\
    const end_marker = std.mem.indexOf(u8, line, "*") orelse return error.InvalidTagBlock;

    // Checksum is 2 chars after *
    if (end_marker + 3 >= line.len) return error.InvalidTagBlock;

    // The tag block ends with \ which should be at end_marker + 3
    if (line[end_marker + 3] != '\\') {
         // Maybe it continues?
         // "ends with a checksum like *hh, and is immediately followed by..."
         // The standard says: \g:1-2-3*hh\$...
         // So it ends with \
         return error.InvalidTagBlock;
    }

    const content = line[1..end_marker];
    const checksum_hex = line[end_marker+1..end_marker+3];
    const expected_checksum = try std.fmt.parseInt(u8, checksum_hex, 16);

    // Validate Checksum
    var sum: u8 = 0;
    for (content) |c| {
        sum ^= c;
    }

    if (sum != expected_checksum) {
        return error.InvalidChecksum;
    }

    return .{
        .tag_block = TagBlock{ .raw_content = content },
        .rest = line[end_marker+4..],
    };
}
