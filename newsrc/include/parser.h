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
    Token *tokens;
    bool in_func_decl_args;
    bool in_enum_decl;

    // debug
    const char *filename;
    Cursor *cursors; // vec(uint32_t[2])
    long cursors_idx;
} Parser;


Token peek(Parser *parser);
Token next(Parser *parser);
Token expect(Parser *parser, TokenKind expected);
Expr parse_expr(Parser *parser);
Expr parse_array_index(Parser *parser, Expr expr);
Expr parse_field_access(Parser *parser, Expr expr);
Parser parser_init(Lexer lex, const char *filename);
Stmnt parse(Parser *parser);

#endif // PARSER_H
