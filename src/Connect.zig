client_id: ?[]const u8 = null,
flags: Flags = .{},
keep_alive: KeepAlive = .{},

const Connect = @This();

pub const MQTT_VERSION = 5;

pub const Flags = packed struct(u8) {
    reserved: bool = false,
    // 3.1.2.4 requires this be 0
    clean_start: bool = true,
    will_flag: bool = false,
    will_qos: u2 = 0,
    will_retain: bool = false,
    password: bool = false,
    username: bool = false,
};

pub const KeepAlive = packed struct(u16) {
    seconds: u16 = 600,
};

pub fn send(c: Connect, any: *AnyWriter) !void {
    const props = [_]u8{ 0x11, 0x00, 0x00, 0x00, 0x03 };
    const client_id: []const u8 = c.client_id orelse
        "generic_mqtt_client";

    var buffer: [0x80]u8 = undefined;
    var fbs =
        std.io.fixedBufferStream(&buffer);
    var w = fbs.writer();

    try w.writeInt(u16, 4, .big);
    try w.writeAll("MQTT");
    try w.writeByte(MQTT_VERSION);
    try w.writeByte(@bitCast(c.flags));
    try w.writeInt(u16, @bitCast(c.keep_alive), .big);
    try w.writeByte(@intCast(props.len));
    try w.writeAll(&props);
    try w.writeInt(u16, @intCast(client_id.len), .big);
    try w.writeAll(client_id);

    const pkt: Packet = .{ .header = .{ .kind = .CONNECT }, .body = fbs.getWritten() };

    log.warn("writing connect packet", .{});
    try pkt.send(any);
}

