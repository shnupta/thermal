pub const Token = struct {
    // TODO: Use these in the way the zig tokenizer does
    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    pub const Tag = enum {
        invalid,
        eof,
        number,
        hex_byte,
        quoted_ascii_string,
        line_comment,
        keyword_esc,
        keyword_ff,
        keyword_lf,
        keyword_cr,
        keyword_ht,
        keyword_can,
        keyword_fs,
        keyword_gs,
    };
};
