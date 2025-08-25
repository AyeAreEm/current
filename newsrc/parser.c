#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include "include/exprs.h"
#include "include/keywords.h"
#include "include/parser.h"
#include "include/lexer.h"
#include "include/stmnts.h"
#include "include/strb.h"
#include "include/types.h"
#include "include/utils.h"
#include "include/stb_ds.h"

static void elog(Parser *parser, size_t i, const char *msg, ...) {
    eprintf("%s:%lu:%lu " TERM_RED "error" TERM_END ": ", parser->filename, parser->cursors[i].row, parser->cursors[i].col);

    va_list args;
    va_start(args, msg);

    veprintfln(msg, args);

    va_end(args);
    exit(1);
}

Expr expr_from_keyword(Parser *parser, Keyword kw) {
    switch (kw) {
        case KwTrue:
            return expr_true((size_t)parser->cursors_idx);
        case KwFalse:
            return expr_false((size_t)parser->cursors_idx);
        case KwNull: {
            Type *subtype = ealloc(sizeof(Type)); subtype->kind = TkNone;
            return expr_null(
                type_option(
                    (Option){
                        .is_null = true,
                        .gen_option = false,
                        .subtype = subtype,
                    },
                    TYPECONST,
                    (size_t)parser->cursors_idx
                ),
                (size_t)parser->cursors_idx
            );
        }
        default:
            elog(parser, parser->cursors_idx, "expected an expression, got keyword %s", keyword_stringify(kw));
            return expr_none(); // just to silence warning, elog exits
    }
}

static Directive directive_map(const char *str) {
    if (streq(str, "link")) {
        return (Directive){ .kind = DkLink };
    } else if (streq(str, "syslink")) {
        return (Directive){ .kind = DkSyslink };
    } else if (streq(str, "output")) {
        return (Directive){ .kind = DkOutput };
    } else if (streq(str, "O0")) {
        return (Directive){ .kind = DkO0 };
    } else if (streq(str, "O1")) {
        return (Directive){ .kind = DkO1 };
    } else if (streq(str, "O2")) {
        return (Directive){ .kind = DkO2 };
    } else if (streq(str, "O3")) {
        return (Directive){ .kind = DkO3 };
    } else if (streq(str, "Odebug")) {
        return (Directive){ .kind = DkOdebug };
    } else if (streq(str, "Ofast")) {
        return (Directive){ .kind = DkOfast };
    } else if (streq(str, "Osmall")) {
        return (Directive){ .kind = DkOsmall };
    }

    return (Directive){ .kind = DkNone };
}

Directive parser_get_directive(Parser *parser, const char *word) {
    Directive d = directive_map(word);
    if (d.kind == DkNone) {
        elog(parser, parser->cursors_idx, "\"#%s\" is not a directive", word);
    }
    return d;
}

Parser parser_init(Lexer lex, const char *filename) {
    return (Parser){
        .tokens = lex.tokens,
        .in_func_decl_args = false,
        .in_enum_decl = false,

        .filename = filename,
        .cursors = lex.cursors,
        .cursors_idx = -1,
    };
}

Token peek(Parser *parser) {
    if (arrlen(parser->tokens) == 0) {
        return (Token){.kind = TokNone};
    }

    return parser->tokens[0];
}

Token next(Parser *parser) {
    if (arrlen(parser->tokens) == 0) {
        return (Token){.kind = TokNone};
    }

    parser->cursors_idx += 1;
    Token tok = parser->tokens[0];
    arrdel(parser->tokens, 0);
    return tok;
}

Token expect(Parser *parser, TokenKind expected) {
    Token tok = next(parser);
    if (tok.kind == TokNone) {
        elog(parser, parser->cursors_idx, "expected token %s when no more tokens left", tokenkind_stringify(expected));
    }

    if (tok.kind != expected) {
        elog(parser, parser->cursors_idx, "expected token %s, got %s", tokenkind_stringify(expected), tokenkind_stringify(tok.kind));
    }

    return tok;
}

typedef enum IdentifersKind {
    IkType,
    IkKeyword,
    IkIdent,
} IdentifersKind;

const char *identifierskind_stringify(IdentifersKind i) {
    switch (i) {
        case IkType: return "Type";
        case IkKeyword: return "Keyword";
        case IkIdent: return "Ident";
    }
}

typedef struct Identifiers {
    IdentifersKind kind;

    union {
        Type type;
        Keyword keyword;
        Expr expr;
    };
} Identifiers;

static Identifiers convert_ident(Parser *parser, Token tok) {
    if (tok.kind != TokIdent) elog(parser, parser->cursors_idx, "expected Ident, got %s", tokenkind_stringify(tok.kind));

    Keyword k = keyword_map(tok.ident);
    if (k != KwNone) {
        return (Identifiers){
            .kind = IkKeyword,
            .keyword = k,
        };
    }

    Type t = type_from_string(tok.ident);
    if (t.kind != TkNone) {
        return (Identifiers){
            .kind = IkType,
            .type = t,
        };
    }

    return (Identifiers){
        .kind = IkIdent,
        .expr = expr_ident(tok.ident, type_none(), (size_t)parser->cursors_idx),
    };
}

