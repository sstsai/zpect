const std = @import("std");

pub const NmeaFrame = struct {
    sentence_type: []const u8, // e.g. "AIVDM", "GPGGA"
    total_parts: ?u8,
    part_number: ?u8,
    channel: ?u8,
    payload: []const u8, // For AIVDM
    raw_fields: [][]const u8, // All fields for generic access

    // We allocate raw_fields if needed or just use iterator internally?
    // Let's keep it simple: specific parser for AIVDM, general for others.

    // For this task, we focus on AIVDM.
    // To support other sentence types, add handling logic in `parse` or create
    // separate parser functions delegated from here based on `sentence_type`.

    pub fn parse(allocator: std.mem.Allocator, line: []const u8) !NmeaFrame {
        // Validate checksum
        if (!validateChecksum(line)) {
            return error.InvalidChecksum;
        }

        // Find start ($ or !)
        const start = std.mem.indexOfAny(u8, line, "!$") orelse return error.InvalidFormat;
        const end = std.mem.lastIndexOfScalar(u8, line, '*') orelse return error.InvalidFormat;

        const content = line[start+1..end];

        // Split into fields
        // Note: In this Zig Master version, std.ArrayList is effectively unmanaged and requires
        // the allocator to be passed to methods like append/deinit.

        var fields = try std.ArrayList([]const u8).initCapacity(allocator, 8);
        errdefer fields.deinit(allocator);

        var it = std.mem.splitScalar(u8, content, ',');
        while (it.next()) |field| {
            try fields.append(allocator, field);
        }

        if (fields.items.len == 0) return error.InvalidFormat;

        const sentence_type = fields.items[0];

        // Check if AIVDM
        if (std.mem.eql(u8, sentence_type, "AIVDM") or std.mem.eql(u8, sentence_type, "AIVDO")) {
            if (fields.items.len < 6) return error.InvalidFormat;

            const total_parts = std.fmt.parseInt(u8, fields.items[1], 10) catch 0;
            const part_number = std.fmt.parseInt(u8, fields.items[2], 10) catch 0;
            const channel_str = fields.items[4];
            const channel = if (channel_str.len > 0) channel_str[0] else null;
            const payload = fields.items[5];

            return NmeaFrame{
                .sentence_type = sentence_type,
                .total_parts = total_parts,
                .part_number = part_number,
                .channel = channel,
                .payload = payload,
                .raw_fields = try fields.toOwnedSlice(allocator),
            };
        }

        // Generic NMEA
        return NmeaFrame{
            .sentence_type = sentence_type,
            .total_parts = null,
            .part_number = null,
            .channel = null,
            .payload = "",
            .raw_fields = try fields.toOwnedSlice(allocator),
        };
    }

    pub fn deinit(self: NmeaFrame, allocator: std.mem.Allocator) void {
        allocator.free(self.raw_fields);
    }

    pub fn validateChecksum(line: []const u8) bool {
        // Find start ! or $ and end *
        const start = std.mem.indexOfAny(u8, line, "!$") orelse return false;
        const end = std.mem.lastIndexOfScalar(u8, line, '*') orelse return false;

        if (end <= start) return false;
        if (end + 3 > line.len) return false; // *XX is 3 chars

        var sum: u8 = 0;
        for (line[start+1..end]) |c| {
            sum ^= c;
        }

        const checksum_hex = line[end+1..end+3];
        const expected = std.fmt.parseInt(u8, checksum_hex, 16) catch return false;

        return sum == expected;
    }
};
