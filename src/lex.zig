const std = @import("std");

// TODO: take inspiration from the zig tokenizer.zig and look for actual keywords
// as well

pub const Token = struct {
    id: Id,
    start: usize,
    end: usize,
    line_number: usize,

    pub const Id = enum {
        literal,
        number,
        byte,
        quoted_ascii_string,
        eof,
        line_comment,
        invalid,

        pub fn nameForErrorDisplay(self: Id) []const u8 {
            return switch (self) {
                .literal => "<literal>",
                .number => "<number>",
                .byte => "<byte>",
                .quoted_ascii_string => "<quoted_ascii_string>",
                .eof => "<eof>",
                .line_comment => "<line_comment>",
                .invalid => unreachable,
            };
        }
    };

    pub fn slice(self: Token, buffer: []const u8) []const u8 {
        return buffer[self.start..self.end];
    }

    pub fn nameForErrorDisplay(self: Token, buffer: []const u8) []const u8 {
        return switch (self.id) {
            .eof => self.id.nameForErrorDisplay(),
            else => self.slice(buffer),
        };
    }
};

pub const Lexer = struct {
    const Self = @This();

    buffer: []const u8,
    pos: usize,
    line_number: usize,
    error_token: ?Token = null,
    at_start_of_line: bool = true,

    pub fn init(buffer: []const u8) Self {
        return Lexer{
            .buffer = buffer,
            .pos = 0,
            .line_number = 0,
        };
    }

    const Error = error{
        InvalidCharacterInNumberLiteral,
        InvalidCharacterInByteLiteral,
        UnterminatedQuotedAsciiString,
        InvalidDigitInLiteral,
        InvalidSingleQuote,
        InvalidCommentLiteral,
    };

    const State = enum {
        start,
        literal,
        number_literal,
        byte_literal,
        first_nibble,
        second_nibble,
        quoted_ascii_string,
        single_quote,
        single_quote_forward_slash,
        line_comment,
    };

    pub fn next(self: *Self) Error!Token {
        const start_pos = self.pos;
        var result = Token{
            .id = .eof,
            .start = start_pos,
            .line_number = self.line_number,
            .end = undefined,
        };
        var state = State.start;

        while (self.pos < self.buffer.len) : (self.pos += 1) {
            const c = self.buffer[self.pos];
            switch (state) {
                .start => {
                    switch (c) {
                        '\n' => {
                            result.start = self.pos + 1;
                            self.line_number += 1;
                            result.line_number = self.line_number;
                            self.at_start_of_line = true;
                        },
                        ' ', '\t', '\x05'...'\x08', '\x0B'...'\x0C', '\x0E'...'\x1F' => {
                            result.start = self.pos + 1;
                        },
                        '"' => state = .quoted_ascii_string,
                        '0'...'9' => state = .number_literal,
                        '\'' => {
                            if (!self.at_start_of_line) {
                                self.error_token = .{
                                    .id = .line_comment,
                                    .start = result.start,
                                    .end = self.pos + 1,
                                    .line_number = self.line_number,
                                };
                                return Error.InvalidSingleQuote;
                            }
                            state = .single_quote;
                        },
                        else => {
                            state = .literal;
                            result.id = .literal;
                        },
                    }
                },
                .single_quote => {
                    switch (c) {
                        '/' => state = .single_quote_forward_slash,
                        else => state = .literal,
                    }
                },
                .single_quote_forward_slash => {
                    switch (c) {
                        '/' => state = .line_comment,
                        else => state = .literal,
                    }
                },
                .line_comment => {
                    result.id = .line_comment;
                    if (c == '\n') {
                        self.at_start_of_line = true;
                        break;
                    }
                },
                .literal => {
                    switch (c) {
                        '0'...'9' => {
                            self.error_token = .{
                                .id = .number,
                                .start = self.pos,
                                .end = self.pos + 1,
                                .line_number = self.line_number,
                            };
                            return Error.InvalidDigitInLiteral;
                        },
                        '\n' => {
                            self.at_start_of_line = true;
                            break;
                        },
                        ' ', '\t', '\x05'...'\x08', '\x0B'...'\x0C', '\x0E'...'\x1F' => {
                            break;
                        },
                        else => {},
                    }
                },
                .number_literal => {
                    switch (c) {
                        '\n' => {
                            self.at_start_of_line = true;
                            result.id = .number;
                            break;
                        },
                        ' ', '\t', '\x05'...'\x08', '\x0B'...'\x0C', '\x0E'...'\x1F' => {
                            result.id = .number;
                            break;
                        },
                        'x' => {
                            if (self.buffer[self.pos - 1] != '0') {
                                self.error_token = .{
                                    .id = .number,
                                    .start = self.pos,
                                    .end = self.pos + 1,
                                    .line_number = self.line_number,
                                };
                                return Error.InvalidCharacterInNumberLiteral;
                            }
                            state = .byte_literal;
                        },
                        '0'...'9' => {},
                        else => {
                            self.error_token = .{
                                .id = .number,
                                .start = self.pos,
                                .end = self.pos + 1,
                                .line_number = self.line_number,
                            };
                            return Error.InvalidCharacterInNumberLiteral;
                        },
                    }
                },
                .byte_literal => {
                    switch (c) {
                        'A'...'F', '0'...'9' => state = .first_nibble,
                        else => {
                            self.error_token = .{
                                .id = .byte,
                                .start = self.pos,
                                .end = self.pos + 1,
                                .line_number = self.line_number,
                            };
                            return Error.InvalidCharacterInByteLiteral;
                        },
                    }
                },
                .first_nibble => {
                    switch (c) {
                        'A'...'F', '0'...'9' => state = .second_nibble,
                        else => {
                            self.error_token = .{
                                .id = .byte,
                                .start = self.pos,
                                .end = self.pos + 1,
                                .line_number = self.line_number,
                            };
                            return Error.InvalidCharacterInByteLiteral;
                        },
                    }
                },
                .second_nibble => {
                    switch (c) {
                        '\n' => {
                            result.id = .byte;
                            self.at_start_of_line = true;
                            break;
                        },
                        ' ', '\t', '\x05'...'\x08', '\x0B'...'\x0C', '\x0E'...'\x1F' => {
                            result.id = .byte;
                            break;
                        },
                        else => {
                            self.error_token = .{
                                .id = .byte,
                                .start = self.pos,
                                .end = self.pos + 1,
                                .line_number = self.line_number,
                            };
                            return Error.InvalidCharacterInByteLiteral;
                        },
                    }
                },
                .quoted_ascii_string => {
                    switch (c) {
                        '"' => {
                            result.id = .quoted_ascii_string;
                            self.pos += 1;
                            break;
                        },
                        '\n' => {
                            self.error_token = .{
                                .id = .quoted_ascii_string,
                                .start = result.start,
                                .end = self.pos + 1,
                                .line_number = self.line_number,
                            };
                            return Error.UnterminatedQuotedAsciiString;
                        },
                        else => {},
                    }
                },
            }
        } else { // EOF
            switch (state) {
                .start => {},
                .line_comment => result.id = .line_comment,
                .number_literal => result.id = .number,
                .literal => result.id = .literal,
                .quoted_ascii_string => {
                    self.error_token = .{
                        .id = .quoted_ascii_string,
                        .start = result.start,
                        .end = self.pos,
                        .line_number = self.line_number,
                    };
                    return Error.UnterminatedQuotedAsciiString;
                },
                .byte_literal, .first_nibble => {},
                .second_nibble => result.id = .byte,
                .single_quote, .single_quote_forward_slash => {
                    self.error_token = .{
                        .id = .quoted_ascii_string,
                        .start = result.start,
                        .end = self.pos,
                        .line_number = self.line_number,
                    };
                    return Error.InvalidCommentLiteral;
                },
            }
        }

        result.end = self.pos;

        return result;
    }
};