// expects = already nexted
// <ident> = 
Stmnt parse_var_reassign(Parser *parser, Expr ident, bool expect_semicolon) {
    Expr expr = parse_expr(parser);
    if (expect_semicolon) expect(parser, TokSemiColon);

    return stmnt_varreassign((VarReassign){
        .type = type_none(),
        .name = ident,
        .value = expr,
    }, (size_t)parser->cursors_idx);
}

Expr parse_end_literal(Parser *parser, Type type) {
    Expr lit = expr_literal((Literal){
        .kind = LitkNone,
    }, type, (size_t)parser->cursors_idx);

    bool is_stmnts = false;
    Arr(Expr) exprs = NULL;
    Arr(Stmnt) stmnts = NULL;

    bool first = true;
    while (peek(parser).kind != TokRightCurl) {
        if (first) {
            if (peek(parser).kind == TokDot) {
                // expecting var reassign
                // { .
                next(parser);
                Token tok = expect(parser, TokIdent);
                Identifiers convert = convert_ident(parser, tok);
                if (convert.kind == IkIdent) {
                    expect(parser, TokEqual);
                    Stmnt stmnt = parse_var_reassign(parser, convert.expr, false);
                    arrpush(stmnts, stmnt);

                    is_stmnts = true;
                } else {
                    elog(parser, parser->cursors_idx, "expected identifer in compound literal, got %s", identifierskind_stringify(convert.kind));
                }
            } else {
                Expr expr = parse_expr(parser);
                arrpush(exprs, expr);
            }
            first = false;
            continue;
        }

        expect(parser, TokComma);
        if (peek(parser).kind == TokRightCurl) {
            break;
        }

        if (is_stmnts) {
            expect(parser, TokDot);
            Token tok = expect(parser, TokIdent);
            Identifiers convert = convert_ident(parser, tok);
            if (convert.kind == IkIdent) {
                expect(parser, TokEqual);
                Stmnt stmnt = parse_var_reassign(parser, convert.expr, false);
                arrpush(stmnts, stmnt);
            } else {
                elog(parser, parser->cursors_idx, "expected identifer in compound literal, got %s", identifierskind_stringify(convert.kind));
            }
        } else {
            Expr expr = parse_expr(parser);
            arrpush(exprs, expr);
        }
    }

    if (is_stmnts) {
        lit.literal.kind = LitkVars;
        lit.literal.vars = stmnts;
    } else {
        lit.literal.kind = LitkExprs;
        lit.literal.exprs = exprs;
    }

    expect(parser, TokRightCurl);
    return lit;
}

void parse_set_ptr_type(Parser *parser, Type *ptr, Type type) {
    switch (ptr->kind) {
        case TkPtr: {
            if (ptr->ptr_to->kind == TkNone) {
                *ptr->ptr_to = type;
            } else {
                parse_set_ptr_type(parser, ptr->ptr_to, type);
            }
        } break;
        default: break;
    }
}

void parse_set_array_type(Parser *parser, Type *arr, Type type) {
    switch (arr->kind) {
        case TkArray: {
            if (arr->array.of->kind == TkNone) {
                *arr->array.of = type;
            } else {
                parse_set_array_type(parser, arr->array.of, type);
            }
        } break;
        default: break;
    }
}

Type typedef_from_ident(Expr ident) {
    assert(ident.kind == EkIdent);
    
    return type_typedef(ident.ident, TYPEVAR, ident.cursors_idx);
}

Type parse_type(Parser *parser) {
    Type type = type_none();
    Token tok = peek(parser);

    switch (tok.kind) {
        case TokQuestion: {
            size_t index = (size_t)parser->cursors_idx;

            next(parser);
            Type *subtype = ealloc(sizeof(Type)); *subtype = parse_type(parser);

            type = type_option((Option){
                .subtype = subtype,
                .is_null = false,
                .gen_option = false,
            }, TYPEVAR, index);
        } break;
        case TokStar:
        case TokCaret: {
            Type *of = ealloc(sizeof(Type)); of->kind = TkNone;

            type = type_ptr(
                of,
                TYPECONST ? tok.kind == TokCaret : TYPEVAR,
                (size_t)parser->cursors_idx
            );
            next(parser);

            for (tok = peek(parser); tok.kind != TokNone; tok = peek(parser)) {
                if (tok.kind != TokStar && tok.kind != TokCaret) {
                    break;
                }
                next(parser);

                if (tok.kind == TokStar) {
                    type = type_ptr(&type, TYPEVAR, (size_t)parser->cursors_idx);
                } else if (tok.kind == TokCaret) {
                    type = type_ptr(&type, TYPECONST, (size_t)parser->cursors_idx);
                }
            }

            Type subtype = parse_type(parser);
            parse_set_ptr_type(parser, &type, subtype);
        } break;
        case TokLeftSquare: {
            for (Token leftsquare = peek(parser); leftsquare.kind == TokLeftSquare; leftsquare = peek(parser)) {
                next(parser);
                Token after = peek(parser);

                Type *of = ealloc(sizeof(Type)); of->kind = TkNone;
                Expr *len = ealloc(sizeof(Expr)); 

                if (after.kind == TokIntLit) {
                    *len = parse_expr(parser);
                    expect(parser, TokRightSquare);
                } else if (after.kind == TokUnderscore) {
                    next(parser);
                    expect(parser, TokRightSquare);
                    len->kind = EkNone;
                } else {
                    elog(parser, parser->cursors_idx, "expected an integer or underscore, got %s", tokenkind_stringify(after.kind));
                }

                Type array_type = type_array((Array){
                    .len = len,
                    .of = of,
                }, TYPEVAR, (size_t)parser->cursors_idx);

                if (type.kind == TkArray) {
                    Type *subtype = ealloc(sizeof(Type)); *subtype = array_type;
                    type.array.of = subtype;
                } else if (type.kind == TkNone) {
                    type = array_type;
                }
            }

            Type subtype = parse_type(parser);
            parse_set_array_type(parser, &type, subtype);
        } break;
        case TokIdent: {
            next(parser);
            Identifiers convert = convert_ident(parser, tok);

            if (convert.kind == IkType) {
                type = convert.type;
            } else if (convert.kind == IkKeyword) {
                elog(parser, parser->cursors_idx, "expected a type, got %s", tokenkind_stringify(tok.kind));
            } else {
                type = typedef_from_ident(convert.expr);
            }
        } break;
        default: break;
    }

    return type;
}

