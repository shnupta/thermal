const std = @import("std");
const thermal = @import("thermal");
const elio = @import("elio");

fn connected(_: *anyopaque, conn: *elio.tcp.Connection) void {
    var printer = thermal.Printer.init(std.heap.page_allocator, ConnectionWriter.any(conn));
    defer printer.deinit();
    // var printer = thermal.Printer.init(ByteWriter.any()) catch {
    //     return;
    // };
    printer.initialise();
    printer.setUnderline(.two_dot);
    printer.justify(.center);
    printer.text("Good Morning");
    printer.lineFeed();
    printer.resetStyles();
    printer.justify(.left);
    printer.printFeedLines(3);
    printer.text("Today is a lovely day for printing.");
    printer.feedCut(6);
    printer.flush() catch |err| {
        std.debug.print("Uh oh: {s}\n", .{@errorName(err)});
        return;
    };
}

fn disconnected(_: *anyopaque, _: *elio.tcp.Connection) void {}

const vtable: elio.tcp.Connection.Handler.VTable = .{ .connected = connected, .disconnected = disconnected };

const ByteWriter = struct {
    fn any() std.io.AnyWriter {
        return .{
            .context = undefined,
            .writeFn = write,
        };
    }

    fn write(_: *const anyopaque, bytes: []const u8) anyerror!usize {
        std.debug.print("{x}", .{bytes});
        return bytes.len;
    }
};

const ConnectionWriter = struct {
    fn any(conn: *elio.tcp.Connection) std.io.AnyWriter {
        return .{
            .context = conn,
            .writeFn = write,
        };
    }

    fn write(context: *const anyopaque, bytes: []const u8) anyerror!usize {
        const conn: *elio.tcp.Connection = @constCast(@alignCast(@ptrCast(context)));
        try conn.writeSlice(bytes);
        return bytes.len;
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var engine = elio.Engine.init(allocator);

    var conn = try elio.tcp.Connection.init(allocator, &engine, elio.tcp.Connection.Handler{ .ptr = undefined, .vtable = &vtable });
    try conn.connect("192.168.68.196", 9100);

    try engine.start();
}
