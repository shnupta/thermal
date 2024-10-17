const std = @import("std");
const thermal = @import("thermal");

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

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var sample_dir = try std.fs.cwd().openDir("samples", .{ .iterate = true });
    defer sample_dir.close();

    var walker = try sample_dir.walk(allocator);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        std.debug.print("\n\nlexing file {s}\n\n", .{entry.path});
        const sample_file = try sample_dir.openFile(entry.path, .{});
        defer sample_file.close();

        const bytes = try sample_file.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(bytes);

        var lexer = thermal.Lexer.init(bytes);
        while (lexer.next()) |token| {
            std.debug.print("{s:<21} | {s}\n", .{ token.id.nameForErrorDisplay(), token.nameForErrorDisplay(bytes) });
            if (token.id == .eof)
                break;
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
            break;
        }
    }
}