Expr parse_primary(Parser *parser) {
    Token tok = peek(parser);

    switch (tok.kind) {
        case TokLeftCurl:
            next(parser);
            return parse_end_literal(parser, type_none());
        case TokLeftSquare: {
            Type type = parse_type(parser);
            tok = peek(parser);
            if (tok.kind == TokLeftCurl) {
                next(parser);
                return parse_end_literal(parser, type);
            } else {
                strb t = string_from_type(type);
                debug("here, %s", t);
                elog(parser, parser->cursors_idx, "unexpected type %s", t);
                // TODO: later when providing more than one error message, uncomment the line below
                // strbfree(t);
            }
        } break;
        case TokIdent: {
            Identifiers convert = convert_ident(parser, tok);
            if (convert.kind == IkIdent) {
                next(parser);
                tok = peek(parser);

                if (tok.kind == TokDot) {
                    // <ident>.
                    next(parser);
                    return parse_field_access(parser, convert.expr);
                } else if (tok.kind == TokLeftSquare) {
                    // <ident>[
                    next(parser);
                    return parse_array_index(parser, convert.expr);
                } else if (tok.kind == TokLeftCurl) {
                    // <ident>{
                    // ident must be a typedef
                    next(parser);
                    Type type = typedef_from_ident(convert.expr);
                    return parse_end_literal(parser, type);
                } else if (streq(convert.expr.ident, "c")) {
                    next(parser);
                    return expr_cstrlit(tok.strlit, (size_t)parser->cursors_idx);
                }

                // <ident>
                return convert.expr;
            } else if (convert.kind == IkKeyword) {
                next(parser);
                return expr_from_keyword(parser, convert.keyword);
            } else if (convert.kind == IkType) {
                Type type = parse_type(parser);
                tok = peek(parser);

                if (tok.kind == TokLeftCurl) {
                    next(parser);
                    return parse_end_literal(parser, type);
                } else {
                    strb t = string_from_type(type);
                    elog(parser, parser->cursors_idx, "unexpected type %s", t);
                    // TODO: later when providing more than one error message, uncomment the line below
                    // strbfree(t);
                }
            } else {
                elog(parser, parser->cursors_idx, "unexpected identifier %s", tok.ident);
            }
        } break;
        case TokIntLit: {
            next(parser);
            return expr_intlit(
                tok.intlit,
                type_integer(
                    TkUntypedInt,
                    TYPECONST,
                    (size_t)parser->cursors_idx
                ),
                (size_t)parser->cursors_idx
            );
        } break;
        case TokFloatLit: {
            next(parser);
            return expr_floatlit(
                tok.floatlit,
                type_decimal(
                    TkUntypedFloat,
                    TYPECONST,
                    (size_t)parser->cursors_idx
                ),
                (size_t)parser->cursors_idx
            );
        } break;
        case TokCharLit: {
            next(parser);
            return expr_charlit(tok.charlit, (size_t)parser->cursors_idx);
        } break;
        case TokStrLit: {
            next(parser);
            return expr_strlit(tok.strlit, (size_t)parser->cursors_idx);
        } break;
        case TokLeftBracket: {
            next(parser);
            size_t index = (size_t)parser->cursors_idx;
            Expr *expr = ealloc(sizeof(Expr)); *expr = parse_expr(parser);
            expect(parser, TokRightBracket);

            return expr_group(expr, type_none(), index);
        } break;
        default:
            elog(parser, parser->cursors_idx, "unexpected token %s", tokenkind_stringify(tok.kind));
    }

    elog(parser, parser->cursors_idx, "unexpected token %s", tokenkind_stringify(tok.kind));
    return expr_none(); // silence warning
}

