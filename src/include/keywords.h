#ifndef KEYWORDS_H
#define KEYWORDS_H

typedef enum Keyword {
    KwNone,
    KwFn,
    KwStruct,
    KwEnum,
    KwReturn,
    KwContinue,
    KwBreak,
    KwTrue,
    KwFalse,
    KwNull,
    KwIf,
    KwElse,
    KwExtern,
    KwFor,
    KwAnd,
    KwOr,
    KwDefer,
    KwCast,
    KwSizeof,
} Keyword;

Keyword keyword_map(const char *str);
const char *keyword_stringify(Keyword k);
#endif // KEYWORDS_H
