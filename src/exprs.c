#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "include/exprs.h"
#include "include/lexer.h"
#include "include/strb.h"
#include "include/types.h"
#include "include/stb_ds.h"

Expr expr_none(void) {
    return (Expr){.kind = EkNone};
}

Expr expr_true(size_t index) {
    return (Expr){
        .kind = EkTrue,
        .cursors_idx = index,
        .type = type_bool(TYPEVAR, index),
    };
}

Expr expr_false(size_t index) {
    return (Expr){
        .kind = EkFalse,
        .cursors_idx = index,
        .type = type_bool(TYPEVAR, index),
    };
}

Expr expr_null(Type t, size_t index) {
    return (Expr){
        .kind = EkNull,
        .cursors_idx = index,
        .type = t,
    };
}

Expr expr_type(Type v, size_t index) {
    return (Expr){
        .kind = EkType,
        .cursors_idx = index,
        .type = (Type){
            .kind = TkTypeId,
        },
        .type_expr = v,
    };
}

Expr expr_intlit(uint64_t v, Type t, size_t index) {
    return (Expr){
        .kind = EkIntLit,
        .cursors_idx = index,
        .type = t,
        .intlit = v,
    };
}

Expr expr_floatlit(double v, Type t, size_t index) {
    return (Expr){
        .kind = EkFloatLit,
        .cursors_idx = index,
        .type = t,
        .floatlit = v,
    };
}

Expr expr_charlit(uint8_t v, size_t index) {
    return (Expr){
        .kind = EkCharLit,
        .cursors_idx = index,
        .type = type_char(TYPEVAR, index),
        .charlit = v,
    };
}

Expr expr_strlit(const char *v, size_t index) {
    return (Expr){
        .kind = EkStrLit,
        .cursors_idx = index,
        .type = type_string(TYPEVAR, index),
        .strlit = v,
    };
}

Expr expr_cstrlit(const char *v, size_t index) {
    return (Expr){
        .kind = EkCstrLit,
        .cursors_idx = index,
        .type = type_cstring(TYPEVAR, index),
        .cstrlit = v,
    };
}

Expr expr_literal(Literal v, Type t, size_t index) {
    return (Expr){
        .kind = EkLiteral,
        .cursors_idx = index,
        .type = t,
        .literal = v,
    };
}

Expr expr_ident(const char *v, Type t, size_t index) {
    return (Expr){
        .kind = EkIdent,
        .cursors_idx = index,
        .type = t,
        .ident = v,
    };
}

Expr expr_fncall(FnCall v, Type t, size_t index) {
    return (Expr){
        .kind = EkFnCall,
        .cursors_idx = index,
        .type = t,
        .fncall = v,
    };
}

Expr expr_binop(Binop v, Type t, size_t index) {
    return (Expr){
        .kind = EkBinop,
        .cursors_idx = index,
        .type = t,
        .binop = v,
    };
}

Expr expr_unop(Unop v, Type t, size_t index) {
    return (Expr){
        .kind = EkUnop,
        .cursors_idx = index,
        .type = t,
        .unop = v,
    };
}

Expr expr_group(Arr(Expr) v, Type t, size_t index) {
    return (Expr){
        .kind = EkGrouping,
        .cursors_idx = index,
        .type = t,
        .group = v,
    };
}

Expr expr_fieldaccess(FieldAccess v, Type t, size_t index) {
    return (Expr){
        .kind = EkFieldAccess,
        .cursors_idx = index,
        .type = t,
        .fieldacc = v,
    };
}

Expr expr_arrayindex(ArrayIndex v, Type t, size_t index) {
    return (Expr){
        .kind = EkArrayIndex,
        .cursors_idx = index,
        .type = t,
        .arrayidx = v,
    };
}

static strb ident_stringify(Expr expr, Arr(Cursor) cursors) {
    assert(expr.kind == EkIdent);

    strb buf = NULL;
    strbprintf(&buf, "%s (%u:%u)", expr.ident, cursors[expr.cursors_idx].row, cursors[expr.cursors_idx].col);

    return buf;
}

