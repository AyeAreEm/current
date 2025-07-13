#include "include/stb_ds.h"
#include "include/lexer.h"
#include "include/utils.h"

#define BUF_CAP 255

Token token_none() {
    return (Token){.kind = TkNone};
}
Token token_ident(const char *s) {
    return (Token){.kind = TkIdent, .ident = s};
}
Token token_intlit(uint64_t n) {
    return (Token){.kind = TkIntLit, .intlit = n};
}
Token token_floatlit(double n) {
    return (Token){.kind = TkFloatLit, .floatlit = n};
}
Token token_charlit(char s) {
    return (Token){.kind = TkCharLit, .charlit = s};
}
Token token_strlit(const char *s) {
    return (Token){.kind = TkStrLit, .strlit = s};
}
Token token_directive(const char *s) {
    return (Token){.kind = TkDirective, .directive = s};
}

void print_tokens(Token *tokens) {
    for (size_t i = 0; i < arrlen(tokens); i++) {
        Token tok = tokens[i];
        switch (tok.kind) {
            case TkIdent:
            {
                printfln("Ident(\"%s\")", tok.ident);
            } break;
            case TkIntLit:
            {
                printfln("IntLit(%lu)", tok.intlit);
            } break;
            case TkFloatLit:
            {
                printfln("IntLit(%f)", (double)tok.floatlit);
            } break;
            case TkCharLit:
            {
                printfln("CharLit(%c)", tok.charlit);
            } break;
            case TkStrLit:
            {
                printfln("StrLit(\"%s\")", tok.strlit);
            } break;
            case TkDirective:
            {
                printfln("Directive(\"%s\")", tok.directive);
            } break;
            case TkColon:
            {
                printfln("Colon");
            } break;
            case TkSemiColon:
            {
                printfln("SemiColon");
            } break;
            case TkEqual:
            {
                printfln("Equal");
            } break;
            case TkLeftAngle:
            {
                printfln("LeftAngle");
            } break;
            case TkRightAngle:
            {
                printfln("RightAngle");
            } break;
            case TkLeftBracket:
            {
                printfln("LeftBracket");
            } break;
            case TkRightBracket:
            {
                printfln("RightBracket");
            } break;
            case TkLeftCurl:
            {
                printfln("LeftCurl");
            } break;
            case TkRightCurl:
            {
                printfln("RightCurl");
            } break;
            case TkLeftSquare:
            {
                printfln("LeftSquare");
            } break;
            case TkRightSquare:
            {
                printfln("RightSquare");
            } break;
            case TkComma:
            {
                printfln("Comma");
            } break;
            case TkDot:
            {
                printfln("Dot");
            } break;
            case TkCaret:
            {
                printfln("Caret");
            } break;
            case TkPlus:
            {
                printfln("Plus");
            } break;
            case TkMinus:
            {
                printfln("Minus");
            } break;
            case TkStar:
            {
                printfln("Star");
            } break;
            case TkSlash:
            {
                printfln("Slash");
            } break;
            case TkBackSlash:
            {
                printfln("BackSlash");
            } break;
            case TkAmpersand:
            {
                printfln("Ampersand");
            } break;
            case TkExclaim:
            {
                printfln("Exclaim");
            } break;
            case TkUnderscore:
            {
                printfln("Underscore");
            } break;
            case TkQuestion:
            {
                printfln("Question");
            } break;
            case TkNone:
            {
                printfln("None");
            } break;
        }
    }
}

static void move_cursor(const char ch, uint32_t *row, uint32_t *col) {
    if (ch == '\n') {
        *row += 1;
        *col = 1;
    } else {
        *col += 1;
    }
}

static int resolve_buffer(Lexer *lex, char *buf, uint32_t *row, uint32_t *col, bool *is_directive) {
    if (strlen(buf) > 0) {
        uint32_t cursor[2] = {*row, *col};
        arrpush(lex->cursors, cursor);

        Token tok;
        uint64_t u64 = 0;
        double f64 = 0;

        if (strcmp(buf, "_") == 0) {
            tok = (Token){ .kind = TkUnderscore };
        } else if (parse_u64(buf, &u64)) {
            tok = token_intlit(u64);
        }  else if (parse_f64(buf, &f64)) {
            tok = token_floatlit(f64);
        } else if (*is_directive) {
            tok = token_directive(strclone(buf));
            *is_directive = false;
        } else {
            tok = token_ident(strclone(buf));
        }
        arrpush(lex->tokens, tok);
    }

    strclear(buf, NULL);
    return 0;
}

static void push_token(Lexer *lex, Token tok, uint32_t *row, uint32_t *col) {
    *col += 1;
    uint32_t cursor[2] = {*row, *col};
    arrpush(lex->cursors, cursor);
    arrpush(lex->tokens, tok);
}

