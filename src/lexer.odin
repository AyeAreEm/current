package main

import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:os"

TokenIdent :: struct {
    ident: string,
}
TokenIntLit :: struct {
    literal: string,
}
TokenFloatLit :: struct {
    literal: string,
}
TokenCharLit :: struct {
    literal: string,
}
TokenStrLit :: struct {
    literal: string,
}

// #<literal>
TokenDirective :: struct {
    literal: string,
}

TokenColon :: struct {}
TokenSemiColon :: struct {}

TokenEqual :: struct {}
TokenLa :: struct {} // left angle
TokenRa :: struct {} // right angle

TokenLb :: struct {} // left bracket
TokenRb :: struct {} // right bracket

TokenLc :: struct {} // left curl
TokenRc :: struct {} // right curl

TokenLs :: struct {} // left square
TokenRs :: struct {} // right square

TokenComma :: struct {}
TokenDot :: struct {}
TokenCaret :: struct {}

TokenPlus :: struct {}
TokenMinus :: struct {}
TokenStar :: struct {}
TokenSlash :: struct {}
TokenBackSlash :: struct {}

TokenAmpersand :: struct {}
TokenExclaim :: struct {}

Token :: union {
    TokenIdent,
    TokenIntLit,
    TokenFloatLit,
    TokenCharLit,
    TokenStrLit,

    TokenDirective,

    TokenColon,
    TokenSemiColon,

    TokenEqual,
    TokenLa,
    TokenRa,

    TokenLb,
    TokenRb,

    TokenLc,
    TokenRc,

    TokenLs,
    TokenRs,

    TokenComma,
    TokenDot,
    TokenCaret,

    TokenPlus,
    TokenMinus,
    TokenStar,
    TokenSlash,
    TokenBackSlash,

    TokenAmpersand,
    TokenExclaim,
}

token_peek :: proc(self: ^Parser) -> Token {
    if len(self.tokens) == 0 {
        return nil
    }

    return self.tokens[0]
}

token_next :: proc(self: ^Parser) -> Token {
    if len(self.tokens) == 0 {
        return nil
    }
    self.cursors_idx += 1
    return pop_front(&self.tokens)
}

token_tag_equal :: proc(lhs, rhs: Token) -> bool {
    switch _ in lhs {
    case TokenStrLit:
        _, ok := rhs.(TokenStrLit)
        return ok
    case TokenDirective:
        _, ok := rhs.(TokenDirective)
        return ok
    case TokenCharLit:
        _, ok := rhs.(TokenCharLit)
        return ok
    case TokenFloatLit:
        _, ok := rhs.(TokenFloatLit)
        return ok
    case TokenCaret:
        _, ok := rhs.(TokenCaret)
        return ok
    case TokenDot:
        _, ok := rhs.(TokenDot)
        return ok
    case TokenAmpersand:
        _, ok := rhs.(TokenAmpersand)
        return ok
    case TokenLs:
        _, ok := rhs.(TokenLs)
        return ok
    case TokenRs:
        _, ok := rhs.(TokenRs)
        return ok
    case TokenLa:
        _, ok := rhs.(TokenLa)
        return ok
    case TokenRa:
        _, ok := rhs.(TokenRa)
        return ok
    case TokenExclaim:
        _, ok := rhs.(TokenExclaim)
        return ok
    case TokenPlus:
        _, ok := rhs.(TokenPlus)
        return ok
    case TokenMinus:
        _, ok := rhs.(TokenMinus)
        return ok
    case TokenStar:
        _, ok := rhs.(TokenStar)
        return ok
    case TokenSlash:
        _, ok := rhs.(TokenSlash)
        return ok
    case TokenBackSlash:
        _, ok := rhs.(TokenBackSlash)
        return ok
    case TokenIdent:
        _, ok := rhs.(TokenIdent)
        return ok
    case TokenIntLit:
        _, ok := rhs.(TokenIntLit)
        return ok
    case TokenColon:
        _, ok := rhs.(TokenColon)
        return ok
    case TokenLb:
        _, ok := rhs.(TokenLb)
        return ok
    case TokenRb:
        _, ok := rhs.(TokenRb)
        return ok
    case TokenLc:
        _, ok := rhs.(TokenLc)
        return ok
    case TokenRc:
        _, ok := rhs.(TokenRc)
        return ok
    case TokenEqual:
        _, ok := rhs.(TokenEqual)
        return ok
    case TokenSemiColon:
        _, ok := rhs.(TokenSemiColon)
        return ok
    case TokenComma:
        _, ok := rhs.(TokenComma)
        return ok
    }

    return false
}

token_expect :: proc(self: ^Parser, expected: Token) -> Token {
    if token := token_next(self); token != nil {
        if !token_tag_equal(token, expected) {
            elog(self, self.cursors_idx, "expected token %v, got %v", expected, token)
        }

        return token
    }

    elog(self, self.cursors_idx, "expected token %v when no more tokens left", expected)
}