Expr parse_end_fn_call(Parser *parser, Expr ident) {
    size_t index = (size_t)parser->cursors_idx;
    Arr(Expr) args = NULL;

    Token tok = peek(parser);
    if (tok.kind != TokRightBracket) {
        arrpush(args, parse_expr(parser));
        for (tok = peek(parser); tok.kind == TokComma; tok = peek(parser)) {
            next(parser);
            arrpush(args, parse_expr(parser));
        }
    }

    expect(parser, TokRightBracket);
    Expr *name = ealloc(sizeof(Expr)); *name = ident;
    return expr_fncall((FnCall){
        .name = name,
        .args = args,
    }, type_none(), index);
}

Expr parse_fn_call(Parser *parser, Expr ident) {
    Expr expr = ident;
    if (ident.kind == EkNone) {
        expr = parse_primary(parser);
    }

    while (true) {
        Token tok = peek(parser);
        if (tok.kind == TokLeftBracket) {
            next(parser);
            expr = parse_end_fn_call(parser, expr);
        } else {
            break;
        }
    }

    return expr;
}

Stmnt stmnt_from_fncall(Expr expr) {
    assert(expr.kind == EkFnCall);
    return stmnt_fncall(expr.fncall, expr.cursors_idx);
}

Expr expr_from_fncall(Stmnt stmnt) {
    assert(stmnt.kind == SkFnCall);
    return expr_fncall(stmnt.fncall, type_none(), stmnt.cursors_idx);
}

Expr parse_unary(Parser *parser) {
    Token op = peek(parser);
    size_t index = (size_t)parser->cursors_idx;

    if (op.kind != TokExclaim && op.kind != TokMinus && op.kind != TokAmpersand) {
        return parse_fn_call(parser, expr_none());
    }
    next(parser);

    Expr *right = ealloc(sizeof(Expr)); *right = parse_unary(parser);
    if (op.kind == TokExclaim) {
        return expr_unop((Unop){
            .kind = UkNot,
            .val = right,
        }, type_bool(TYPEVAR, index), index);
    } else if (op.kind == TokMinus) {
        return expr_unop((Unop){
            .kind = UkNegate,
            .val = right,
        }, type_none(), index);
    } else {
        return expr_unop((Unop){
            .kind = UkAddress,
            .val = right,
        }, type_none(), index);
    }
}

Expr parse_factor(Parser *parser) {
    Expr expr = parse_unary(parser);

    for (Token op = peek(parser); op.kind != TokNone; op = peek(parser)) {
        if (op.kind != TokStar && op.kind != TokSlash) {
            break;
        }
        next(parser);

        size_t index = (size_t)parser->cursors_idx;
        Expr *left = ealloc(sizeof(Expr)); *left = expr;
        Expr *right = ealloc(sizeof(Expr)); *right = parse_unary(parser);

        if (op.kind == TokStar) {
            expr = expr_binop((Binop){
                .kind = BkMultiply,
                .left = left,
                .right = right,
            }, type_none(), index);
        } else {
            expr = expr_binop((Binop){
                .kind = BkDivide,
                .left = left,
                .right = right,
            }, type_none(), index);
        }
    }

    return expr;
}

Expr parse_term(Parser *parser) {
    Expr expr = parse_factor(parser);

    for (Token op = peek(parser); op.kind != TokNone;) {
        if (op.kind != TokPlus && op.kind != TokMinus) {
            break;
        }
        next(parser);

        size_t index = (size_t)parser->cursors_idx;
        Expr *left = ealloc(sizeof(Expr)); *left = expr;
        Expr *right = ealloc(sizeof(Expr)); *right = parse_factor(parser);

        if (op.kind == TokPlus) {
            expr = expr_binop((Binop){
                .kind = BkPlus,
                .left = left,
                .right = right,
            }, type_none(), index);
        } else {
            expr = expr_binop((Binop){
                .kind = BkMinus,
                .left = left,
                .right = right,
            }, type_none(), index);
        }
    }

    return expr;
}

Expr parse_comparison(Parser *parser) {
    Expr expr = parse_term(parser);

    for (Token tok = peek(parser); tok.kind != TokNone;) {
        size_t index = (size_t)parser->cursors_idx;
        if (tok.kind != TokLeftAngle && tok.kind != TokRightAngle) {
            break;
        }
        next(parser);

        Expr *left = ealloc(sizeof(Expr)); *left = expr;
        Expr *right = ealloc(sizeof(Expr)); *right = parse_term(parser);

        Token after = peek(parser);
        if (after.kind == TokEqual) {
            next(parser);

            if (tok.kind == TokLeftAngle) {
                expr = expr_binop((Binop){
                    .kind = BkLessEqual,
                    .left = left,
                    .right = right,
                }, type_bool(TYPEVAR, index), index);
            } else {
                expr = expr_binop((Binop){
                    .kind = BkGreaterEqual,
                    .left = left,
                    .right = right,
                }, type_bool(TYPEVAR, index), index);
            }
        } else {
            if (tok.kind == TokLeftAngle) {
                expr = expr_binop((Binop){
                    .kind = BkLess,
                    .left = left,
                    .right = right,
                }, type_bool(TYPEVAR, index), index);
            } else {
                expr = expr_binop((Binop){
                    .kind = BkGreater,
                    .left = left,
                    .right = right,
                }, type_bool(TYPEVAR, index), index);
            }
        }
    }

    return expr;
}

