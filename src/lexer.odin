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
    try_append :: proc(cursor: ^[dynamic][2]u32, col, row: ^u32, tokens: ^[dynamic]Token, buf: ^strings.Builder, extra_token: Token = nil) {
        if len(buf.buf) > 0 {
            append(cursor, [2]u32{row^, col^})
            string_buf := strings.to_string(buf^)
            if _, ok := strconv.parse_u64(string_buf); ok {
                append(tokens, TokenIntLit{strings.clone(string_buf)})
            } if _, ok := strconv.parse_f64(string_buf); ok {
                append(tokens, TokenFloatLit{strings.clone(string_buf)})
            } else {
                append(tokens, TokenIdent{strings.clone(string_buf)})
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

    for ch, i in source {
        if ignore_index != -1 && i == ignore_index {
            ignore_index = -1
            continue
        }

        if ch == '\n' && in_single_line_comment {
            in_single_line_comment = false
            continue
        } else if in_single_line_comment {
            continue
        }

        if ch == '*' && source[i + 1] == '/' && in_block_comment {
            ignore_index = i + 1
            in_block_comment = false
            continue
        } else if in_block_comment {
            continue
        }

        switch ch {
        case ' ', '\r', '\n', '\t':
            if ch == '\r' {
                continue
            }

            try_append(&cursor, &col, &row, &tokens, &buf)
            if ch == '\n' {
                row += 1
                col = 1
            } else {
                col += 1
            }
        case '.':
            string_buf := strings.to_string(buf)
            if _, ok := strconv.parse_u64(string_buf); ok {
                append(&buf.buf, cast(u8)ch)
                col += 1
            } else {
                try_append(&cursor, &col, &row, &tokens, &buf, TokenDot{})
            }
        case ':':
            try_append(&cursor, &col, &row, &tokens, &buf, TokenColon{})
        case '(':
            try_append(&cursor, &col, &row, &tokens, &buf, TokenLb{})
        case ')':
            try_append(&cursor, &col, &row, &tokens, &buf, TokenRb{})
        case '{':
            try_append(&cursor, &col, &row, &tokens, &buf, TokenLc{})
        case '}':
            try_append(&cursor, &col, &row, &tokens, &buf, TokenRc{})
        case '<':
            try_append(&cursor, &col, &row, &tokens, &buf, TokenLa{})
        case '>':
            try_append(&cursor, &col, &row, &tokens, &buf, TokenRa{})
        case '[':
            try_append(&cursor, &col, &row, &tokens, &buf, TokenLs{})
        case ']':
            try_append(&cursor, &col, &row, &tokens, &buf, TokenRs{})
        case '=':
            try_append(&cursor, &col, &row, &tokens, &buf, TokenEqual{})
        case '!':
            try_append(&cursor, &col, &row, &tokens, &buf, TokenExclaim{})
        case ';':
            try_append(&cursor, &col, &row, &tokens, &buf, TokenSemiColon{})
        case ',':
            try_append(&cursor, &col, &row, &tokens, &buf, TokenComma{})
        case '+':
            try_append(&cursor, &col, &row, &tokens, &buf, TokenPlus{})
        case '-':
            try_append(&cursor, &col, &row, &tokens, &buf, TokenMinus{})
        case '*':
            if '/' == source[i + 1] {
                ignore_index = i + 1
                in_block_comment = false
            } else {
                try_append(&cursor, &col, &row, &tokens, &buf, TokenStar{})
            }
        case '^':
            try_append(&cursor, &col, &row, &tokens, &buf, TokenCaret{})
        case '&':
            try_append(&cursor, &col, &row, &tokens, &buf, TokenAmpersand{})
        case '/':
            if '/' == source[i + 1] {
                ignore_index = i + 1
                in_single_line_comment = true
            } else if '*' == source[i + 1] {
                ignore_index = i + 1
                in_block_comment = true
            } else {
                try_append(&cursor, &col, &row, &tokens, &buf, TokenSlash{})
            }
        case '\\':
            try_append(&cursor, &col, &row, &tokens, &buf, TokenBackSlash{})
        case:
            append(&buf.buf, cast(u8)ch)
            col += 1
        }
    }

    return
}
