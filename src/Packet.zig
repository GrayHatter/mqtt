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

    pub const CONNECT = FixedHeader{ .kind = .connect };
};

pub const ControlType = enum(u4) {
    reserved = 0,
    connect = 1,
    connack = 2,
    publish = 3,
    puback = 4,
    pubrec = 5,
    pubrel = 6,
    pubcomp = 7,
    subscribe = 8,
    suback = 9,
    unsubscribe = 10,
    unsuback = 11,
    pingreq = 12,
    pingresp = 13,
    disconnect = 14,
    auth = 15,

    pub const Flags = packed struct(u4) {
        retain: bool = false,
        qos: Qos = .at_most_once,
        dup: bool = false,
    };

    /// mqtt 5.0 -- 2.1.3
    pub fn flags(cpt: ControlType) !Flags {
        return switch (cpt) {
            .reserved => error.Invalidcpt,
            .connect, .connack, .publish, .puback, .pubrec, .pubcomp => .{},
            .suback, .unsuback, .pingreq, .pingresp, .disconnect, .auth => .{},
            .pubrel, .subscribe, .unsubscribe => .{ .qos = .at_least_once },
        };
    }
};

pub const Qos = enum(u2) {
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
    connect: Connect,
    connack: Connect.Ack,
    publish: Publish,
    puback: Publish.Ack,
    pubrec: void,
    pubrel: void,
    pubcomp: void,
    subscribe: Subscribe,
    suback: Subscribe.Ack,
    unsubscribe: void,
    unsuback: void,
    pingreq: Ping.Req,
    pingresp: Ping.Resp,
    disconnect: Disconnect,
    auth: void,
};

pub fn parse(header: FixedHeader, payload: []const u8) !Parsed {
    var fbs = std.io.fixedBufferStream(payload);
    var fbsr = fbs.reader();
    var r = fbsr.any();
    switch (header.kind) {
        .connect => return .{ .connect = try Connect.parse(&r) },
        .connack => return .{ .connack = try Connect.Ack.parse(&r) },
        .publish => return .{ .publish = try Publish.parse(payload, header.flags) },
        .puback => return .{ .puback = try Publish.Ack.parse(&r) },
        .subscribe => return .{ .subscribe = try Subscribe.parse(&r) },
        .suback => return .{ .suback = try Subscribe.Ack.parse(&r) },
        .pingreq => return .{ .pingreq = try Ping.Req.parse(payload) },
        .pingresp => return .{ .pingresp = try Ping.Resp.parse(payload) },
        .disconnect => return .{ .disconnect = try Disconnect.parse(&r) },
        .pubrec, .pubrel, .pubcomp, .unsubscribe, .unsuback, .auth => {
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

const Publish = @import("Publish.zig");
const Connect = @import("Connect.zig");
const Subscribe = @import("Subscribe.zig");
const Ping = @import("Ping.zig");
const Disconnect = @import("Disconnect.zig");
const codec = @import("codec.zig");
const writeVarInt = codec.writeVarInt;
const readVarInt = codec.readVarInt;

const std = @import("std");
const log = std.log.scoped(.mqtt);
const AnyWriter = std.io.AnyWriter;
const AnyReader = std.io.AnyReader;