Expr parse_equality(Parser *parser) {
    Expr expr = parse_comparison(parser);

    for (Token tok = peek(parser); tok.kind != TokNone; tok = peek(parser)) {
        size_t index = (size_t)parser->cursors_idx;
        if (tok.kind != TokExclaim && tok.kind != TokEqual) {
            break;
        }
        next(parser);

        Token after = next(parser);
        if (after.kind != TokEqual) {
            break;
        }

        Expr *left = ealloc(sizeof(Expr)); *left = expr;
        Expr *right = ealloc(sizeof(Expr)); *right = parse_comparison(parser);
        if (tok.kind == TokExclaim) {
            expr = expr_binop((Binop){
                .kind = BkInequals,
                .left = left,
                .right = right,
            }, type_bool(TYPEVAR, index), index);
        } else {
            expr = expr_binop((Binop){
                .kind = BkEquals,
                .left = left,
                .right = right,
            }, type_bool(TYPEVAR, index), index);
        }
    }

    return expr;
}

Expr parse_expr(Parser *parser) {
    return parse_equality(parser);
}

// expects [ already nexted
// <expr>[
Expr parse_array_index(Parser *parser, Expr expr) {
    Expr *index = ealloc(sizeof(Expr)); *index = parse_expr(parser);
    expect(parser, TokRightSquare);

    Expr *e = ealloc(sizeof(Expr)); *e = expr;
    Expr arrindex = expr_arrayindex((ArrayIndex){
        .accessing = e,
        .index = index,
    }, type_none(), (size_t)parser->cursors_idx);

    Token tok = peek(parser);
    if (tok.kind == TokDot) {
        next(parser);
        return parse_field_access(parser, arrindex);
    } else if (tok.kind == TokLeftSquare) {
        next(parser);
        return parse_array_index(parser, arrindex);
    }

    return arrindex;
}

// expects '.' already nexted
// <expr>.
Expr parse_field_access(Parser *parser, Expr expr) {
    size_t index = parser->cursors_idx;

    Expr *front = ealloc(sizeof(Expr)); *front = expr;

    // <expr>.&
    Token tok = next(parser);
    if (tok.kind == TokAmpersand) {
        Expr *field = ealloc(sizeof(Expr)); field->kind = EkNone;

        return expr_fieldaccess((FieldAccess){
            .accessing = front,
            .field = field,
            .deref = true,
        }, type_none(), index);
    }

    // <expr>.<ident>
    Identifiers convert = convert_ident(parser, tok);
    if (convert.kind != IkIdent) {
        elog(parser, parser->cursors_idx, "unexpected token %s after field access", tokenkind_stringify(tok.kind));
    }

    Expr *field = ealloc(sizeof(Expr)); *field = convert.expr;

    Expr fa = expr_fieldaccess((FieldAccess){
        .accessing = front,
        .field = field,
        .deref = false,
    }, field->type, index);

    tok = peek(parser);
    if (tok.kind == TokNone) elog(parser, parser->cursors_idx, "expected more tokens");

    if (tok.kind == TokDot) {
        next(parser); // already checked if none
        return parse_field_access(parser, fa);
    } else if (tok.kind == TokLeftSquare) {
        next(parser); // already checked if none
        return parse_array_index(parser, fa);
    }

    return fa;
}

// <expr> [+-*/]=
Stmnt parse_compound_assignment(Parser *parser, Expr expr, Token op, bool expect_semicolon) {
    size_t op_idx = (size_t)parser->cursors_idx;
    Expr *var = ealloc(sizeof(Expr)); *var = expr;
    Expr *val = ealloc(sizeof(Expr)); *val = parse_expr(parser);
    Expr *group = ealloc(sizeof(Expr));
    *group = expr_group(val, type_none(), parser->cursors_idx);

    if (expect_semicolon) expect(parser, TokSemiColon);

    Stmnt reassign = stmnt_varreassign((VarReassign){
        .name = expr,
        .type = type_none(),
        .value = expr_none(),
    }, parser->cursors_idx);

    Expr binop = expr_binop((Binop){
        .kind = 0,
        .left = var,
        .right = group,
    }, type_none(), op_idx);

    if (op.kind == TokPlus) {
        binop.binop.kind = BkPlus;
    } else if (op.kind == TokMinus) {
        binop.binop.kind = BkMinus;
    } else if (op.kind == TokStar) {
        binop.binop.kind = BkMultiply;
    } else if (op.kind == TokSlash) {
        binop.binop.kind = BkMultiply;
    }
    reassign.varreassign.value = binop;

    return reassign;
}

