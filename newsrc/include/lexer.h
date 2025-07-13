#ifndef LEXER_H
#define LEXER_H

#include <stdint.h>

typedef enum TokenKind {
    TkIdent,
    TkIntLit,
    TkFloatLit,
    TkCharLit,
    TkStrLit,
    TkDirective,

    TkColon,
    TkSemiColon,

    TkEqual,
    TkLeftAngle,
    TkRightAngle,

    TkLeftBracket,
    TkRightBracket,

    TkLeftCurl,
    TkRightCurl,

    TkLeftSquare,
    TkRightSquare,

    TkComma,
    TkDot,
    TkCaret,

    TkPlus,
    TkMinus,
    TkStar,
    TkSlash,
    TkBackSlash,

    TkAmpersand,
    TkExclaim,

    TkUnderscore,

    TkQuestion,

    TkNone,
} TokenKind;

typedef struct TokenIdent {
    const char *ident;
} TokenIdent;

typedef struct TokenIntLit {
    uint64_t literal;
} TokenIntLit;

typedef TokenIntLit TokenFloatLit;

typedef struct TokenCharLit {
    char literal;
} TokenCharLit;

typedef struct TokenStrLit {
    const char *literal;
} TokenStrLit;

// #<literal>
typedef TokenStrLit TokenDirective;

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

Token token_none();
Token token_ident(const char *s);
Token token_intlit(uint64_t n);
Token token_floatlit(double n);
Token token_charlit(char s);
Token token_strlit(const char *s);
Token token_directive(const char *s);
void print_tokens(Token *tokens);

typedef struct Lexer {
    Token *tokens;
    uint32_t **cursors; // vec(uint32_t[2])
} Lexer;

Lexer lexer(const char *source);
#endif // LEXER_H
