topic_name: []const u8,
//The Packet Identifier field is only present in PUBLISH packets where the
//QoS level is 1 or 2. Section 2.2.1 provides more information about Packet
//Identifiers.
packet_ident: ?u16,
//The length of the Properties in the PUBLISH packet Variable Header encoded as
//a Variable Byte Integer.
properties: []const u8,
payload: []const u8,
ack_required: bool = false,

const Publish = @This();

pub const Properties = enum(u8) {
    payload_format = 1,
    // 3.3.2.3.2 Payload Format Indicator 1 (0x01) Byte, Identifier of the
    // Payload Format Indicator. Followed by the value of the Payload Forma t
    // Indicator, either of: ·         0 (0x00) Byte Indicates that the
    // Payload is unspecified bytes, which is equivalent to not sending a
    // Payload Format Indicator. ·         1 (0x01) Byte Indicates that the
    // Payload is UTF-8 Encoded Character Data. The UTF-8 data in the Payload
    // MUST be well-formed UTF-8 as defined by the Unicode specification
    // [Unicode] and restated in RFC 3629 [RFC3629]. A Server MUST send the
    // Payload Format Indicator unaltered to all subscribers receiving the
    // Application Message [MQTT-3.3.2-4]. The receiver MAY validate that the
    // Payload is of the format indicated, and if it is not send a PUBACK,
    // PUBREC, or DISCONNECT with Reason Code of 0x99 (Payload format
    // invalid) as described in section 4.13.  Refer to section 5.4.9 for
    // information about security issues in validating the payload format.

    msg_expire = 2,
    // 3.3.2.3.3 Message Expiry Interval` 2 (0x02) Byte, Identifier of the
    // Message Expiry Interval. Followed by the Four Byte Integer representing
    // the Message Expiry Interval. If present, the Four Byte value is the
    // lifetime of the Application Message in seconds. If the Message Expiry
    // Interval has passed and the Server has not managed to start onward
    // delivery to a matching subscriber, then it MUST delete the copy of the
    // message for that subscriber [MQTT-3.3.2-5]. If absent, the Application
    // Message does not expire. The PUBLISH packet sent to a Client by the Server
    // MUST contain a Message Expiry Interval set to the received value minus the
    // time that the Application Message has been waiting in the Server
    // [MQTT-3.3.2-6]. Refer to section 4.1 for details and limitations of stored
    // state.

    topic_alias = 35,
    // 3.3.2.3.4 Topic Alias 35 (0x23) Byte, Identifier of the Topic Alias.
    // Followed by the Two Byte integer representing the Topic Alias value. It is
    // a Protocol Error to include the Topic Alias value more than once. A Topic
    // Alias is an integer value that is used to identify the Topic instead of
    // using the Topic Name. This reduces the size of the PUBLISH packet, and is
    // useful when the Topic Names are long and the same Topic Names are used
    // repetitively within a Network Connection. The sender decides whether to
    // use a Topic Alias and chooses the value. It sets a Topic Alias mapping by
    // including a non-zero length Topic Name and a Topic Alias in the PUBLISH
    // packet. The receiver processes the PUBLISH as normal but also sets the
    // specified Topic Alias mapping to this Topic Name. If a Topic Alias mapping
    // has been set at the receiver, a sender can send a PUBLISH packet that
    // contains that Topic Alias and a zero length Topic Name. The receiver then
    // treats the incoming PUBLISH as if it had contained the Topic Name of the
    // Topic Alias. A sender can modify the Topic Alias mapping by sending
    // another PUBLISH in the same Network Connection with the same Topic Alias
    // value and a different non-zero length Topic Name. Topic Alias mappings
    // exist only within a Network Connection and last only for the lifetime of
    // that Network Connection. A receiver MUST NOT carry forward any Topic Alias
    // mappings from one Network Connection to another [MQTT-3.3.2-7]. A Topic
    // Alias of 0 is not permitted. A sender MUST NOT send a PUBLISH packet
    // containing a Topic Alias which has the value 0 [MQTT-3.3.2-8]. A Client
    // MUST NOT send a PUBLISH packet with a Topic Alias greater than the Topic
    // Alias Maximum value returned by the Server in the CONNACK packet
    // [MQTT-3.3.2-9]. A Client MUST accept all Topic Alias values greater than 0
    // and less than or equal to the Topic Alias Maximum value that it sent in
    // the CONNECT packet [MQTT-3.3.2-10]. A Server MUST NOT send a PUBLISH
    // packet with a Topic Alias greater than the Topic Alias Maximum value sent
    // by the Client in the CONNECT packet [MQTT-3.3.2-11]. A Server MUST accept
    // all Topic Alias values greater than 0 and less than or equal to the Topic
    // Alias Maximum value that it returned in the CONNACK packet
    // [MQTT-3.3.2-12]. The Topic Alias mappings used by the Client and Server
    // are independent from each other. Thus, when a Client sends a PUBLISH
    // containing a Topic Alias value of 1 to a Server and the Server sends a
    // PUBLISH with a Topic Alias value of 1 to that Client they will in general
    // be referring to different Topics.

    response_topic = 8,
    // 3.3.2.3.5 Response Topic 8 (0x08) Byte, Identifier of the Response Topic.
    // Followed by a UTF-8 Encoded String which is used as the Topic Name for a
    // response message. The Response Topic MUST be a UTF-8 Encoded String as
    // defined in section 1.5.4 [MQTT-3.3.2-13]. The Response Topic MUST NOT
    // contain wildcard characters [MQTT-3.3.2-14]. It is a Protocol Error to
    // include the Response Topic more than once. The presence of a Response
    // Topic identifies the Message as a Request. Refer to section 4.10 for more
    // information about Request / Response. The Server MUST send the Response
    // Topic unaltered to all subscribers receiving the Application Message
    // [MQTT-3.3.2-15]. Non-normative comment: The receiver of an Application
    // Message with a Response Topic sends a response by using the Response Topic
    // as the Topic Name of a PUBLISH. If the Request Message contains a
    // Correlation Data, the receiver of the Request Message should also include
    // this Correlation Data as a property in the PUBLISH packet of the Response
    // Message.

    correlation_data = 9,
    // 3.3.2.3.6 Correlation Data 9 (0x09) Byte, Identifier of the Correlation
    // Data. Followed by Binary Data. The Correlation Data is used by the sender
    // of the Request Message to identify which request the Response Message is
    // for when it is received. It is a Protocol Error to include Correlation
    // Data more than once. If the Correlation Data is not present, the Requester
    // does not require any correlation data. The Server MUST send the
    // Correlation Data unaltered to all subscribers receiving the Application
    // Message [MQTT-3.3.2-16]. The value of the Correlation Data only has
    // meaning to the sender of the Request Message and receiver of the Response
    // Message. Non-normative comment The receiver of an Application Message
    // which contains both a Response Topic and a Correlation Data sends a
    // response by using the Response Topic as the Topic Name of a PUBLISH. The
    // Client should also send the Correlation Data unaltered as part of the
    // PUBLISH of the responses. Non-normative comment If the Correlation Data
    // contains information which can cause application failures if modified by
    // the Client responding to the request, it should be encrypted and/or hashed
    // to allow any alteration to be detected. Refer to section 4.10 for more
    // information about Request / Response

    user_property = 38,
    // 3.3.2.3.7 User Property 38 (0x26) Byte, Identifier of the User Property.
    // Followed by a UTF-8 String Pair. The User Property is allowed to appear
    // multiple times to represent multiple name, value pairs. The same name is
    // allowed to appear more than once. The Server MUST send all User Properties
    // unaltered in a PUBLISH packet when forwarding the Application Message to a
    // Client [MQTT-3.3.2-17]. The Server MUST maintain the order of User
    // Properties when forwarding the Application Message [MQTT-3.3.2-18].
    // Non-normative comment This property is intended to provide a means of
    // transferring application layer name-value tags whose meaning and
    // interpretation are known only by the application programs responsible for
    // sending and receiving them.

    sub_ident = 11,
    // 3.3.2.3.8 Subscription Identifier 11 (0x0B), Identifier of the
    // Subscription Identifier. Followed by a Variable Byte Integer representing
    // the identifier of the subscription. The Subscription Identifier can have
    // the value of 1 to 268,435,455. It is a Protocol Error if the Subscription
    // Identifier has a value of 0. Multiple Subscription Identifiers will be
    // included if the publication is the result of a match to more than one
    // subscription, in this case their order is not significant.

    content_type = 3,
    // 3.3.2.3.9 Content Type 3 (0x03) Identifier of the Content Type. Followed
    // by a UTF-8 Encoded String describing the content of the Application
    // Message. The Content Type MUST be a UTF-8 Encoded String as defined in
    // section 1.5.4 [MQTT-3.3.2-19]. It is a Protocol Error to include the
    // Content Type more than once. The value of the Content Type is defined by
    // the sending and receiving application. A Server MUST send the Content Type
    // unaltered to all subscribers receiving the Application Message
    // [MQTT-3.3.2-20].
};