// returns VarReassign if possible, else StmntNone
Stmnt parse_possible_assignment(Parser *parser, Expr expr, bool expect_semicolon) {
    Token tok = peek(parser);
    if (tok.kind == TokNone) return stmnt_none();

    if (tok.kind == TokPlus ||
        tok.kind == TokMinus ||
        tok.kind == TokStar ||
        tok.kind == TokSlash) {
        next(parser);
        Token after = next(parser);

        if (after.kind == TokEqual) {
            return parse_compound_assignment(parser, expr, after, expect_semicolon);
        } else {
            elog(parser, parser->cursors_idx, "unexpected token %s", tokenkind_stringify(after.kind));
        }
    } else if (tok.kind == TokEqual) {
        next(parser);
        return parse_var_reassign(parser, expr, expect_semicolon);
    }

    return stmnt_none();
}

// CAUTION: can return NULL
Stmnt *parse_block(Parser *parser, TokenKind start, TokenKind end) {
    if (start != TokNone) {
        expect(parser, start);
    }

    Arr(Stmnt) block = NULL;

    Token tok = peek(parser);
    if (tok.kind == end && start != TokNone) {
        next(parser);
        return block;
    }

    for (Stmnt stmnt = parser_parse(parser); stmnt.kind != SkNone; stmnt = parser_parse(parser)) {
        arrpush(block, stmnt);

        tok = peek(parser);
        if (tok.kind == end) {
            next(parser);
            break;
        }
    }

    if (arrlen(block) == 0) {
        expect(parser, end);
    }

    return block;
}

Stmnt *parse_block_curls(Parser *parser) {
    return parse_block(parser, TokLeftCurl, TokRightCurl);
}

Stmnt parse_fn_decl(Parser *parser, Expr ident) {
    size_t index = (size_t)parser->cursors_idx;

    parser->in_func_decl_args = true;
    Stmnt *args = parse_block(parser, TokLeftBracket, TokRightBracket);
    parser->in_func_decl_args = false;

    Type type = parse_type(parser);
    if (type.kind == TkNone) elog(parser, parser->cursors_idx, "expected return type in function declaration");
    FnDecl fndecl = {
        .name = ident,
        .args = args,
        .type = type,
    };

    Token tok = peek(parser);
    if (tok.kind == TokLeftCurl) {
        Stmnt *body = parse_block_curls(parser);
        fndecl.body = body;
        fndecl.has_body = true;

        return stmnt_fndecl(fndecl, index);
    } else if (tok.kind == TokSemiColon) {
        next(parser);
        fndecl.body = NULL;
        fndecl.has_body = false;

        return stmnt_fndecl(fndecl, index);
    } else {
        elog(parser, parser->cursors_idx, "expected ';' or '{', got %s", tokenkind_stringify(tok.kind));
    }

    // unreachable, silence warning
    return stmnt_none();
}

Stmnt parse_struct_decl(Parser *parser, Expr ident) {
    size_t index = (size_t)parser->cursors_idx;
    Stmnt *fields = parse_block_curls(parser);

    return stmnt_structdecl((StructDecl){
        .name = ident,
        .fields = fields,
    }, index);
}

Stmnt parse_enum_decl(Parser *parser, Expr ident) {
    size_t index = (size_t)parser->cursors_idx;
    parser->in_enum_decl = true;
    Stmnt *fields = parse_block_curls(parser);
    parser->in_enum_decl = false;

    return stmnt_enumdecl((EnumDecl){
        .name = ident,
        .fields = fields,
    }, index);
}

// <ident> : <type?> :
// type can be none
Stmnt parse_const_decl(Parser *parser, Expr ident, Type type) {
    Token tok = peek(parser);
    if (tok.kind == TokNone) return stmnt_none();

    size_t index = (size_t)parser->cursors_idx;
    if (tok.kind == TokIdent) {
        Identifiers convert = convert_ident(parser, tok);
        if (convert.kind == IkKeyword) {
            switch (convert.keyword) {
                case KwFn:
                    next(parser);
                    return parse_fn_decl(parser, ident);
                case KwStruct:
                    next(parser);
                    return parse_struct_decl(parser, ident);
                case KwEnum:
                    next(parser);
                    return parse_enum_decl(parser, ident);
                case KwTrue:
                case KwFalse:
                case KwNull:
                    break;
                default:
                    elog(parser, index, "unexpected token %s", tokenkind_stringify(tok.kind));
                    break;
            }
        }
    }

    // <ident>: <type,
    if (parser->in_func_decl_args) {
        // TODO: implement default function arguments
        return stmnt_constdecl((ConstDecl){
            .name = ident,
            .type = type,
            .value = expr_none(),
        }, index);
    }

    Expr expr = parse_expr(parser);
    expect(parser, TokSemiColon);

    // <ident>: <type?> : ;
    if (expr.kind == EkNone) {
        elog(parser, index, "expected expression after \":\" in variable declaration");
    }

    return stmnt_constdecl((ConstDecl){
        .name = ident,
        .type = type,
        .value = expr,
    }, index);
}