pub const Ack = struct {
    pub const Properties = enum(u8) {
        //This is the length of the Properties in the CONNACK packet Variable
        //Header encoded as a Variable Byte Integer.

        expiry_interval = 17,
        //Followed by the Four Byte Integer representing the Session Expiry
        //Interval in seconds. It is a Protocol Error to include the Session
        //Expiry Interval more than once. If the Session Expiry Interval is
        //absent the value in the CONNECT Packet used. The server uses this
        //property to inform the Client that it is using a value other than that
        //sent by the Client in the CONNACK. Refer to section 3.1.2.11.2 for a
        //description of the use of Session Expiry Interval.

        receive_maximum = 33,
        //Followed by the Two Byte Integer representing the Receive Maximum
        //value. It is a Protocol Error to include the Receive Maximum value
        //more than once or for it to have the value 0. The Server uses this
        //value to limit the number of QoS 1 and QoS 2 publications that it is
        //willing to process concurrently for the Client. It does not provide a
        //mechanism to limit the QoS 0 publications that the Client might try to
        //send. If the Receive Maximum value is absent, then its value defaults
        //to 65,535. Refer to section 4.9 Flow Control for details of how the
        //Receive Maximum is used.

        maximum_qos = 36,
        // (0x24) Byte, Identifier of the Maximum QoS. Followed by a Byte with a
        // value of either 0 or 1. It is a Protocol Error to include Maximum QoS
        // more than once, or to have a value other than 0 or 1. If the Maximum
        // QoS is absent, the Client uses a Maximum QoS of 2. If a Server does
        // not support QoS 1 or QoS 2 PUBLISH packets it MUST send a Maximum QoS
        // in the CONNACK packet specifying the highest QoS it supports
        // [MQTT-3.2.2-9]. A Server that does not support QoS 1 or QoS 2 PUBLISH
        // packets MUST still accept SUBSCRIBE packets containing a Requested
        // QoS of 0, 1 or 2 [MQTT-3.2.2-10]. If a Client receives a Maximum QoS
        // from a Server, it MUST NOT send PUBLISH packets at a QoS level
        // exceeding the Maximum QoS level specified [MQTT-3.2.2-11]. It is a
        // Protocol Error if the Server receives a PUBLISH packet with a QoS
        // greater than the Maximum QoS it specified. In this case use
        // DISCONNECT with Reason Code 0x9B (QoS not supported) as described in
        // section 4.13 Handling errors. If a Server receives a CONNECT packet
        // containing a Will QoS that exceeds its capabilities, it MUST reject
        // the connection. It SHOULD use a CONNACK packet with Reason Code 0x9B
        // (QoS not supported) as described in section 4.13 Handling errors, and
        // MUST close the Network Connection [MQTT-3.2.2-12]. Non-normative
        // comment A Client does not need to support QoS 1 or QoS 2 PUBLISH
        // packets. If this is the case, the Client simply restricts the maximum
        // QoS field in any SUBSCRIBE commands it sends to a value it can
        // support.

        retain_available = 37,
        // (0x25) Byte, Identifier of Retain Available. Followed by a Byte
        // field. If present, this byte declares whether the Server supports
        // retained messages. A value of 0 means that retained messages are not
        // supported. A value of 1 means retained messages are supported. If not
        // present, then retained messages are supported. It is a Protocol Error
        // to include Retain Available more than once or to use a value other
        // than 0 or 1. If a Server receives a CONNECT packet containing a Will
        // Message with the Will Retain set to 1, and it does not support
        // retained messages, the Server MUST reject the connection request. It
        // SHOULD send CONNACK with Reason Code 0x9A (Retain not supported) and
        // then it MUST close the Network Connection [MQTT-3.2.2-13]. A Client
        // receiving Retain Available set to 0 from the Server MUST NOT send a
        // PUBLISH packet with the RETAIN flag set to 1 [MQTT-3.2.2-14]. If the
        // Server receives such a packet, this is a Protocol Error. The Server
        // SHOULD send a DISCONNECT with Reason Code of 0x9A (Retain not
        // supported) as described in section 4.13.

        maximum_packet_size = 39,
        // (0x27) Byte, Identifier of the Maximum Packet Size. Followed by a
        // Four Byte Integer representing the Maximum Packet Size the Server is
        // willing to accept. If the Maximum Packet Size is not present, there
        // is no limit on the packet size imposed beyond the limitations in the
        // protocol as a result of the remaining length encoding and the
        // protocol header sizes. It is a Protocol Error to include the Maximum
        // Packet Size more than once, or for the value to be set to zero. The
        // packet size is the total number of bytes in an MQTT Control Packet,
        // as defined in section 2.1.4. The Server uses the Maximum Packet Size
        // to inform the Client that it will not process packets whose size
        // exceeds this limit. The Client MUST NOT send packets exceeding
        // Maximum Packet Size to the Server [MQTT-3.2.2-15]. If a Server
        // receives a packet whose size exceeds this limit, this is a Protocol
        // Error, the Server uses DISCONNECT with Reason Code 0x95 (Packet too
        // large), as described in section 4.13.

        assigned_client_identifier = 18,
        // (0x12) Byte, Identifier of the Assigned Client Identifier. Followed
        // by the UTF-8 string which is the Assigned Client Identifier. It is a
        // Protocol Error to include the Assigned Client Identifier more than
        // once. The Client Identifier which was assigned by the Server because
        // a zero length Client Identifier was found in the CONNECT packet. If
        // the Client connects using a zero length Client Identifier, the Server
        // MUST respond with a CONNACK containing an Assigned Client Identifier.
        // The Assigned Client Identifier MUST be a new Client Identifier not
        // used by any other Session currently in the Server [MQTT-3.2.2-16].

        topic_alias_maximum = 34,
        // (0x22) Byte, Identifier of the Topic Alias Maximum. Followed by the
        // Two Byte Integer representing the Topic Alias Maximum value. It is a
        // Protocol Error to include the Topic Alias Maximum value more than
        // once. If the Topic Alias Maximum property is absent, the default
        // value is 0. This value indicates the highest value that the Server
        // will accept as a Topic Alias sent by the Client. The Server uses this
        // value to limit the number of Topic Aliases that it is willing to hold
        // on this Connection. The Client MUST NOT send a Topic Alias in a
        // PUBLISH packet to the Server greater than this value [MQTT-3.2.2-17].
        // A value of 0 indicates that the Server does not accept any Topic
        // Aliases on this connection. If Topic Alias Maximum is absent or 0,
        // the Client MUST NOT send any Topic Aliases on to the Server
        // [MQTT-3.2.2-18].

        reason_string = 31,
        // (0x1F) Byte Identifier of the Reason String. Followed by the UTF-8
        // Encoded String representing the reason associated with this response.
        // This Reason String is a human readable string designed for
        // diagnostics and SHOULD NOT be parsed by the Client. The Server uses
        // this value to give additional information to the Client. The Server
        // MUST NOT send this property if it would increase the size of the
        // CONNACK packet beyond the Maximum Packet Size specified by the Client
        // [MQTT-3.2.2-19]. It is a Protocol Error to include the Reason String
        // more than once. Non-normative comment Proper uses for the reason
        // string in the Client would include using this information in an
        // exception thrown by the Client code, or writing this string to a log.

        user_property = 38,
        // (0x26) Byte, Identifier of User Property. Followed by a UTF-8 String
        // Pair. This property can be used to provide additional information to
        // the Client including diagnostic information. The Server MUST NOT send
        // this property if it would increase the size of the CONNACK packet
        // beyond the Maximum Packet Size specified by the Client
        // [MQTT-3.2.2-20]. The User Property is allowed to appear multiple
        // times to represent multiple name, value pairs. The same name is
        // allowed to appear more than once. The content and meaning of this
        // property is not defined by this specification. The receiver of a
        // CONNACK containing this property MAY ignore it.

        wildcard_subscription_available = 40,
        // (0x28) Byte, Identifier of Wildcard Subscription Available. Followed
        // by a Byte field. If present, this byte declares whether the Server
        // supports Wildcard Subscriptions. A value is 0 means that Wildcard
        // Subscriptions are not supported. A value of 1 means Wildcard
        // Subscriptions are supported. If not present, then Wildcard
        // Subscriptions are supported. It is a Protocol Error to include the
        // Wildcard Subscription Available more than once or to send a value
        // other than 0 or 1. If the Server receives a SUBSCRIBE packet
        // containing a Wildcard Subscription and it does not support Wildcard
        // Subscriptions, this is a Protocol Error. The Server uses DISCONNECT
        // with Reason Code 0xA2 (Wildcard Subscriptions not supported) as
        // described in section 4.13. If a Server supports Wildcard
        // Subscriptions, it can still reject a particular subscribe request
        // containing a Wildcard Subscription. In this case the Server MAY send
        // a SUBACK Control Packet with a Reason Code 0xA2 (Wildcard
        // Subscriptions not supported).

        subscription_identifiers_available = 41,
        // (0x29) Byte, Identifier of Subscription Identifier Available.
        // Followed by a Byte field. If present, this byte declares whether the
        // Server supports Subscription Identifiers. A value is 0 means that
        // Subscription Identifiers are not supported. A value of 1 means
        // Subscription Identifiers are supported. If not present, then
        // Subscription Identifiers are supported. It is a Protocol Error to
        // include the Subscription Identifier Available more than once, or to
        // send a value other than 0 or 1. If the Server receives a SUBSCRIBE
        // packet containing Subscription Identifier and it does not support
        // Subscription Identifiers, this is a Protocol Error. The Server uses
        // DISCONNECT with Reason Code of 0xA1 (Subscription Identifiers not
        // supported) as described in section 4.13.

        shared_subscription_available = 42,
        // (0x2A) Byte, Identifier of Shared Subscription Available. Followed by
        // a Byte field. If present, this byte declares whether the Server
        // supports Shared Subscriptions. A value is 0 means that Shared
        // Subscriptions are not supported. A value of 1 means Shared
        // Subscriptions are supported. If not present, then Shared
        // Subscriptions are supported. It is a Protocol Error to include the
        // Shared Subscription Available more than once or to send a value other
        // than 0 or 1. If the Server receives a SUBSCRIBE packet containing
        // Shared Subscriptions and it does not support Shared Subscriptions,
        // this is a Protocol Error. The Server uses DISCONNECT with Reason Code
        // 0x9E (Shared Subscriptions not supported) as described in section
        // 4.13.

        server_keep_alive = 19,
        // (0x13) Byte, Identifier of the Server Keep Alive. Followed by a Two
        // Byte Integer with the Keep Alive time assigned by the Server. If the
        // Server sends a Server Keep Alive on the CONNACK packet, the Client
        // MUST use this value instead of the Keep Alive value the Client sent
        // on CONNECT [MQTT-3.2.2-21]. If the Server does not send the Server
        // Keep Alive, the Server MUST use the Keep Alive value set by the
        // Client on CONNECT [MQTT-3.2.2-22]. It is a Protocol Error to include
        // the Server Keep Alive more than once. Non-normative comment The
        // primary use of the Server Keep Alive is for the Server to inform the
        // Client that it will disconnect the Client for inactivity sooner than
        // the Keep Alive specified by the Client.

        response_information = 26,
        // (0x1A) Byte, Identifier of the Response Information. Followed by a
        // UTF-8 Encoded String which is used as the basis for creating a
        // Response Topic. The way in which the Client creates a Response Topic
        // from the Response Information is not defined by this specification.
        // It is a Protocol Error to include the Response Information more than
        // once. If the Client sends a Request Response Information with a value
        // 1, it is OPTIONAL for the Server to send the Response Information in
        // the CONNACK. Non-normative comment A common use of this is to pass a
        // globally unique portion of the topic tree which is reserved for this
        // Client for at least the lifetime of its Session. This often cannot
        // just be a random name as both the requesting Client and the
        // responding Client need to be authorized to use it. It is normal to
        // use this as the root of a topic tree for a particular Client. For the
        // Server to return this information, it normally needs to be correctly
        // configured. Using this mechanism allows this configuration to be done
        // once in the Server rather than in each Client. Refer to section 4.10
        // for more information about Request / Response.

        server_reference = 28,
        // (0x1C) Byte, Identifier of the Server Reference. Followed by a UTF-8
        // Encoded String which can be used by the Client to identify another
        // Server to use. It is a Protocol Error to include the Server Reference
        // more than once. The Server uses a Server Reference in either a
        // CONNACK or DISCONNECT packet with Reason code of 0x9C (Use another
        // server) or Reason Code 0x9D (Server moved) as described in section
        // 4.13. Refer to section 4.11 Server redirection for information about
        // how Server Reference is used.

        authentication_method = 21,
        // (0x15) Byte, Identifier of the Authentication Method. Followed by a
        // UTF-8 Encoded String containing the name of the authentication
        // method. It is a Protocol Error to include the Authentication Method
        // more than once. Refer to section 4.12 for more information about
        // extended authentication.

        authentication_data = 22,
        // (0x16) Byte, Identifier of the Authentication Data. Followed by
        // Binary Data containing authentication data. The contents of this data
        // are defined by the authentication method and the state of already
        // exchanged authentication data. It is a Protocol Error to include the
        // Authentication Data more than once. Refer to section 4.12 for more
        // information about extended authentication.
    };
};

const Packet = @import("Packet.zig");

const std = @import("std");
const log = std.log.scoped(.mqtt);
const AnyWriter = std.io.AnyWriter;
