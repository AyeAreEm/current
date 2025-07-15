#include "include/stb_ds.h"
#include "include/lexer.h"
#include "include/utils.h"

#define BUF_CAP 255

Token token_none() {
    return (Token){.kind = TokNone};
}
Token token_ident(const char *s) {
    return (Token){.kind = TokIdent, .ident = s};
}
Token token_intlit(uint64_t n) {
    return (Token){.kind = TokIntLit, .intlit = n};
}
Token token_floatlit(double n) {
    return (Token){.kind = TokFloatLit, .floatlit = n};
}
Token token_charlit(char s) {
    return (Token){.kind = TokCharLit, .charlit = s};
}
Token token_strlit(const char *s) {
    return (Token){.kind = TokStrLit, .strlit = s};
}
Token token_directive(const char *s) {
    return (Token){.kind = TokDirective, .directive = s};
}

const char *tokenkind_stringify(TokenKind kind) {
    switch (kind) {
        case TokIdent: return "Ident";
        case TokIntLit: return "IntLit";
        case TokFloatLit: return "FloatLit";
        case TokCharLit: return "CharLit";
        case TokStrLit: return "StrLit";
        case TokDirective: return "Directive";
        case TokColon: return "':'";
        case TokSemiColon: return "';'";
        case TokEqual: return "'='";
        case TokLeftAngle: return "'<'";
        case TokRightAngle: return "'>'";
        case TokLeftBracket: return "'('";
        case TokRightBracket: return "')'";
        case TokLeftCurl: return "'{'";
        case TokRightCurl: return "'}'";
        case TokLeftSquare: return "'['";
        case TokRightSquare: return "']'";
        case TokComma: return "','";
        case TokDot: return "'.'";
        case TokCaret: return "'^'";
        case TokPlus: return "'+'";
        case TokMinus: return "'-'";
        case TokStar: return "'*'";
        case TokSlash: return "'/'";
        case TokBackSlash: return "'\\'";
        case TokAmpersand: return "'&'";
        case TokExclaim: return "'!'";
        case TokUnderscore: return "'_'";
        case TokQuestion: return "'?'";
        case TokNone: return "";
    }

    return "";
}

void print_tokens(Token *tokens) {
    for (size_t i = 0; i < arrlen(tokens); i++) {
        Token tok = tokens[i];
        switch (tok.kind) {
            case TokIdent:
            {
                printfln("Ident(\"%s\")", tok.ident);
            } break;
            case TokIntLit:
            {
                printfln("IntLit(%lu)", tok.intlit);
            } break;
            case TokFloatLit:
            {
                printfln("FloatLit(%f)", (double)tok.floatlit);
            } break;
            case TokCharLit:
            {
                printfln("CharLit(%c)", tok.charlit);
            } break;
            case TokStrLit:
            {
                printfln("StrLit(\"%s\")", tok.strlit);
            } break;
            case TokDirective:
            {
                printfln("Directive(\"%s\")", tok.directive);
            } break;
            case TokColon:
            {
                printfln("Colon");
            } break;
            case TokSemiColon:
            {
                printfln("SemiColon");
            } break;
            case TokEqual:
            {
                printfln("Equal");
            } break;
            case TokLeftAngle:
            {
                printfln("LeftAngle");
            } break;
            case TokRightAngle:
            {
                printfln("RightAngle");
            } break;
            case TokLeftBracket:
            {
                printfln("LeftBracket");
            } break;
            case TokRightBracket:
            {
                printfln("RightBracket");
            } break;
            case TokLeftCurl:
            {
                printfln("LeftCurl");
            } break;
            case TokRightCurl:
            {
                printfln("RightCurl");
            } break;
            case TokLeftSquare:
            {
                printfln("LeftSquare");
            } break;
            case TokRightSquare:
            {
                printfln("RightSquare");
            } break;
            case TokComma:
            {
                printfln("Comma");
            } break;
            case TokDot:
            {
                printfln("Dot");
            } break;
            case TokCaret:
            {
                printfln("Caret");
            } break;
            case TokPlus:
            {
                printfln("Plus");
            } break;
            case TokMinus:
            {
                printfln("Minus");
            } break;
            case TokStar:
            {
                printfln("Star");
            } break;
            case TokSlash:
            {
                printfln("Slash");
            } break;
            case TokBackSlash:
            {
                printfln("BackSlash");
            } break;
            case TokAmpersand:
            {
                printfln("Ampersand");
            } break;
            case TokExclaim:
            {
                printfln("Exclaim");
            } break;
            case TokUnderscore:
            {
                printfln("Underscore");
            } break;
            case TokQuestion:
            {
                printfln("Question");
            } break;
            case TokNone:
            {
                printfln("None");
            } break;
        }
    }
}

static Cursor cursor(uint32_t row, uint32_t col) {
    return (Cursor){row, col};
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
        arrpush(lex->cursors, cursor(*row, *col));

        Token tok;
        uint64_t u64 = 0;
        double f64 = 0;

        if (streq(buf, "_")) {
            tok = (Token){ .kind = TokUnderscore };
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
    arrpush(lex->cursors, cursor(*row, *col));
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
                    arrpush(lex.cursors, cursor(row, col));
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
                    arrpush(lex.cursors, cursor(row, col));
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
                    push_token(&lex, (Token){.kind = TokDot}, &row, &col);
                }
            } break;
            case '?':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TokQuestion}, &row, &col);
            } break;
            case ':':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TokColon}, &row, &col);
            } break;
            case '(':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TokLeftBracket}, &row, &col);
            } break;
            case ')':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TokRightBracket}, &row, &col);
            } break;
            case '{':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TokLeftCurl}, &row, &col);
            } break;
            case '}':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TokRightCurl}, &row, &col);
            } break;
            case '<':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TokLeftAngle}, &row, &col);
            } break;
            case '>':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TokRightAngle}, &row, &col);
            } break;
            case '[':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TokLeftSquare}, &row, &col);
            } break;
            case ']':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TokRightSquare}, &row, &col);
            } break;
            case '=':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TokEqual}, &row, &col);
            } break;
            case '!':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TokExclaim}, &row, &col);
            } break;
            case ';':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TokSemiColon}, &row, &col);
            } break;
            case ',':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TokComma}, &row, &col);
            } break;
            case '+':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TokPlus}, &row, &col);
            } break;
            case '-':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TokMinus}, &row, &col);
            } break;
            case '*':
            {
                if (AT(source, strlen(source), i + 1) == '/') {
                    ignore_index = i + 1;
                    in_block_comment = false;
                    col += 1;
                } else {
                    resolve_buffer(&lex, buf, &row, &col, &is_directive);
                    push_token(&lex, (Token){.kind = TokStar}, &row, &col);
                }
            } break;
            case '^':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TokCaret}, &row, &col);
            } break;
            case '&':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TokAmpersand}, &row, &col);
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
                    push_token(&lex, (Token){.kind = TokSlash}, &row, &col);
                }
            } break;
            case '\\':
            {
                resolve_buffer(&lex, buf, &row, &col, &is_directive);
                push_token(&lex, (Token){.kind = TokBackSlash}, &row, &col);
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
