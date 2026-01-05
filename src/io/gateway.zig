const std = @import("std");

pub const Gateway = struct {
    stream: std.net.Stream,

    pub const MAGIC: u32 = 0x000053AA;

    pub fn connect(allocator: std.mem.Allocator, address: []const u8, port: u16) !Gateway {
        _ = allocator; // Autodoc: unused for now as Stream manages itself
        const stream = try std.net.tcpConnectToAddress(try std.net.Address.parseIp4(address, port));
        return Gateway{ .stream = stream };
    }

    pub fn readPacket(self: *Gateway, allocator: std.mem.Allocator) ![]u8 {
        var reader = self.stream.reader();

        // Read Magic (4 bytes)
        const magic = try reader.readInt(u32, .big);
        if (magic != MAGIC) {
            return error.InvalidMagic;
        }

        // Read Length (2 bytes)
        const length = try reader.readInt(u16, .big);

        // Read Payload
        const payload = try allocator.alloc(u8, length);
        errdefer allocator.free(payload);

        const bytes_read = try reader.readAll(payload);
        if (bytes_read != length) {
            return error.IncompletePacket;
        }

        return payload;
    }

    pub fn close(self: *Gateway) void {
        self.stream.close();
    }
};
