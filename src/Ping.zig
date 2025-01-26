pub const Req = struct {
    pub fn send(_: Req, any: *AnyWriter) !void {
        return try (Packet{ .header = .{ .kind = .pingreq }, .body = &[0]u8{} }).send(any);
    }

    pub fn parse(_: []const u8) !Req {
        return .{};
    }
};

pub const Resp = struct {
    pub fn send(_: Resp, any: *AnyWriter) !void {
        return try (Packet{ .header = .{ .kind = .pingresp }, .body = &[0]u8{} }).send(any);
    }

    pub fn parse(_: []const u8) !Resp {
        return .{};
    }
};

const std = @import("std");
const Packet = @import("Packet.zig");
const AnyWriter = std.io.AnyWriter;
