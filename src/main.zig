//! makes a general attempt to follow
//! https://docs.oasis-open.org/mqtt/mqtt/v5.0/os/mqtt-v5.0-os.html
//! At least the parts that make sense

const mqtt = @import("mqtt.zig");

pub fn client() !void {
    log.err("startup", .{});
    const a = std.heap.page_allocator;

    var conn = std.net.tcpConnectToHost(a, "localhost", 1883) catch |e| {
        log.err("unable to connect to host", .{});
        return e;
    };
    var w = conn.writer();
    var any = w.any();

    try (mqtt.Connect{}).send(&any);

    var poller = std.io.poll(
        a,
        enum { srv },
        .{ .srv = .{ .handle = conn.handle } },
    );

    var poll_more = try poller.poll();
    var fifo = poller.fifo(.srv);
    while (fifo.readableLength() > 0 or try poller.poll()) {
        var ready = fifo.readableLength();

        if (ready < 6) {
            poll_more = try poller.poll();
            continue;
        }

        log.err("", .{});
        const pkt: mqtt.Packet.FixedHeader = @bitCast(fifo.readItem() orelse unreachable);

        var r = fifo.reader();
        var anyr = r.any();
        const reported = try mqtt.Packet.unpackVarInt(&anyr);

        ready = fifo.readableLength();
        while (ready < reported and poll_more) {
            log.err("    getting more now... {}/{}", .{ ready, reported });
            poll_more = try poller.poll();
            ready = fifo.readableLength();
        }

        switch (pkt.kind) {
            .CONNACK => {
                log.err("CONNACK ({}/{}) ", .{ reported, ready });
                fifo.discard(@min(ready, reported));
                try (mqtt.Subscribe{ .channels = &.{""} }).send(&any);
            },
            .PUBLISH => {
                const slen = try r.readInt(u16, .big);
                const topic = fifo.readableSliceOfLen(slen);
                log.err("PUBLISH [{s}] [{any}]", .{ topic, topic });
                fifo.discard(slen);
                var pktid: ?u16 = null;
                switch (pkt.flags.qos) {
                    .at_most_once => {
                        log.err("     expecting {s}", .{"nop"});
                    },
                    .at_least_once => {
                        log.err("     expecting {s}", .{"PUBACK"});
                        pktid = try r.readInt(u16, .big);
                        try mqtt.Publish.Ack.send(pktid.?, .success, &any);
                    },
                    .exactly_once => {
                        log.err("     expecting {s}", .{"PUBREC"});
                    },
                    .invalid => @panic("unreachable"),
                }

                const drop = @min(ready, reported) - 2 - slen - if (pktid != null) 2 else @as(usize, 0);

                const contents = fifo.readableSliceOfLen(drop);
                log.err(">{s}<", .{contents});

                log.err("     discarding {}", .{drop});
                fifo.discard(drop);
            },
            .SUBACK => {
                log.err("SUBACK ({}/{}) ", .{ reported, ready });
                fifo.discard(@min(ready, reported));
            },
            else => |tag| {
                ready = fifo.readableLength();
                log.err("", .{});
                log.err("", .{});
                log.err("", .{});
                log.err("read [{s}] ({}/{})", .{ @tagName(tag), reported, ready });
                log.err("discarding {}", .{@min(ready, reported)});
                log.err("", .{});
                log.err("", .{});
                log.err("", .{});
                fifo.discard(@min(ready, reported));
            },
        }
    }

    log.err("end going to exit", .{});
}

test "main" {
    std.testing.refAllDecls(@This());
}

const std = @import("std");
const log = std.log;
const AnyReader = std.io.AnyReader;
const AnyWriter = std.io.AnyWriter;