static strb fncall_stringify(Expr expr, Arr(Cursor) cursors) {
    assert(expr.kind == EkFnCall);

    strb ident = expr_stringify(*expr.fncall.name, cursors);
    strb buf = NULL;

    strbprintf(&buf, "%s(", ident);
    for (size_t i = 0; i < arrlenu(expr.fncall.args); i++) {
        strb arg = expr_stringify(expr.fncall.args[i], cursors);
        strbprintf(&buf, "%s", arg);
        strbfree(arg);
    }
    strbprintf(&buf, ") (%u:%u)", cursors[expr.cursors_idx].row, cursors[expr.cursors_idx].col);

    strbfree(ident);

    return buf;
}

static strb arrayindex_stringify(Expr expr, Arr(Cursor) cursors) {
    assert(expr.kind == EkArrayIndex);

    strb ident = expr_stringify(*expr.arrayidx.accessing, cursors);
    strb index = expr_stringify(*expr.arrayidx.index, cursors);

    strb buf = NULL;
    strbprintf(&buf, "%s[%s] (%u:%u)", ident, index, cursors[expr.cursors_idx].row, cursors[expr.cursors_idx].col);

    strbfree(index);
    strbfree(ident);

    return buf;
}

static strb fieldaccess_stringify(Expr expr, Arr(Cursor) cursors) {
    assert(expr.kind == EkFieldAccess);

    strb ident = expr_stringify(*expr.fieldacc.accessing, cursors);
    strb field = NULL;
    if (expr.fieldacc.deref) {
        strbpush(&field, '&');
    } else {
        field = expr_stringify(*expr.fieldacc.field, cursors);
    }

    strb buf = NULL;
    strbprintf(&buf, "%s.%s (%u:%u)", ident, field, cursors[expr.cursors_idx].row, cursors[expr.cursors_idx].col);

    strbfree(ident);
    strbfree(field);

    return buf;
}

static strb binop_stringify(Expr expr, Arr(Cursor) cursors) {
    assert(expr.kind == EkBinop);

    strb left = expr_stringify(*expr.binop.left, cursors);
    strb right = expr_stringify(*expr.binop.right, cursors);

    char *op = "";
    switch (expr.binop.kind) {
        case BkPlus:
            op = "+";
            break;
        case BkMinus:
            op = "-";
            break;
        case BkMultiply:
            op = "*";
            break;
        case BkDivide:
            op = "/";
            break;
        case BkLess:
            op = "<";
            break;
        case BkLessEqual:
            op = "<=";
            break;
        case BkGreater:
            op = ">";
            break;
        case BkGreaterEqual:
            op = ">=";
            break;
        case BkEquals:
            op = "==";
            break;
        case BkInequals:
            op = "!=";
            break;
        case BkBitAnd:
            op = "&";
            break;
        case BkBitOr:
            op = "|";
            break;
        case BkLeftShift:
            op = "<<";
            break;
        case BkRightShift:
            op = ">>";
            break;
        case BkAnd:
            op = "and";
            break;
        case BkOr:
            op = "or";
            break;
    }

    strb buf = NULL;
    strbprintf(&buf, "%s %s %s (%u:%u)", left, right, op, cursors[expr.cursors_idx].row, cursors[expr.cursors_idx].col);

    strbfree(right);
    strbfree(left);

    return buf;
}

static strb unop_stringify(Expr expr, Arr(Cursor) cursors) {
    assert(expr.kind == EkUnop);

    strb left = expr_stringify(*expr.unop.val, cursors);

    char op = 0;
    switch (expr.unop.kind) {
        case UkNegate:
            op = '-';
            break;
        case UkNot:
            op = '!';
            break;
        case UkAddress:
            op = '&';
            break;
    }

    strb buf = NULL;
    strbprintf(&buf, "%c%s", op, left);
    strbfree(left);

    return buf;
}

static strb literal_stringify(Expr expr, Arr(Cursor) cursors) {
    assert(expr.kind == EkLiteral);

    strb buf = NULL;
    strb t = string_from_type(expr.type);
    strbprintf(&buf, "%s{", t);
    strbfree(t);

    size_t len;
    if (expr.literal.kind == LitkExprs) {
        len = arrlenu(expr.literal.exprs);
    } else {
        strbprintf(&buf, "PRINT STMNTS NOT IMPLED}");
        return buf;
    }

    for (size_t i = 0; i < len; i++) {
        strb val = expr_stringify(expr.literal.exprs[i], cursors);
        if (i == 0) {
            strbprintf(&buf, "%s", val);
        } else {
            strbprintf(&buf, ", %s", val);
        }
        strbfree(val);
    }
    strbpush(&buf, '}');

    return buf;
}
static strb grouping_stringify(Expr expr, Arr(Cursor) cursors) {
    assert(expr.kind == EkGrouping);

    strb buf = NULL;
    strbpush(&buf, '(');

    for (size_t i = 0; i < arrlenu(expr.group); i++) {
        strb val = expr_stringify(expr.group[i], cursors);
        strbprintf(&buf, "%s", val);
        strbfree(val);
    }

    return buf;
}