Stmnt parse_var_decl(Parser *parser, Expr ident, Type type, bool has_equal) {
    size_t index = (size_t)parser->cursors_idx;

    VarDecl vardecl = {
        .name = ident,
        .type = type,
        .value = expr_none(),
    };

    // <ident>: <type?> = 
    if (has_equal) {
        Expr expr = parse_expr(parser);
        expect(parser, TokSemiColon);
        if (expr.kind == EkNone) {
            elog(parser, index, "expected expression after \"=\" in variable declaration");
        }

        vardecl.value = expr;
    }

    return stmnt_vardecl(vardecl, index);
}

// <ident> :
Stmnt parse_decl(Parser *parser, Expr ident) {
    Token tok = peek(parser);
    if (tok.kind == TokNone) return stmnt_none();

    if (tok.kind == TokColon) {
        next(parser);
        return parse_const_decl(parser, ident, type_none());
    } else if (tok.kind == TokEqual) {
        next(parser);
        return parse_var_decl(parser, ident, type_none(), true);
    } else {
        Type type = parse_type(parser);

        tok = peek(parser);
        if (tok.kind == TokNone) return stmnt_none();

        if (tok.kind == TokColon) {
            next(parser);
            return parse_const_decl(parser, ident, type);
        } else if (tok.kind == TokEqual) {
            next(parser);
            return parse_var_decl(parser, ident, type, true);
        } else if (tok.kind == TokSemiColon) {
            next(parser);
            if (type.kind == TkNone) {
                elog(parser, parser->cursors_idx, "expected type for variable declaration since it does not have a value");
            }
            return parse_var_decl(parser, ident, type, false);
        } else if (tok.kind == TokComma) {
            next(parser);
            if (!parser->in_func_decl_args) {
                elog(parser, parser->cursors_idx, "unexpected comma during declaration");
            }
            return parse_const_decl(parser, ident, type);
        } else if (tok.kind == TokRightBracket) {
            if (!parser->in_func_decl_args) {
                elog(parser, parser->cursors_idx, "unexpected TokenRb during declaration");
            }
            return parse_const_decl(parser, ident, type);
        } else {
            elog(parser, parser->cursors_idx, "unexpected token %s", tokenkind_stringify(tok.kind));
        }
    }

    return stmnt_none();
}

Stmnt parse_ident(Parser *parser, Expr ident) {
    assert(ident.kind == EkIdent);

    Token tok = peek(parser);
    if (tok.kind == TokNone) return stmnt_none();
    
    // <ident>. OR <ident>[
    if (tok.kind == TokDot) {
        next(parser); // already checked if none
        Expr reassigned = parse_field_access(parser, ident);

        tok = peek(parser);
        if (tok.kind == TokNone) return stmnt_none();

        return parse_possible_assignment(parser, reassigned, true);
    } else if (tok.kind == TokLeftSquare) {
        next(parser);
        Expr arrindex = parse_array_index(parser, ident);

        tok = peek(parser);
        if (tok.kind == TokNone) return stmnt_none();

        return parse_possible_assignment(parser, arrindex, true);
    }

    Stmnt assign = parse_possible_assignment(parser, ident, true);
    if (assign.kind != SkNone) return assign;

    switch (tok.kind) {
        case TokColon:
            next(parser);
            return parse_decl(parser, ident);
        case TokLeftBracket: {
            Expr expr = parse_fn_call(parser, ident);
            Stmnt stmnt = stmnt_from_fncall(expr);
            expect(parser, TokSemiColon);
            return stmnt;
        }
        case TokSemiColon:
            if (!parser->in_enum_decl) {
                elog(parser, parser->cursors_idx, "unexpected token %s", tokenkind_stringify(tok.kind));
            }

            next(parser);
            return stmnt_constdecl((ConstDecl){
                .name = ident,
                .type = type_integer(TkI32, TYPECONST, parser->cursors_idx),
            }, parser->cursors_idx);
        default:
            elog(parser, parser->cursors_idx, "unexpected token %s", tokenkind_stringify(tok.kind));
    }

    return stmnt_none();
}

Stmnt parse_return(Parser *parser) {
    size_t index = (size_t)parser->cursors_idx;
    Token tok = peek(parser);
    if (tok.kind == TokSemiColon) {
        next(parser);
        return stmnt_return((Return){
            .value = expr_none(),
            .type = type_none(),
        }, index);
    }

    Expr expr = parse_expr(parser);
    expect(parser, TokSemiColon);

    return stmnt_return((Return){
        .value = expr,
        .type = type_none(),
    }, index);
}

Stmnt parse_continue(Parser *parser) {
    size_t index = (size_t)parser->cursors_idx;
    expect(parser, TokSemiColon);

    return stmnt_continue(index);
}

Stmnt parse_break(Parser *parser) {
    size_t index = (size_t)parser->cursors_idx;
    expect(parser, TokSemiColon);

    return stmnt_break(index);
}

