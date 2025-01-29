//! makes a general attempt to follow
//! https://docs.oasis-open.org/mqtt/mqtt/v5.0/os/mqtt-v5.0-os.html
//! At least the parts that make sense

pub const Client = @import("Client.zig");
pub const Server = @import("Server.zig");

pub const Packet = @import("Packet.zig");
pub const Publish = @import("Publish.zig");
pub const Connect = @import("Connect.zig");
pub const Subscribe = @import("Subscribe.zig");
pub const Disconnect = @import("Disconnect.zig");

const mqtt = @This();

test mqtt {
    _ = &Client;
    _ = &Server;
    _ = &Packet;
    _ = &Publish;
    _ = &Connect;
    _ = &Subscribe;
    _ = &Disconnect;

    @import("std").testing.refAllDecls(mqtt);
}
