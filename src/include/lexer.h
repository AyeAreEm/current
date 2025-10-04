#ifndef LEXER_H
#define LEXER_H

#include <stdint.h>
#include "stb_ds.h"
#include "strb.h"

typedef enum TokenKind {
    TokIdent,
    TokIntLit,
    TokFloatLit,
    TokCharLit,
    TokStrLit,
    TokDirective,

    TokColon,
    TokSemiColon,

    TokEqual,
    TokLeftAngle,
    TokRightAngle,

    TokLeftBracket,
    TokRightBracket,

    TokLeftCurl,
    TokRightCurl,

    TokLeftSquare,
    TokRightSquare,

    TokComma,
    TokDot,
    TokCaret,

    TokPlus,
    TokMinus,
    TokStar,
    TokSlash,
    TokPercent,
    TokBackSlash,

    TokBar,
    TokAmpersand,
    TokExclaim,

    TokUnderscore,

    TokQuestion,

    TokNone,
} TokenKind;
const char *tokenkind_stringify(TokenKind kind);

typedef struct Token {
    TokenKind kind;
    union {
        const char *ident;
        uint64_t intlit;
        uint64_t floatlit;
        char charlit;
        const char *strlit;
        const char *directive;
    };
} Token;

Token token_none(void);
Token token_ident(const char *s);
Token token_intlit(uint64_t n);
Token token_floatlit(double n);
Token token_charlit(char s);
Token token_strlit(const char *s);
Token token_directive(const char *s);
void print_tokens(Token *tokens);

// returns strb, needs to be freed
strb token_stringify(Token tok);

typedef struct Cursor {
    uint32_t row;
    uint32_t col;
} Cursor;

typedef struct Lexer {
    Arr(Token) tokens;
    Arr(Cursor) cursors;
} Lexer;

Lexer lexer(const char *source);
#endif // LEXER_H