Stmnt parse_if(Parser *parser) {
    size_t index = (size_t)parser->cursors_idx;

    expect(parser, TokLeftBracket);
    Expr cond = parse_expr(parser);
    expect(parser, TokLeftBracket);

    Token capture_tok = peek(parser);
    Expr capture = expr_none();
    // if (<cond>) <[capture]>
    if (capture_tok.kind == TokLeftSquare) {
        next(parser);
        capture_tok = expect(parser, TokIdent);

        Identifiers convert = convert_ident(parser, capture_tok);
        if (convert.kind == IkIdent) {
            capture = convert.expr;
        } else {
            elog(parser, parser->cursors_idx, "capture must be a unique identifier");
        }
        expect(parser, TokRightSquare);
    }

    Stmnt *body = parse_block_curls(parser);
    Arr(Stmnt) else_block = NULL;

    Token tok = peek(parser);
    if (tok.kind == TokIdent) {
        Identifiers convert = convert_ident(parser, tok);
        if (convert.kind == IkKeyword && convert.keyword == KwElse) {
            next(parser);
            else_block = parse_block(parser, TokNone, TokRightCurl);
        }
    }

    return stmnt_if((If){
        .condition = cond,
        .body = body,
        .capture.ident = capture,
        .capturekind = CkIdent,
        .els = else_block,
    }, index);
}

Stmnt parse_extern(Parser *parser) {
    size_t index = (size_t)parser->cursors_idx;
    Stmnt *stmnt = ealloc(sizeof(Stmnt)); *stmnt = parser_parse(parser);
    return stmnt_extern(stmnt, index);
}

Stmnt parse_for(Parser *parser) {
    size_t index = (size_t)parser->cursors_idx;

    expect(parser, TokLeftBracket);
    Token tok = expect(parser, TokIdent);
    Identifiers convert = convert_ident(parser, tok);
    Expr ident;
    if (convert.kind == IkIdent) {
        ident = convert.expr;
    } else {
        elog(parser, parser->cursors_idx, "expected identifer, got reserved word");
    }

    // for (i:
    tok = peek(parser);
    if (tok.kind == TokColon) {
        next(parser);
        tok = peek(parser);

        Stmnt *vardecl = ealloc(sizeof(Stmnt));
        if (tok.kind == TokEqual) {
            // for (i :=
            next(parser);
            *vardecl = parse_var_decl(parser, ident, type_none(), true);
        } else if (tok.kind == TokIdent) {
            // for (i: <type>
            Type type = parse_type(parser);
            expect(parser, TokEqual);
            *vardecl = parse_var_decl(parser, ident, type, true);
        } else {
            elog(parser, parser->cursors_idx, "unexpected token %s in for loop", tokenkind_stringify(tok.kind));
        }

        // for (i: <type?> = <expr>; <cond>
        Expr cond = parse_expr(parser);
        expect(parser, TokSemiColon);

        Stmnt *reassign = ealloc(sizeof(Stmnt));
        tok = peek(parser);
        if (tok.kind == TokIdent) {
            next(parser);

            // for (i: <type?> = <expr>; <cond>; i [+-*/]=
            *reassign = parse_possible_assignment(parser, ident, false);
        }
        expect(parser, TokRightBracket);

        Stmnt *body = parse_block_curls(parser);
        return stmnt_for((For){
            .decl = vardecl,
            .condition = cond,
            .reassign = reassign,
            .body = body,
        }, index);
    } else {
        // TODO: support `for (values) [value]`
        elog(parser, parser->cursors_idx, "expected ':', got %s", tokenkind_stringify(tok.kind));
        return stmnt_none(); // silence warning
    }
}

Stmnt parse_directive(Parser *parser) {
    Token tok = next(parser);

    assert(tok.kind == TokDirective);
    Directive directive = parser_get_directive(parser, tok.ident);
    Stmnt d = stmnt_directive(directive, parser->cursors_idx);

    switch (directive.kind) {
        case DkOutput:
        case DkLink:
        case DkSyslink: {
            tok = expect(parser, TokStrLit);
            expect(parser, TokSemiColon);
            d.directive.str = tok.strlit;
        } break;
        default:
            expect(parser, TokSemiColon);
            break;
    }

    return d;
}

Stmnt parser_parse(Parser *parser) {
    Token tok = peek(parser);
    if (tok.kind == TokNone) return stmnt_none();

    switch (tok.kind) {
        case TokIdent:
        {
            next(parser); // already checked if none
            Identifiers convert = convert_ident(parser, tok);

            if (convert.kind == IkIdent) {
                return parse_ident(parser, convert.expr);
            } else if (convert.kind == IkKeyword) {
                switch (convert.keyword) {
                    case KwReturn:
                        return parse_return(parser);
                    case KwContinue:
                        return parse_continue(parser);
                    case KwBreak:
                        return parse_break(parser);
                    case KwIf:
                        return parse_if(parser);
                    case KwExtern:
                        return parse_extern(parser);
                    case KwFor:
                        return parse_for(parser);
                    default: break;
                }
            }
        } break;
        case TokLeftCurl: {
            size_t index = (size_t)parser->cursors_idx;
            return stmnt_block(parse_block_curls(parser), index);
        } break;
        case TokDirective:
            return parse_directive(parser);
        default:
            next(parser);
            elog(parser, parser->cursors_idx, "unexpected token %s", tokenkind_stringify(tok.kind));
            break;
    }

    return stmnt_none();
}
