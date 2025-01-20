alloc: Allocator,
peer: std.net.Stream,
poller: Poller,
//reader: AnyReader,
writer: std.net.Stream.Writer,
drop: usize = 0,

pub const Client = @This();

pub const Poller = std.io.Poller(PEnum);
pub const PEnum = enum { srv };

pub fn init(a: Allocator, host: []const u8, port: u16) !Client {
    const peer = try std.net.tcpConnectToHost(a, host, port);
    const poller = std.io.poll(
        a,
        PEnum,
        .{ .srv = .{ .handle = peer.handle } },
    );
    const c: Client = .{
        .alloc = a,
        .peer = peer,
        .poller = poller,
        .writer = peer.writer(),
    };
    return c;
}

/// might be rolled into init
pub fn connect(c: *Client) !void {
    var w = c.writer.any();
    try (Connect{}).send(&w);
}

pub fn recv(c: *Client) !Packet.Parsed {
    var fifo = c.poller.fifo(.srv);
    var ready = fifo.readableLength();
    if (c.drop > 0 and ready >= c.drop) {
        fifo.discard(c.drop);
        c.drop = 0;
    }
    var poll_more = try c.poller.poll();
    while (poll_more) {
        ready = fifo.readableLength();
        log.err("loop", .{});

        if (ready < 6) {
            poll_more = try c.poller.poll();
            continue;
        }

        const pkt: Packet.FixedHeader = @bitCast(fifo.readItem().?);
        var fr = fifo.reader();
        var r = fr.any();
        const reported = try Packet.unpackVarInt(&r);
        while (ready < reported and poll_more) {
            log.err("    getting more data... {}/{}", .{ ready, reported });
            poll_more = try c.poller.poll();
            ready = fifo.readableLength();
        }
        const payload = fifo.readableSliceOfLen(reported);

        c.drop = reported;
        return try Packet.parse(pkt, payload);
    }
    return error.StreamCrashed;
}

const Packet = @import("Packet.zig");
const Publish = @import("Publish.zig");
const Connect = @import("Connect.zig");
const Subscribe = @import("Subscribe.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.mqtt);
const AnyReader = std.io.AnyReader;
const AnyWriter = std.io.AnyWriter;