lexer :: proc(source: string) -> (tokens: [dynamic]Token, cursor: [dynamic][2]u32) {
    try_append :: proc(cursor: ^[dynamic][2]u32, col, row: ^u32, tokens: ^[dynamic]Token, buf: ^strings.Builder, is_directive: ^bool, extra_token: Token = nil) {
        if len(buf.buf) > 0 {
            append(cursor, [2]u32{row^, col^})
            string_buf := strings.to_string(buf^)

            if _, ok := strconv.parse_u64(string_buf); ok {
                append(tokens, TokenIntLit{strings.clone(string_buf)})
            } else if _, ok := strconv.parse_f64(string_buf); ok {
                append(tokens, TokenFloatLit{strings.clone(string_buf)})
            } else {
                if is_directive^ {
                    append(tokens, TokenDirective{strings.clone(string_buf)})
                    is_directive^ = false
                } else {
                    append(tokens, TokenIdent{strings.clone(string_buf)})
                }
            }
        }

        if extra_token != nil {
            col^ += 1
            append(cursor, [2]u32{row^, col^})
            append(tokens, extra_token)
        }

        clear(&buf.buf)
    }

    buf, buf_err := strings.builder_make()
    if buf_err != nil {
        fmt.eprintfln("failed to allocate string builder")
        os.exit(1)
    }
    defer delete(buf.buf)

    row, col: u32 = 1, 1

    ignore_index := -1
    in_single_line_comment := false
    in_block_comment := false
    in_quotes := false
    in_double_quotes := false
    is_directive := false

    for ch, i in source {
        if ignore_index != -1 && i == ignore_index {
            ignore_index = -1
            if ch == '\n' {
                row += 1
                col = 1
            } else {
                col += 1
            }
            continue
        }

        if ch == '\n' && in_single_line_comment {
            in_single_line_comment = false
            row += 1
            col = 1
            continue
        } else if in_single_line_comment {
            if ch == '\n' {
                row += 1
                col = 1
            } else {
                col += 1
            }
            continue
        }

        if ch == '*' && source[i + 1] == '/' && in_block_comment {
            ignore_index = i + 1
            in_block_comment = false
            col += 1
            continue
        } else if in_block_comment {
            if ch == '\n' {
                row += 1
                col = 1
            } else {
                col += 1
            }
            continue
        }

        if in_quotes && ch != '\''{
            append(&buf.buf, cast(u8)ch)
            if ch == '\n' {
                row += 1
                col = 1
            } else {
                col += 1
            }
            continue
        }

        if in_double_quotes && ch != '"' {
            append(&buf.buf, cast(u8)ch)
            if ch == '\n' {
                row += 1
                col = 1
            } else {
                col += 1
            }
            continue
        }

        switch ch {
        case ' ', '\r', '\n', '\t':
            if ch == '\r' {
                continue
            }

            try_append(&cursor, &col, &row, &tokens, &buf, &is_directive)
            if ch == '\n' {
                row += 1
                col = 1
            } else {
                col += 1
            }
        case '#':
            try_append(&cursor, &col, &row, &tokens, &buf, &is_directive)
            is_directive = true
            col += 1
        case '\'':
            // TODO: handle escaped '
            if in_quotes {
                in_quotes = false
                string_buf := strings.to_string(buf)

                append(&cursor, [2]u32{row, col})
                append(&tokens, TokenCharLit{
                    literal = strings.clone(string_buf),
                })
                clear(&buf.buf)
            } else {
                try_append(&cursor, &col, &row, &tokens, &buf, &is_directive)
                in_quotes = true
                col += 1
            }
        case '"':
            // TODO: handle escaped "
            if in_double_quotes {
                in_double_quotes = false
                string_buf := strings.to_string(buf)

                append(&cursor, [2]u32{row, col})
                append(&tokens, TokenStrLit{
                    literal = strings.clone(string_buf),
                })
                clear(&buf.buf)
            } else {
                try_append(&cursor, &col, &row, &tokens, &buf, &is_directive)
                in_double_quotes = true
                col += 1
            }
        case '.':
            string_buf := strings.to_string(buf)
            if _, ok := strconv.parse_u64(string_buf); ok {
                append(&buf.buf, cast(u8)ch)
                col += 1
            } else {
                try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenDot{})
            }
        case ':':
            try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenColon{})
        case '(':
            try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenLb{})
        case ')':
            try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenRb{})
        case '{':
            try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenLc{})
        case '}':
            try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenRc{})
        case '<':
            try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenLa{})
        case '>':
            try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenRa{})
        case '[':
            try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenLs{})
        case ']':
            try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenRs{})
        case '=':
            try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenEqual{})
        case '!':
            try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenExclaim{})
        case ';':
            try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenSemiColon{})
        case ',':
            try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenComma{})
        case '+':
            try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenPlus{})
        case '-':
            try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenMinus{})
        case '*':
            if '/' == source[i + 1] {
                ignore_index = i + 1
                in_block_comment = false
                col += 1
            } else {
                try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenStar{})
            }
        case '^':
            try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenCaret{})
        case '&':
            try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenAmpersand{})
        case '/':
            if '/' == source[i + 1] {
                ignore_index = i + 1
                in_single_line_comment = true
                col += 1
            } else if '*' == source[i + 1] {
                ignore_index = i + 1
                in_block_comment = true
            } else {
                try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenSlash{})
            }
        case '\\':
            try_append(&cursor, &col, &row, &tokens, &buf, &is_directive, TokenBackSlash{})
        case:
            append(&buf.buf, cast(u8)ch)
            col += 1
        }
    }

    return
}