pub fn parse(publ: []const u8, flags: Packet.ControlType.Flags) !Publish {
    var fbs = std.io.fixedBufferStream(publ);
    var r = fbs.reader();
    const slen = try r.readInt(u16, .big);
    const topic = publ[2..][0..slen];
    try fbs.seekBy(slen);
    var pktid: ?u16 = null;
    var ack_required = false;
    switch (flags.qos) {
        .at_most_once => {},
        .at_least_once => {
            log.err("     expecting {s}", .{"PUBACK"});
            ack_required = true;
            pktid = try r.readInt(u16, .big);
        },
        .exactly_once => {
            log.err("     expecting {s} (not implemented)", .{"PUBREC"});
            ack_required = true;
        },
        .invalid => @panic("unreachable"),
    }
    const props = publ[2 + slen .. 2 + slen]; // TODO implement
    try fbs.seekBy(1); // short VLI

    return .{
        .topic_name = topic,
        .packet_ident = pktid,
        .properties = props,
        .payload = publ[fbs.pos..],
        .ack_required = ack_required,
    };
}

pub fn send(p: Publish, any: *AnyWriter) !void {
    var buffer: [0x4000]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    var w = fbs.writer();

    try w.writeInt(u16, @intCast(p.topic_name.len), .big);
    try w.writeAll(p.topic_name);
    if (p.packet_ident) |pid| {
        try w.writeInt(u16, pid, .big);
    }
    try w.writeByte(0); // properties not implemented
    try w.writeAll(p.payload);

    const pkt: Packet = .{
        .header = .{
            .kind = .publish,
            .flags = .{ .qos = if (p.packet_ident != null) .at_least_once else .at_most_once },
        },
        .body = fbs.getWritten(),
    };

    try pkt.send(any);
}

