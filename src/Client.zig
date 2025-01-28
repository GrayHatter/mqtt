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
heartbeat_interval: u16,
timeout: u64 = 10_000_000_000,
srv_topic_aliases: ?[]Alias = null,
cli_topic_aliases: ?[]Alias = null,

pub const Client = @This();

pub const Poller = std.io.Poller(PEnum);
pub const PEnum = enum { srv };

pub const Alias = struct {
    num: u16,
    alias: []const u8,
};

pub const Options = struct {
    heartbeat_interval: u16 = 3600,
};

pub fn init(a: Allocator, host: []const u8, port: u16, opts: Options) !Client {
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
        .heartbeat_interval = opts.heartbeat_interval,
    };
    return c;
}

/// might be rolled into init
pub fn connect(c: *Client) !bool {
    try c.send(Connect{
        .keep_alive = .{ .seconds = c.heartbeat_interval },
    });
    // grab the connack packet
    const pkt = try c.recv() orelse {
        log.err("recv timeout!", .{});
        return false;
    };
    switch (pkt) {
        .connack => {
            log.err("connack {any}", .{pkt});
            // handle connack, and record settings
            return true;
        },
        else => {
            log.err("Unexpected packet => {any}", .{pkt});
            return false;
        },
    }
}

/// if your type provides a compatible `send()` function delivering via this
/// allows the client to avoid sending additional heartbeats
pub fn send(c: *Client, packet: anytype) !void {
    var any = c.writer.any();
    c.last_tx = @intCast(std.time.timestamp());
    return try packet.send(&any);
}

pub fn heartbeat(c: *Client) !void {
    const beat_delay: u16 = @truncate(@as(usize, c.heartbeat_interval) * 90 / 100);
    if (std.time.timestamp() > c.last_tx + beat_delay) {
        log.err("sending heartbeat", .{});
        try c.send(Ping.Req{});
    }
}

pub fn recv(c: *Client) !?Packet.Parsed {
    var fifo = c.poller.fifo(.srv);
    var ready = fifo.readableLength();
    if (c.drop > 0) {
        fifo.discard(c.drop);
        c.drop = 0;
    }

    var poll_more = true;
    while (poll_more) {
        ready = fifo.readableLength();

        if (ready < 2) {
            try c.heartbeat();
            poll_more = try c.poller.pollTimeout(c.timeout);
            if (fifo.readableLength() == ready) return null;
            continue;
        }

        const pkt: Packet.FixedHeader = @bitCast(fifo.readItem().?);
        var fr = fifo.reader();
        var r = fr.any();
        const reported = try Packet.unpackVarInt(&r);
        ready = fifo.readableLength();
        while (ready < reported) {
            log.err("    getting more data... {}/{}", .{ ready, reported });
            poll_more = try c.poller.poll();
            if (!poll_more) {
                log.err("Unable to keep polling, and not enough data received", .{});
                log.err("header {any}", .{pkt});
                log.err("amount {} / {}", .{ reported, ready });
                log.err("data available {any}", .{fifo.readableSliceOfLen(fifo.readableLength())});
                return error.StreamCrashed;
            }
            ready = fifo.readableLength();
        }
        const payload = fifo.readableSliceOfLen(reported);
        c.drop = reported;
        return try Packet.parse(pkt, payload);
    }
    return error.StreamCrashed;
}

test Client {
    std.testing.refAllDecls(@This());
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