static strb intlit_stringify(Expr expr) {
    assert(expr.kind == EkIntLit);

    strb buf = NULL;

    switch (expr.type.kind) {
        case TkI8:
        case TkI16:
        case TkI32:
        case TkI64:
        case TkIsize:
            strbprintf(&buf, "%ld", expr.intlit);
            break;
        case TkU8:
        case TkU16:
        case TkU32:
        case TkU64:
        case TkUsize:
            strbprintf(&buf, "%lu", expr.intlit);
            break;
        case TkUntypedInt:
            strbprintf(&buf, "%lu OR %ld", expr.intlit, expr.intlit);
            break;
        default: break;
    }

    return buf;
}

static strb floatlit_stringify(Expr expr) {
    assert(expr.kind == EkFloatLit);

    strb buf = NULL;

    switch (expr.type.kind) {
        case TkF32:
        case TkF64:
        case TkUntypedFloat:
            strbprintf(&buf, "%f", expr.intlit);
            break;
        default: break;
    }

    return buf;
}

static strb charlit_stringify(Expr expr) {
    assert(expr.kind == EkCharLit);

    strb buf = NULL;
    strbprintf(&buf, "'%c'", expr.charlit);

    return buf;
}

static strb strlit_stringify(Expr expr) {
    assert(expr.kind == EkStrLit);

    strb buf = NULL;
    strbprintf(&buf, "\"%s\"", expr.strlit);

    return buf;
}

static strb cstrlit_stringify(Expr expr) {
    assert(expr.kind == EkCstrLit);

    strb buf = NULL;
    strbprintf(&buf, "c\"%s\"", expr.cstrlit);

    return buf;
}

static strb type_stringify(Expr expr) {
    assert(expr.kind == EkType);

    strb buf = NULL;
    strb t = string_from_type(expr.type_expr);
    strbprintf(&buf, "%s", t);

    return buf;
}

static strb true_stringify(Expr expr) {
    assert(expr.kind == EkTrue);

    strb buf = NULL;
    strbprintf(&buf, "True");

    return buf;
}

static strb false_stringify(Expr expr) {
    assert(expr.kind == EkFalse);

    strb buf = NULL;
    strbprintf(&buf, "False");

    return buf;
}

static strb null_stringify(Expr expr) {
    assert(expr.kind == EkNull);

    strb buf = NULL;
    strbprintf(&buf, "Null");

    return buf;
}

static strb none_stringify(Expr expr) {
    assert(expr.kind == EkNone);

    strb buf = NULL;
    strbprintf(&buf, "Undefined");

    return buf;
}

strb expr_stringify(Expr expr, Arr(Cursor) cursors) {
    switch (expr.kind) {
        case EkFnCall:
            return fncall_stringify(expr, cursors);
        case EkIdent:
            return ident_stringify(expr, cursors);
        case EkArrayIndex:
            return arrayindex_stringify(expr, cursors);
        case EkFieldAccess:
            return fieldaccess_stringify(expr, cursors);
        case EkBinop:
            return binop_stringify(expr, cursors);
        case EkUnop:
            return unop_stringify(expr, cursors);
        case EkLiteral:
            return literal_stringify(expr, cursors);
        case EkGrouping:
            return grouping_stringify(expr, cursors);
        case EkIntLit:
            return intlit_stringify(expr);
        case EkFloatLit:
            return floatlit_stringify(expr);
        case EkCharLit:
            return charlit_stringify(expr);
        case EkStrLit:
            return strlit_stringify(expr);
        case EkCstrLit:
            return cstrlit_stringify(expr);
        case EkType:
            return type_stringify(expr);
        case EkTrue:
            return true_stringify(expr);
        case EkFalse:
            return false_stringify(expr);
        case EkNull:
            return null_stringify(expr);
        case EkNone:
            return none_stringify(expr);
        default:
            break;
    }

    return NULL;
}
