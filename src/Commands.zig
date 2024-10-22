pub const Command = []const u8;

// ESC
pub fn esc() Command {
    return &.{0x1B};
}

// @
pub fn at() Command {
    return &.{0x40};
}

// ESC @
pub fn initialisePrinter() Command {
    return comptime esc() ++ at();
}

// LF
pub fn lineFeed() Command {
    return &.{0x0A};
}

pub fn gs() Command {
    return &.{0x1D};
}

pub fn cut() Command {
    return comptime gs() ++ &[2]u8{ 'V', 0x00 };
}

pub fn printFeed() Command {
    return comptime esc() ++ &[1]u8{'d'};
}

pub fn underline() Command {
    return comptime esc() ++ &[1]u8{'-'};
}

pub fn emphasise() Command {
    return comptime esc() ++ &[1]u8{'E'};
}

pub fn justify() Command {
    return comptime esc() ++ &[1]u8{'a'};
}

pub fn printModes() Command {
    return comptime esc() ++ &[1]u8{'!'};
}

// TODO: FF (printing complete)
