#ifndef EXPRS_H
#define EXPRS_H

#include <stddef.h>
#include <stdint.h>
#include "lexer.h"
#include "types.h"

typedef struct Stmnt Stmnt;

typedef enum ExprKind {
    EkNone,

    // types are also exprs
    EkType,

    EkIntLit,
    EkFloatLit,
    EkCharLit,
    EkStrLit,
    EkCstrLit,
    EkLiteral,

    EkIdent,
    EkFnCall,

    EkBinop,
    EkUnop,

    EkTrue,
    EkFalse,
    EkGrouping,

    EkFieldAccess,
    EkArrayIndex,

    EkNull,
} ExprKind;

typedef enum LitKind {
    LitkNone,
    LitkExprs,
    LitkVars,
} LitKind;

typedef struct Literal {
    LitKind kind;

    union {
        Arr(Expr) exprs;
        Arr(Stmnt) vars; // VarReassign
    };
} Literal;

typedef struct FieldAccess {
    Expr *accessing;
    Expr *field;
    bool deref;
} FieldAccess;

typedef struct ArrayIndex {
    Expr *accessing;
    Expr *index;
} ArrayIndex;

typedef struct FnCall {
    Expr *name;
    Arr(Expr) args;
} FnCall;

typedef enum BinopKind {
    BkPlus,
    BkMinus,
    BkDivide,
    BkMultiply,
    BkMod,

    BkLess,
    BkLessEqual,
    BkGreater,
    BkGreaterEqual,
    BkEquals,
    BkInequals,

    BkBitOr,
    BkBitAnd,
    BkLeftShift,
    BkRightShift,

    BkAnd,
    BkOr,
} BinopKind;

typedef struct Binop { // Binary Operation
    BinopKind kind;

    Expr *left;
    Expr *right;
} Binop;

typedef enum UnopKind {
    UkNot,
    UkNegate,
    UkAddress,
} UnopKind;

typedef struct Unop { // Unary Operation
    UnopKind kind;
    Expr *val;
} Unop;

typedef struct Expr {
    ExprKind kind;
    size_t cursors_idx;
    Type type;

    union {
        Type type_expr;

        uint64_t intlit;
        double floatlit;
        uint8_t charlit;
        const char *strlit;
        const char *cstrlit;
        const char *ident;

        Literal literal;
        FnCall fncall;

        Binop binop;
        Unop unop;

        Expr *group;
        FieldAccess fieldacc;
        ArrayIndex arrayidx;
    };
} Expr;

Expr expr_none(void);
Expr expr_true(size_t index);
Expr expr_false(size_t index);
Expr expr_null(Type t, size_t index);
Expr expr_type(Type v, size_t index);
Expr expr_intlit(uint64_t v, Type t, size_t index);
Expr expr_floatlit(double v, Type t, size_t index);
Expr expr_charlit(uint8_t v, size_t index);
Expr expr_strlit(const char *v, size_t index);
Expr expr_cstrlit(const char *v, size_t index);
Expr expr_literal(Literal v, Type t, size_t index);
Expr expr_ident(const char *v, Type t, size_t index);
Expr expr_fncall(FnCall v, Type t, size_t index);
Expr expr_binop(Binop v, Type t, size_t index);
Expr expr_unop(Unop v, Type t, size_t index);
Expr expr_group(Arr(Expr) v, Type t, size_t index);
Expr expr_fieldaccess(FieldAccess v, Type t, size_t index);
Expr expr_arrayindex(ArrayIndex v, Type t, size_t index);
char *expr_stringify(Expr expr, Arr(Cursor) cursors);

#endif // EXPRS_H
