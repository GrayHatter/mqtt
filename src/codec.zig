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

pub fn readVarInt(any: *AnyReader) !usize {
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

test readVarInt {
    var buffer = [_]u8{ 0, 0, 0, 0 };
    var fbs = io.fixedBufferStream(&buffer);
    var r = fbs.reader().any();

    var result = readVarInt(&r);
    try std.testing.expectEqual(fbs.pos, 1);
    try std.testing.expectEqual(result, 0);
    fbs.reset();
    buffer = [4]u8{ 127, 0, 0, 0 };
    result = readVarInt(&r);
    try std.testing.expectEqual(fbs.pos, 1);
    try std.testing.expectEqual(result, 127);
    fbs.reset();
    buffer = [4]u8{ 128, 1, 0, 0 };
    result = readVarInt(&r);
    try std.testing.expectEqual(fbs.pos, 2);
    try std.testing.expectEqual(result, 128);
    fbs.reset();
    buffer = [4]u8{ 129, 1, 0, 0 };
    result = readVarInt(&r);
    try std.testing.expectEqual(fbs.pos, 2);
    try std.testing.expectEqual(result, 129);
}

const std = @import("std");
const io = std.io;
const AnyWriter = io.AnyWriter;
const AnyReader = io.AnyReader;
