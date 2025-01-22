alloc: Allocator,
peer: std.net.Stream,
poller: Poller,
//reader: AnyReader,
writer: std.net.Stream.Writer,
/// The packet payload is left in the fifo, between calls to recv to avoid a
/// spurious alloc. Callers that need to retain the information should duplicate
/// data from the response as needed.
drop: usize = 0,
last_tx: usize = 0,

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
    try c.send(Connect{});
}

/// if your type provides a compatible `send()` function delivering via this
/// allows the client to avoid sending additional heartbeats
pub fn send(c: *Client, packet: anytype) !void {
    var any = c.writer.any();
    c.last_tx = @intCast(std.time.timestamp());
    return try packet.send(&any);
}

pub fn heartbeat(c: *Client) !void {
    if (std.time.timestamp() > c.last_tx + 500) {
        log.err("sending heartbeat", .{});
        try c.send(Ping.Req{});
    }
}

pub fn recv(c: *Client) !Packet.Parsed {
    var fifo = c.poller.fifo(.srv);
    var ready = fifo.readableLength();
    if (c.drop > 0) {
        fifo.discard(c.drop);
        c.drop = 0;
        ready = fifo.readableLength();
    }
    var poll_more = if (ready < 2) try c.poller.poll() else true;
    while (poll_more) {
        ready = fifo.readableLength();
        try c.heartbeat();

        if (ready < 4) {
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
const Ping = @import("Ping.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.mqtt);
const AnyReader = std.io.AnyReader;
const AnyWriter = std.io.AnyWriter;
