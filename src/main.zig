const std = @import("std");
const thermal = @import("thermal");
const elio = @import("elio");

fn getLineContainingPos(buffer: []const u8, pos: usize) struct { slice: []const u8, line_start: usize } {
    var line_start: usize = 0;
    var line_end: usize = 0;

    var idx: usize = pos;
    // find line start
    while (idx > 0 and buffer[idx] != '\n') : (idx -= 1) {}
    line_start = idx + 1;

    idx = pos;
    while (idx < buffer.len and buffer[idx] != '\n') : (idx += 1) {}
    line_end = idx;

    return .{ .slice = buffer[line_start..line_end], .line_start = line_start };
}

const red = "\x1b[31m";
const reset = "\x1b[0m";

// pub fn main() !void {
//     const allocator = std.heap.page_allocator;
//     var sample_dir = try std.fs.cwd().openDir("samples", .{ .iterate = true });
//     defer sample_dir.close();
//
//     var walker = try sample_dir.walk(allocator);
//     defer walker.deinit();
//     while (try walker.next()) |entry| {
//         std.debug.print("\n\nlexing file {s}\n\n", .{entry.path});
//         const sample_file = try sample_dir.openFile(entry.path, .{});
//         defer sample_file.close();
//
//         const bytes = try sample_file.readToEndAlloc(allocator, 1024 * 1024);
//         defer allocator.free(bytes);
//
//         var lexer = thermal.Lexer.init(bytes);
//         while (lexer.next()) |token| {
//             std.debug.print("{s:<21} | {s}\n", .{ token.id.nameForErrorDisplay(), token.nameForErrorDisplay(bytes) });
//             if (token.id == .eof)
//                 break;
//         } else |err| {
//             const err_token = lexer.error_token.?;
//             std.debug.print("\nError '{s}' on line {d}:\n\n", .{ @errorName(err), err_token.line_number });
//
//             const line_details = getLineContainingPos(bytes, err_token.start);
//             std.debug.print("{s}\n", .{line_details.slice});
//
//             const offset: usize = err_token.start - line_details.line_start;
//             const len: usize = err_token.end - err_token.start;
//
//             var space_buf: [1024]u8 = .{' '} ** 1024;
//             var caret_buf: [1024]u8 = .{'^'} ** 1024;
//             std.debug.print("{s}{s}{s}{s}\n", .{ space_buf[0..offset], red, caret_buf[0..len], reset });
//             break;
//         }
//     }
// }

fn connected(_: *anyopaque, conn: *elio.tcp.Connection) void {
    // conn.writeSlice(&.{ 0x1D, 0x56, 0 }) catch {};
    const allocator = std.heap.page_allocator;
    const sample_file = std.fs.cwd().openFile("samples/receipt.thermal", .{}) catch {
        return;
    };
    const bytes = sample_file.readToEndAlloc(allocator, 1024 * 1024) catch {
        return;
    };
    var lexer = thermal.Lexer.init(bytes);
    while (lexer.next()) |token| {
        if (token.id == .eof)
            break;
        if (token.id == .line_comment or token.id == .invalid)
            continue;

        // :( doesn't seem to work always with the receipt example
        const serialised_bytes = thermal.RawTokenSerialiser.serialise(allocator, bytes, token);

        std.debug.print("token: {s}\nserialised_bytes: {x}\n\n", .{ token.slice(bytes), serialised_bytes });
        conn.writeSlice(serialised_bytes) catch {
            std.debug.print("failed to send to socket\n", .{});
            return;
        };
    } else |err| {
        const err_token = lexer.error_token.?;
        std.debug.print("\nError '{s}' on line {d}:\n\n", .{ @errorName(err), err_token.line_number });

        const line_details = getLineContainingPos(bytes, err_token.start);
        std.debug.print("{s}\n", .{line_details.slice});

        const offset: usize = err_token.start - line_details.line_start;
        const len: usize = err_token.end - err_token.start;

        var space_buf: [1024]u8 = .{' '} ** 1024;
        var caret_buf: [1024]u8 = .{'^'} ** 1024;
        std.debug.print("{s}{s}{s}{s}\n", .{ space_buf[0..offset], red, caret_buf[0..len], reset });
    }
}

fn disconnected(_: *anyopaque, _: *elio.tcp.Connection) void {}
const vtable: elio.tcp.Connection.Handler.VTable = .{ .connected = connected, .disconnected = disconnected };

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var engine = elio.Engine.init(allocator);

    var conn = try elio.tcp.Connection.init(allocator, &engine, elio.tcp.Connection.Handler{ .ptr = undefined, .vtable = &vtable });

    try conn.connect("192.168.68.196", 9100);

    try engine.start();
}
