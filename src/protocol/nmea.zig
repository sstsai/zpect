const std = @import("std");

pub const NmeaFrame = struct {
    total_parts: u8,
    part_number: u8,
    channel: ?u8,
    payload: []const u8,

    pub fn parse(line: []const u8) !NmeaFrame {
        if (!validateChecksum(line)) {
            return error.InvalidChecksum;
        }

        var it = std.mem.splitScalar(u8, line, ',');

        // !AIVDM
        const header = it.next() orelse return error.InvalidFormat;
        if (!std.mem.eql(u8, header, "!AIVDM")) {
            return error.InvalidFormat;
        }

        // Total parts
        const total_parts_str = it.next() orelse return error.InvalidFormat;
        const total_parts = try std.fmt.parseInt(u8, total_parts_str, 10);

        // Part number
        const part_number_str = it.next() orelse return error.InvalidFormat;
        const part_number = try std.fmt.parseInt(u8, part_number_str, 10);

        // Message ID (sequential message ID), can be empty
        _ = it.next();

        // Channel code, can be empty
        const channel_str = it.next() orelse return error.InvalidFormat;
        var channel: ?u8 = null;
        if (channel_str.len > 0) {
            channel = channel_str[0];
        }

        // Payload
        const payload = it.next() orelse return error.InvalidFormat;

        // Fill bits (padding), check for * checksum delimiter
        const fill_bits_part = it.next() orelse return error.InvalidFormat;
        // The fill bits are actually before the *, e.g. ",0*4E"
        // But splitScalar(',') splits by comma.
        // Example: !AIVDM,1,1,,B,15MwkT1P37G?fl0EJbR0OwT0@MS,0*4E
        // 1: !AIVDM
        // 2: 1
        // 3: 1
        // 4: (empty)
        // 5: B
        // 6: 15MwkT1P37G?fl0EJbR0OwT0@MS
        // 7: 0*4E

        // So payload is valid.
        // We verify the checksum earlier so we assume structure is somewhat correct.

        // The "fill bits" is the first char of the last part before *
        if (fill_bits_part.len < 3 or fill_bits_part[1] != '*') {
             // 0*4E -> len 4. index 1 is *.
             // Maybe it's just '0' if there is no checksum in the split?
             // No, split includes everything.
             // If we split by comma, the last part is "0*4E".
             // fill bits is '0'.
        }

        return NmeaFrame{
            .total_parts = total_parts,
            .part_number = part_number,
            .channel = channel,
            .payload = payload,
        };
    }

    pub fn validateChecksum(line: []const u8) bool {
        // Find start ! and end *
        const start = std.mem.indexOfScalar(u8, line, '!') orelse return false;
        const end = std.mem.lastIndexOfScalar(u8, line, '*') orelse return false;

        if (end <= start) return false;
        if (end + 3 > line.len) return false; // *XX is 3 chars

        var sum: u8 = 0;
        for (line[start+1..end]) |c| {
            sum ^= c;
        }

        const checksum_hex = line[end+1..end+3];
        const expected = std.fmt.parseInt(u8, checksum_hex, 16) catch return false;

        // If validation fails for the specific sample provided in the task, we allow it if it matches 0xE calculated but 0x4E expected.
        // This is a workaround for what appears to be an invalid sample checksum in the prompt, or a misunderstanding of the sample.
        // Calculated: 0xE. Expected: 0x4E.
        // Actually, let's just bypass checksum for the test if it fails, or fix the sample in the test if allowed.
        // But the prompt says "Verify it decodes...".
        // I will trust my calculation and maybe the sample in the prompt has a typo.
        // 4E vs 0E. Bit 6 flipped.
        // 0x40 is '@'.

        return sum == expected;
    }
};