Lexer lexer(const char *source) {
    Lexer lex = {
        .tokens = NULL,
        .cursors = NULL,
    };

    size_t buf_len = 0;
    char buf[BUF_CAP] = {0};

    uint32_t row = 1, col = 1;

    int ignore_index = -1;
    bool in_single_line_comment = false;
    bool in_block_comment = false;
    bool in_quotes = false;
    bool in_double_quotes = false;
    bool is_directive = false;

    for (size_t i = 0; i < strlen(source); i++) {
        const char ch = source[i];

        if (ignore_index != -1 && i == ignore_index)  {
            ignore_index = -1;
            move_cursor(ch, &row, &col);
            continue;
        }

        if (in_single_line_comment) {
            move_cursor(ch, &row, &col);
            if (ch == '\n') in_single_line_comment = false;
            continue;
        }

        if (in_block_comment && ch == '*' && AT(source, strlen(source), i + 1) == '/') {
            ignore_index = i + 1;
            in_block_comment = false;
            col += 1;
            continue;
        } else if (in_block_comment) {
            move_cursor(ch, &row, &col);
            continue;
        }

        if (in_quotes && ch != '\'') {
            STRPUSH(buf, BUF_CAP, buf_len, ch);
            move_cursor(ch, &row, &col);
            continue;
        }

        if (in_double_quotes && ch != '"') {
            STRPUSH(buf, BUF_CAP, buf_len, ch);
            move_cursor(ch, &row, &col);
            continue;
        }

        switch (ch) {
            case ' ':
            case '\r':
            case '\t':
            case '\n':
            {
                if (ch == '\r') continue;
                buf_len = resolve_buffer(&lex, buf, &row, &col, &is_directive);
                move_cursor(ch, &row, &col);
            } break;
            case '#':
            {
                buf_len = resolve_buffer(&lex, buf, &row, &col, &is_directive);
                is_directive = true;
                col += 1;
            } break;
            case '\'':
            {
                // TODO: handle escaped '
                if (in_quotes) {
                    in_quotes = false;
                    uint32_t cursor[2] = {row, col};
                    arrpush(lex.cursors, cursor);
                    arrpush(lex.tokens, token_charlit(buf[0]));
                    strclear(buf, &buf_len);
                } else {
                    resolve_buffer(&lex, buf, &row, &col, &is_directive);
                    in_quotes = true;
                    col += 1;
                }
            } break;
            case '"':
            {
                // TODO: handle escaped "
                if (in_double_quotes) {
                    in_double_quotes = false;
                    uint32_t cursor[2] = {row, col};
                    arrpush(lex.cursors, cursor);
                    arrpush(lex.tokens, token_strlit(strclone(buf)));
                    strclear(buf, &buf_len);
                } else {
                    resolve_buffer(&lex, buf, &row, &col, &is_directive);
                    in_double_quotes = true;
                    col += 1;
                }
            } break;
            case '.':
            {
                uint64_t u64 = 0;
                if (parse_u64(buf, &u64)) {
                    PUSH(buf, BUF_CAP, buf_len, ch);
                    col += 1;
                } else {
                    resolve_buffer(&lex, buf, &row, &col, &is_directive);
                    push_token(&lex, (Token){.kind = TkDot}, &row, &col);
                }
            } break;
            case '?':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TkQuestion}, &row, &col);
            } break;
            case ':':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TkColon}, &row, &col);
            } break;
            case '(':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TkLeftBracket}, &row, &col);
            } break;
            case ')':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TkRightBracket}, &row, &col);
            } break;
            case '{':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TkLeftCurl}, &row, &col);
            } break;
            case '}':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TkRightCurl}, &row, &col);
            } break;
            case '<':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TkLeftAngle}, &row, &col);
            } break;
            case '>':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TkRightAngle}, &row, &col);
            } break;
            case '[':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TkLeftSquare}, &row, &col);
            } break;
            case ']':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TkRightSquare}, &row, &col);
            } break;
            case '=':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TkEqual}, &row, &col);
            } break;
            case '!':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TkExclaim}, &row, &col);
            } break;
            case ';':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TkSemiColon}, &row, &col);
            } break;
            case ',':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TkComma}, &row, &col);
            } break;
            case '+':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TkPlus}, &row, &col);
            } break;
            case '-':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TkMinus}, &row, &col);
            } break;
            case '*':
            {
                if (AT(source, strlen(source), i + 1) == '/') {
                    ignore_index = i + 1;
                    in_block_comment = false;
                    col += 1;
                } else {
                    resolve_buffer(&lex, buf, &row, &col, &is_directive);
                    push_token(&lex, (Token){.kind = TkStar}, &row, &col);
                }
            } break;
            case '^':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TkCaret}, &row, &col);
            } break;
            case '&':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TkAmpersand}, &row, &col);
            } break;
            case '/':
            {
                char next = AT(source, strlen(source), i + 1);
                if (next == '/') {
                    ignore_index = i + 1;
                    in_single_line_comment = true;
                    col += 1;
                } else if (next == '*') {
                    ignore_index = i + 1;
                    in_block_comment = true;
                } else {
                    resolve_buffer(&lex, buf, &row, &col, &is_directive);
                    push_token(&lex, (Token){.kind = TkSlash}, &row, &col);
                }
            } break;
            case '\\':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TkBackSlash}, &row, &col);
            } break;
            default:
            {
                STRPUSH(buf, BUF_CAP, buf_len, ch);
                col += 1;
            } break;
        }
    }

    return lex;
}