pub const Ack = struct {
    pub const Reason = enum(u8) {
        success = 0,
        no_match = 16,
        error_nos = 128,
        internal_error = 131,
        not_authorized = 135,
        topic_name_invalid = 144,
        packet_id_in_use = 145,
        over_quota = 151,
        payload_format_invalid = 153,
        _,
    };

    pub fn parse(r: *AnyReader) !Ack {
        _ = r;
        @panic("not implemented");
    }

    pub fn send(pkt_id: u16, code: Reason, any: *AnyWriter) !void {
        var buffer: [0x4000]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        var w = fbs.writer();

        try w.writeInt(u16, pkt_id, .big);
        try w.writeByte(@intFromEnum(code));
        try w.writeByte(0); //property length;

        const pkt: Packet = .{ .header = .{ .kind = .puback }, .body = fbs.getWritten() };
        try pkt.send(any);
    }
};

test Publish {
    const c = Publish{
        .topic_name = "publish",
        .packet_ident = null,
        .properties = &[0]u8{},
        .payload = &[0]u8{},
    };
    var buffer: [0xffff]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    var writer = fbs.writer();
    var any = writer.any();

    try c.send(&any);

    try std.testing.expectEqual(fbs.pos, 12);
}

const Packet = @import("Packet.zig");

const std = @import("std");
const log = std.log.scoped(.mqtt);
const AnyWriter = std.io.AnyWriter;
const AnyReader = std.io.AnyReader;
