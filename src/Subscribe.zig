channels: []const []const u8,

const Subscribe = @This();

pub fn send(s: Subscribe, any: *AnyWriter) !void {
    var buffer: [0x4000]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    var w = fbs.writer();

    log.err("writing subscribe packet", .{});
    try w.writeInt(u16, 10, .big);
    try w.writeByte(0); // No props
    for (s.channels) |ch| {
        try w.writeInt(u16, @intCast(ch.len), .big);
        try w.writeAll(ch);
        try w.writeByte(0x01); // options
    }
    const pkt: Packet = .{
        .header = .{ .kind = .SUBSCRIBE, .flags = try Packet.ControlType.SUBSCRIBE.flags() },
        .body = fbs.getWritten(),
    };
    try pkt.send(any);
}

const Packet = @import("Packet.zig");

const std = @import("std");
const log = std.log.scoped(.mqtt);
const AnyWriter = std.io.AnyWriter;
