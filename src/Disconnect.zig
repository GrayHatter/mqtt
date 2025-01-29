reason: Reason,

const Disconnect = @This();

pub const Reason = enum(u8) {
    normal = 0, // both
    normal_with_will = 4, // client
    unspecified = 128, // both
    malformed_packet = 129, // both
    protocol_error = 130, // both
    implementation_specific = 131, // both
    unauthorized = 135, // server
    busy = 137, // server
    shutting_down = 139, // server
    keep_alive_timeout = 141, // server
    session_taken_over = 142, // server
    topic_filter_invalid = 143, // server
    topic_name_invalid = 144, // both
    receive_maximum_exceeded = 147, // both
    topic_alias_invalid = 148, // both
    packet_too_large = 149, // both
    message_rate_too_high = 150, // both
    quota_exceeded = 151, // both
    administrative_action = 152, // both
    payload_format_invalid = 153, // both
    retain_not_supported = 154, // both
    qos_not_supported = 155, // server
    use_another_server = 156, // server
    server_moved = 157, // server
    shared_subscriptions_not_supported = 158, // server
    connection_rate_exceeded = 159, // server
    maximum_connect_time = 160, // server
    subscription_identifiers_not_supported = 161, // server
    wildcards_not_supported = 162, // server
};

pub fn send(d: Disconnect, any: *AnyWriter) !void {
    _ = d;
    _ = any;
    @panic("not implemented");
}

pub fn parse(r: *AnyReader) !Disconnect {
    const reason = try r.readByte();
    return .{
        .reason = intToEnum(Reason, reason) catch return error.InvalidPacket,
    };
}

test {
    _ = &send;
    _ = &parse;
}

const Packet = @import("Packet.zig");
const codec = @import("codec.zig");

const std = @import("std");
const log = std.log.scoped(.mqtt);
const AnyWriter = std.io.AnyWriter;
const AnyReader = std.io.AnyReader;
const intToEnum = std.meta.intToEnum;
