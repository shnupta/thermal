// Because I'm lazy, I'm skipping producing an IR for now and just directly
// encoding tokens into their direct form.
// Will write this out as a byte stream to then send to the printer to just get testing.
// Better make sure your program semantically makes sense!

const std = @import("std");
const Token = @import("lex.zig").Token;

const keywords = std.StaticStringMap([]const u8).initComptime(.{
    .{ "ESC", &[_]u8{0x1B} },
    .{ "GS", &[_]u8{0x1D} },
    .{ "LF", &[_]u8{0x0A} },
});

pub fn serialise(allocator: std.mem.Allocator, buf: []const u8, token: Token) []const u8 {
    switch (token.id) {
        .line_comment, .eof, .invalid => {
            return &[_]u8{};
        },
        .number => {
            return token.slice(buf);
        },
        .byte => {
            const int = std.fmt.parseUnsigned(u8, token.slice(buf), 0) catch |err| {
                std.debug.print("error parsing byte: {s} -> {s}\n", .{ token.slice(buf), @errorName(err) });
                return &[_]u8{};
            };
            std.debug.print("int: {d}\n", .{int});
            const bytes = std.mem.toBytes(int);
            std.debug.print("bytes: {x}\n", .{bytes});
            const byte_value: []u8 = allocator.alloc(u8, 1) catch {
                return &[_]u8{};
            };
            byte_value[0] = int;
            return byte_value;
        },
        .quoted_ascii_string => {
            const slice = token.slice(buf);
            return slice[1 .. slice.len - 1];
        },
        .literal => {
            return keywords.get(token.slice(buf)).?;
        },
    }
}
