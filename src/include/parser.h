#ifndef PARSER_H
#define PARSER_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include "lexer.h"
#include "types.h"
#include "keywords.h"
#include "exprs.h"
#include "stmnts.h"

typedef struct Parser {
    Arr(Token) tokens;
    bool in_func_decl_args;
    bool in_enum_decl;

    const char *filename;
    Arr(Cursor) cursors;
    long cursors_idx;
} Parser;

Expr parse_expr(Parser *parser);
Expr parse_array_index(Parser *parser, Expr expr);
Expr parse_field_access(Parser *parser, Expr expr);
Parser parser_init(Lexer lex, const char *filename);
Stmnt parser_parse(Parser *parser);

#endif // PARSER_H
