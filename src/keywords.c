#include "include/utils.h"
#include "include/keywords.h"

Keyword keyword_map(const char *str) {
    if (streq(str, "fn")) {
        return KwFn;
    } else if (streq(str, "struct")) {
        return KwStruct;
    } else if (streq(str, "enum")) {
        return KwEnum;
    } else if (streq(str, "return")) {
        return KwReturn;
    } else if (streq(str, "continue")) {
        return KwContinue;
    } else if (streq(str, "break")) {
        return KwBreak;
    } else if (streq(str, "true")) {
        return KwTrue;
    } else if (streq(str, "false")) {
        return KwFalse;
    } else if (streq(str, "null")) {
        return KwNull;
    } else if (streq(str, "if")) {
        return KwIf;
    } else if (streq(str, "else")) {
        return KwElse;
    } else if (streq(str, "extern")) {
        return KwExtern;
    } else if (streq(str, "for")) {
        return KwFor;
    } else if (streq(str, "and")) {
        return KwAnd;
    } else if (streq(str, "or")) {
        return KwFor;
    } else if (streq(str, "defer")) {
        return KwDefer;
    } else if (streq(str, "cast")) {
        return KwCast;
    } else if (streq(str, "sizeof")) {
        return KwSizeof;
    }

    return KwNone;
}

const char *keyword_stringify(Keyword k) {
    switch (k) {
        case KwNull: return "Null";
        case KwFalse: return "False";
        case KwTrue: return "True";
        case KwFn: return "Fn";
        case KwStruct: return "Struct";
        case KwEnum: return "Enum";
        case KwIf: return "If";
        case KwElse: return "Else";
        case KwFor: return "For";
        case KwBreak: return "Break";
        case KwContinue: return "Continue";
        case KwReturn: return "Return";
        case KwExtern: return "Extern";
        case KwNone: return "None";
        case KwAnd: return "And";
        case KwOr: return "Or";
        case KwDefer: return "Defer";
        case KwCast: return "Cast";
        case KwSizeof: return "Sizeof";
    }

    return "";
}

