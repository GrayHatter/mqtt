//! Builds and sends a packet. The MQTT v5 defined layout is always
//! FixedHeader u8      | CODE   | Flags  |
//! VarLen Int u8-u32   | u1 cont & u7    | ... up to 3 additional bytes
//! payload             | remaining bytes |
//!

header: FixedHeader,
body: []const u8,

const Packet = @This();

pub const FixedHeader = packed struct(u8) {
    flags: ControlType.Flags = .{},
    kind: ControlType,

    pub const CONNECT = FixedHeader{ .kind = .CONNECT };
};

pub const ControlType = enum(u4) {
    reserved = 0,
    CONNECT = 1,
    CONNACK = 2,
    PUBLISH = 3,
    PUBACK = 4,
    PUBREC = 5,
    PUBREL = 6,
    PUBCOMP = 7,
    SUBSCRIBE = 8,
    SUBACK = 9,
    UNSUBSCRIBE = 10,
    UNSUBACK = 11,
    PINGREQ = 12,
    PINGRESP = 13,
    DISCONNECT = 14,
    AUTH = 15,

    pub const Flags = packed struct(u4) {
        retain: bool = false,
        qos: QOS = .at_most_once,
        dup: bool = false,
    };
    /// MQTT 5.0 -- 2.1.3
    pub fn flags(cpt: ControlType) !Flags {
        return switch (cpt) {
            .reserved => error.InvalidCPT,
            .CONNECT, .CONNACK, .PUBLISH, .PUBACK, .PUBREC, .PUBCOMP => .{},
            .SUBACK, .UNSUBACK, .PINGREQ, .PINGRESP, .DISCONNECT, .AUTH => .{},
            .PUBREL, .SUBSCRIBE, .UNSUBSCRIBE => .{ .qos = .at_least_once },
        };
    }
};

pub const QOS = enum(u2) {
    at_most_once = 0,
    at_least_once = 1,
    exactly_once = 2,
    invalid = 3,
};

// TODO find better name
pub const Header = struct {
    header: FixedHeader,
    length: usize,
};

// TODO find better name
pub const Parsed = union(ControlType) {
    reserved: void,
    CONNECT: Connect,
    CONNACK: Connect.Ack,
    PUBLISH: Publish,
    PUBACK: Publish.Ack,
    PUBREC: void,
    PUBREL: void,
    PUBCOMP: void,
    SUBSCRIBE: Subscribe,
    SUBACK: Subscribe.Ack,
    UNSUBSCRIBE: void,
    UNSUBACK: void,
    PINGREQ: Ping.Req,
    PINGRESP: Ping.Resp,
    DISCONNECT: void,
    AUTH: void,
};

pub fn parse(header: FixedHeader, payload: []const u8) !Parsed {
    var fbs = std.io.fixedBufferStream(payload);
    var fbsr = fbs.reader();
    var r = fbsr.any();
    switch (header.kind) {
        .CONNECT => return .{ .CONNECT = try Connect.parse(&r) },
        .CONNACK => return .{ .CONNACK = try Connect.Ack.parse(&r) },
        .PUBLISH => return .{ .PUBLISH = try Publish.parse(payload, header.flags) },
        .PUBACK => return .{ .PUBACK = try Publish.Ack.parse(&r) },
        .SUBSCRIBE => return .{ .SUBSCRIBE = try Subscribe.parse(&r) },
        .SUBACK => return .{ .SUBACK = try Subscribe.Ack.parse(&r) },
        .PINGREQ => return .{ .PINGREQ = try Ping.Req.parse(payload) },
        .PINGRESP => return .{ .PINGRESP = try Ping.Resp.parse(payload) },
        .PUBREC, .PUBREL, .PUBCOMP, .UNSUBSCRIBE, .UNSUBACK, .DISCONNECT, .AUTH => {
            log.err("not implemented parser for {}", .{header.kind});
            @panic("not implemented");
        },
        else => |els| {
            log.err("not implemented parser for {}", .{els});
            unreachable;
        },
    }
    unreachable;
}

pub fn send(p: Packet, any: *AnyWriter) !void {
    try any.writeByte(@bitCast(p.header));
    _ = try writeVarInt(p.body.len, any);
    try any.writeAll(p.body);
    log.debug("send packet str: {s}", .{p.body});
    log.debug("send packet bytes: {any}", .{p.body});
}

pub fn writeVarInt(requested: usize, any: *AnyWriter) !usize {
    var written: usize = 0;
    var len = requested;
    if (len > 0xffffff7f) return error.PayloadTooLarge;
    while (written == 0 or len > 0) {
        const byte: u8 = @truncate(len & 0x7f);
        len >>= 7;
        try any.writeByte(byte | if (len > 0) 0x80 else @as(u8, 0x00));
        written += 1;
    }
    return written;
}

pub fn unpackVarInt(any: *AnyReader) !usize {
    var current: u8 = try any.readByte();
    var result: usize = current & 127;
    var mult: usize = 128;
    while (current > 127) {
        current = try any.readByte();
        result += @as(usize, (current & 127)) * mult;
        mult *= 128;
        if (mult > 128 * 128 * 128) return error.InvalidIntSize;
    }

    return result;
}

test unpackVarInt {
    var buffer = [_]u8{ 0, 0, 0, 0 };
    var fbs = std.io.fixedBufferStream(&buffer);
    var r = fbs.reader().any();

    var result = unpackVarInt(&r);
    try std.testing.expectEqual(fbs.pos, 1);
    try std.testing.expectEqual(result, 0);
    fbs.reset();
    buffer = [4]u8{ 127, 0, 0, 0 };
    result = unpackVarInt(&r);
    try std.testing.expectEqual(fbs.pos, 1);
    try std.testing.expectEqual(result, 127);
    fbs.reset();
    buffer = [4]u8{ 128, 1, 0, 0 };
    result = unpackVarInt(&r);
    try std.testing.expectEqual(fbs.pos, 2);
    try std.testing.expectEqual(result, 128);
    fbs.reset();
    buffer = [4]u8{ 129, 1, 0, 0 };
    result = unpackVarInt(&r);
    try std.testing.expectEqual(fbs.pos, 2);
    try std.testing.expectEqual(result, 129);
}

const Publish = @import("Publish.zig");
const Connect = @import("Connect.zig");
const Subscribe = @import("Subscribe.zig");
const Ping = @import("Ping.zig");

const std = @import("std");
const log = std.log.scoped(.mqtt);
const AnyWriter = std.io.AnyWriter;
const AnyReader = std.io.AnyReader;
