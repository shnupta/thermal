const std = @import("std");
const Commands = @import("Commands.zig");

const Printer = @This();

const Writer = std.io.AnyWriter;
const Buffer = std.ArrayList(u8);

allocator: std.mem.Allocator,
writer: Writer,
buffer: Buffer,
internal_error: ?anyerror = null,

pub fn init(allocator: std.mem.Allocator, writer: Writer) Printer {
    return .{ .allocator = allocator, .writer = writer, .buffer = Buffer.init(allocator) };
}

pub fn deinit(self: *Printer) void {
    self.buffer.deinit();
}

/// Flushes the internal buffer to the writer.
pub fn flush(self: *Printer) !void {
    if (self.internal_error != null) {
        return self.internal_error.?;
    }
    _ = try self.writer.write(self.buffer.items);
    self.buffer.clearRetainingCapacity();
}

fn internalWrite(self: *Printer, bytes: []const u8) void {
    if (self.internal_error != null) return;
    self.buffer.appendSlice(bytes) catch |err| {
        self.internal_error = err;
    };
}

/// Clears the data in the print buffer and resets the printer modes to the modes that were in effect when the power was turned on.
/// - Any macro definitions are not cleared.
/// - Offline response selection is not cleared.
/// - Contents of user NV memory are not cleared.
/// - NV graphics (NV bit image) and NV user memory are not cleared.
/// - The maintenance counter value is not affected by this command.
/// - Software setting values are not cleared.
pub fn initialise(self: *Printer) void {
    self.internalWrite(Commands.initialisePrinter());
}

/// Prints the data in the print buffer and feeds one line, based on the current line spacing.
pub fn lineFeed(self: *Printer) void {
    self.internalWrite(Commands.lineFeed());
}

pub fn text(self: *Printer, bytes: []const u8) void {
    self.internalWrite(bytes);
}

pub fn formattedText(self: *Printer, comptime fmt: []const u8, args: anytype) void {
    if (self.internal_error != null) return;
    const formatted = std.fmt.allocPrint(self.allocator, fmt, args) catch |err| {
        self.internal_error = err;
        return;
    };
    defer self.allocator.free(formatted);
    self.text(formatted);
}

/// Performs a full cut of the paper.
pub fn cut(self: *Printer) void {
    self.internalWrite(Commands.cut());
}

/// Prints the data in the buffer and feeds lines, then cuts.
pub fn feedCut(self: *Printer, lines: u8) void {
    self.printFeedLines(lines);
    self.cut();
}

/// Prints the data in the buffer and feeds lines.
pub fn printFeedLines(self: *Printer, lines: u8) void {
    self.internalWrite(Commands.printFeed());
    self.internalWrite(&.{lines});
}

pub const UnderlineMode = enum(u8) { off = 0, one_dot = 1, two_dot = 2 };

/// Sets the underline style.
pub fn setUnderline(self: *Printer, mode: UnderlineMode) void {
    self.internalWrite(Commands.underline());
    self.internalWrite(&.{@intFromEnum(mode)});
}

pub fn emphasise(self: *Printer, toggle: bool) void {
    self.internalWrite(Commands.emphasise());
    self.internalWrite(&.{@as(u8, @intFromBool(toggle))});
}

pub const Justify = enum(u8) {
    left = 0,
    center = 1,
    right = 2,
};

pub fn justify(self: *Printer, just: Justify) void {
    self.internalWrite(Commands.justify());
    self.internalWrite(&.{@intFromEnum(just)});
}

pub fn resetStyles(self: *Printer) void {
    self.internalWrite(Commands.printModes());
    self.internalWrite(&.{0x00});
}
