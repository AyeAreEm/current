#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include "include/typecheck.h"
#include "include/eval.h"
#include "include/exprs.h"
#include "include/sema.h"
#include "include/stmnts.h"
#include "include/strb.h"
#include "include/types.h"
#include "include/utils.h"

// static const double F32_MIN = -3.40282347E+38;
static const double F32_MAX = 3.40282347E+38;
// static const double F64_MIN = -1.7976931348623157E+308;
// static const double F64_MAX = 1.7976931348623157E+308;

// static const int64_t I8_MIN = INT8_MIN;
static const int64_t I8_MAX = INT8_MAX;
// static const int64_t I16_MIN = INT16_MIN;
static const int64_t I16_MAX = INT16_MAX;
// static const int64_t I32_MIN = INT32_MIN;
static const int64_t I32_MAX = INT32_MAX;
// static const int64_t I64_MIN = INT64_MIN;
static const int64_t I64_MAX = INT64_MAX;

static const uint64_t U8_MAX = UINT8_MAX;
static const uint64_t U16_MAX = UINT16_MAX;
static const uint64_t U32_MAX = UINT32_MAX;
// static const uint64_t U64_MAX = UINT64_MAX;

static void elog(Sema *sema, size_t i, const char *msg, ...) {
    eprintf("%s:%lu:%lu " TERM_RED "error" TERM_END ": ", sema->filename, sema->cursors[i].row, sema->cursors[i].col);

    va_list args;
    va_start(args, msg);

    veprintfln(msg, args);

    va_end(args);
    exit(1);
}

bool tc_ptr_equals(Sema *sema, Type lhs, Type *rhs) {
    if (lhs.kind == TkPtr && rhs->kind == TkPtr) {
        if (!lhs.constant && rhs->constant) return false;
        if (!lhs.constant && !rhs->constant) return tc_ptr_equals(sema, *lhs.option.subtype, rhs->option.subtype);
        if (lhs.constant) return tc_ptr_equals(sema, *lhs.option.subtype, rhs->option.subtype);
    } else {
        return tc_equals(sema, lhs, rhs);
    }

    return false;
}

bool tc_array_equals(Sema *sema, Type lhs, Type *rhs) {
    if (lhs.kind == TkArray && rhs->kind == TkArray) {
        if (lhs.array.len->kind != EkNone) {
            uint64_t l_len = eval_expr(sema, lhs.array.len);

            if (rhs->array.len->kind == EkNone) elog(sema, rhs->cursors_idx, "cannot infer array length");
            uint64_t r_len = eval_expr(sema, rhs->array.len);

            if (l_len != r_len) return false;
            return tc_array_equals(sema, *lhs.array.of, rhs->array.of);
        } else {
            if (rhs->array.len->kind == EkNone) elog(sema, rhs->cursors_idx, "cannot infer array length");
            *lhs.array.len = *rhs->array.len;
            return tc_array_equals(sema, *lhs.array.of, rhs->array.of);
        }
    } else {
        return tc_equals(sema, lhs, rhs);
    }
}

// <ident>: <lhs> = <rhs>
// rhs is a pointer because it might be correct if wrapped in an option
bool tc_equals(Sema *sema, Type lhs, Type *rhs) {
    switch (lhs.kind) {
        case TkVoid: {
            strb t = string_from_type(*rhs);
            debug("warning: unexpected comparsion between Void and %s", t);
            strbfree(t);
            return false;
         }
        case TkTypeDef:
            symtab_find(sema, lhs.typedeff, lhs.cursors_idx);
            if (rhs->kind == TkTypeDef && streq(lhs.typedeff, rhs->typedeff)) {
                return true;
            }
        case TkOption:
            if (rhs->kind == TkOption) {
                if (lhs.option.subtype->kind == TkVoid) {
                    elog(sema, lhs.cursors_idx, "cannot use ?void. maybe use bool instead?");
                }

                if (rhs->option.is_null) {
                    *rhs->option.subtype = *lhs.option.subtype;
                    rhs->option.gen_option = true;
                    return true;
                }
                return tc_equals(sema, *lhs.option.subtype, rhs->option.subtype);
            } else if (tc_equals(sema, *lhs.option.subtype, rhs)) {
                Type *subtype = ealloc(sizeof(Type)); *subtype = *rhs;
                *rhs = type_option((Option){
                    .subtype = subtype,
                    .is_null = false,
                    .gen_option = true,
                }, TYPEVAR, 0);
                return true;
            }
            return false;
        case TkPtr:
            return tc_ptr_equals(sema, lhs, rhs);
        case TkArray:
            return tc_array_equals(sema, lhs, rhs);
        case TkUntypedInt:
            switch (rhs->kind) {
                case TkUntypedInt:
                case TkI8:
                case TkI16:
                case TkI32:
                case TkI64:
                case TkIsize:
                case TkU8:
                case TkU16:
                case TkU32:
                case TkU64:
                case TkUsize:
                    return true;
                default:
                    return false;
            }
        case TkI8:
            switch (rhs->kind) {
                case TkUntypedInt:
                    *rhs = lhs;
                case TkI8:
                    return true;
                default:
                    return false;
            }
        case TkI16:
            switch (rhs->kind) {
                case TkUntypedInt:
                    *rhs = lhs;
                case TkI8:
                case TkI16:
                    return true;
                default:
                    return false;
            }
        case TkI32:
            switch (rhs->kind) {
                case TkUntypedInt:
                    *rhs = lhs;
                case TkI8:
                case TkI16:
                case TkI32:
                    return true;
                default:
                    return false;
            }
        case TkI64:
            switch (rhs->kind) {
                case TkUntypedInt:
                    *rhs = lhs;
                case TkI8:
                case TkI16:
                case TkI32:
                case TkI64:
                    return true;
                default:
                    return false;
            }
        case TkIsize:
            switch (rhs->kind) {
                case TkUntypedInt:
                    *rhs = lhs;
                case TkI8:
                case TkI16:
                case TkI32:
                case TkI64:
                case TkIsize:
                    return true;
                default:
                    return false;
            }
        case TkU8:
            switch (rhs->kind) {
                case TkUntypedInt:
                    *rhs = lhs;
                case TkU8:
                    return true;
                default:
                    return false;
            }
        case TkU16:
            switch (rhs->kind) {
                case TkUntypedInt:
                    *rhs = lhs;
                case TkU8:
                case TkU16:
                    return true;
                default:
                    return false;
            }
        case TkU32:
            switch (rhs->kind) {
                case TkUntypedInt:
                    *rhs = lhs;
                case TkU8:
                case TkU16:
                case TkU32:
                    return true;
                default:
                    return false;
            }
        case TkU64:
            switch (rhs->kind) {
                case TkUntypedInt:
                    *rhs = lhs;
                case TkU8:
                case TkU16:
                case TkU32:
                case TkU64:
                    return true;
                default:
                    return false;
            }
        case TkUsize:
            switch (rhs->kind) {
                case TkUntypedInt:
                    *rhs = lhs;
                case TkU8:
                case TkU16:
                case TkU32:
                case TkU64:
                case TkUsize:
                    return true;
                default:
                    return false;
            }
        case TkUntypedFloat:
            switch (rhs->kind) {
                case TkUntypedFloat:
                case TkF32:
                case TkF64:
                    return true;
                default:
                    return false;
            }
        case TkF32:
            switch (rhs->kind) {
                case TkUntypedFloat:
                    *rhs = lhs;
                case TkF32:
                    return true;
                default:
                    return false;
            }
        case TkF64:
            switch (rhs->kind) {
                case TkUntypedFloat:
                    *rhs = lhs;
                case TkF32:
                case TkF64:
                    return true;
                default:
                    return false;
            }
        default:
            break;
    }

    if (lhs.kind == rhs->kind) return true;
    return false;
}

void tc_return(Sema *sema, Stmnt *stmnt) {
    assert(stmnt->kind == SkReturn);
    FnDecl fndecl = sema->envinfo.fn.fndecl;
    Return *ret = &stmnt->returnf;

    if (ret->type.kind == TkNone) {
        ret->type = fndecl.type;
    }

    if (ret->value.kind == EkNone) {
        if (fndecl.type.kind == TkVoid) return;

        strb t1 = string_from_type(fndecl.type);
        strb t2 = string_from_type(ret->type);
        elog(sema, stmnt->cursors_idx, "mismatch types, %s vs %s", t1, t2);
        // TODO: later when providing more than one error message, uncomment the line below
        // strbfree(t1); strbfree(t2);
    }

    if (!tc_equals(sema, ret->type, &ret->value.type)) {
        strb t1 = string_from_type(ret->type);
        strb t2 = string_from_type(ret->value.type);
        elog(sema, stmnt->cursors_idx, "mismatch types, expected return type %s, got %s", t1, t2);
        // TODO: later when providing more than one error message, uncomment the line below
        // strbfree(t1); strbfree(t2);
    }

    if (!tc_equals(sema, fndecl.type, &ret->type)) {
        strb t1 = string_from_type(fndecl.type);
        strb t2 = string_from_type(ret->type);
        elog(sema, stmnt->cursors_idx, "mismatch types, funciton type %s, got %s", t1, t2);
        // TODO: later when providing more than one error message, uncomment the line below
        // strbfree(t1); strbfree(t2);
    }
}

// returns TkNone if no default
Type tc_default_untyped_type(Type type) {
    if (type.kind == TkUntypedInt) {
        return type_integer(TkI64, TYPEVAR, 0);
    } else if (type.kind == TkUntypedFloat) {
        return type_integer(TkF64, TYPEVAR, 0);
    }

    return type_none();
}

void tc_infer(Sema *sema, Type *lhs, Expr *expr) {
    Type *exprtype = resolve_expr_type(sema, expr);
    Type default_type = tc_default_untyped_type(*exprtype);

    if (exprtype->kind == TkTypeDef) {
        symtab_find(sema, exprtype->typedeff, expr->cursors_idx);
    }

    if (default_type.kind != TkNone) {
        *lhs = default_type;
    } else {
        *lhs = *exprtype;
    }
}

void tc_var_decl(Sema *sema, Stmnt *stmnt) {
    assert(stmnt->kind == SkVarDecl);
    VarDecl *vardecl = &stmnt->vardecl;

    if (vardecl->value.kind == EkNone) {
        // <ident>: <type>;
        if (vardecl->type.kind == TkVoid) {
            // <ident>: void; error
            elog(sema, stmnt->cursors_idx, "variable cannot be of type void");
        }
    } else if (vardecl->type.kind == TkNone) {
        tc_infer(sema, &vardecl->type, &vardecl->value);
    } else {
        Type *exprtype = resolve_expr_type(sema, &vardecl->value);
        if (!tc_equals(sema, vardecl->type, exprtype)) {
            strb t1 = string_from_type(vardecl->type);
            strb t2 = string_from_type(*exprtype);
            elog(sema, stmnt->cursors_idx, "mismatch types, variable \"%s\" type %s, expression type %s", vardecl->name.ident, t1, t2);
            // TODO: later when providing more than one error message, uncomment the line below
            // strbfree(t1); strbfree(t2);
        }
    }

    if (vardecl->type.kind == TkArray && vardecl->type.array.len->kind == EkNone) {
        elog(sema, stmnt->cursors_idx, "cannot infer array length for \"%s\" without compound literal", vardecl->name.ident);
    }

    tc_number_within_bounds(sema, vardecl->type, vardecl->value);
}

void tc_make_constant(Type *type) {
    switch (type->kind) {
        case TkI8:
        case TkI16:
        case TkI32:
        case TkI64:
        case TkIsize:
        case TkU8:
        case TkU16:
        case TkU32:
        case TkU64:
        case TkUsize:
        case TkF32:
        case TkF64:
        case TkBool:
        case TkChar:
        case TkString:
        case TkCstring:
        case TkTypeDef:
        case TkTypeId:
            type->constant = true;
            return;
        case TkArray:
            tc_make_constant(type->array.of);
            type->constant = true;
            return;
        case TkOption:
            tc_make_constant(type->option.subtype);
            type->constant = true;
            return;
        case TkPtr:
            // don't make the underlying type constant
            type->constant = true;
            return;
        case TkVoid:
        case TkUntypedInt:
        case TkUntypedFloat:
        case TkNone:
            assert(false && "cannot make void, untyped_int, untyped_float, or None constant");
    }
}

void tc_const_decl(Sema *sema, Stmnt *stmnt) {
    assert(stmnt->kind == SkConstDecl);
    ConstDecl *constdecl = &stmnt->constdecl;
    Type *valtype = resolve_expr_type(sema, &constdecl->value);

    if (constdecl->type.kind == TkNone) {
        tc_infer(sema, &constdecl->type, &constdecl->value);
    } else if (!tc_equals(sema, constdecl->type, valtype)) {
        strb t1 = string_from_type(constdecl->type);
        strb t2 = string_from_type(*valtype);
        elog(sema, stmnt->cursors_idx, "mismatch types, variable \"%s\" type %s, expression type %s", constdecl->name.ident, t1, t2);
        // TODO: later when providing more than one error message, uncomment the line below
        // strbfree(t1); strbfree(t2);
    }

    tc_make_constant(&constdecl->type);
    tc_number_within_bounds(sema, constdecl->type, constdecl->value);
}

void tc_number_within_bounds(Sema *sema, Type type, Expr expr) {
    if (expr.kind == EkIntLit) {
        switch (type.kind) {
            case TkF32: {
                double value = (double)expr.intlit;
                if (value > F32_MAX) {
                    elog(sema, expr.cursors_idx, "literal \"%f\" cannot be represented in f32", value);
                }
            } break;
            case TkF64:
                break;
            case TkU8: {
                uint64_t value = expr.intlit;
                if (value > U8_MAX) {
                    elog(sema, expr.cursors_idx, "literal \"%zu\" cannot be represented in u8", value);
                }
            } break;
            case TkU16: {
                uint64_t value = expr.intlit;
                if (value > U16_MAX) {
                    elog(sema, expr.cursors_idx, "literal \"%zu\" cannot be represented in u16", value);
                }
            } break;
            case TkU32: {
                uint64_t value = expr.intlit;
                if (value > U32_MAX) {
                    elog(sema, expr.cursors_idx, "literal \"%zu\" cannot be represented in u32", value);
                }
            } break;
            case TkU64:
            case TkUsize:
                break;
            case TkI8: {
                uint64_t value = expr.intlit;
                if (value > I8_MAX) {
                    elog(sema, expr.cursors_idx, "literal \"%zu\" cannot be represented in i8", value);
                }
            } break;
            case TkI16: {
                uint64_t value = expr.intlit;
                if (value > I16_MAX) {
                    elog(sema, expr.cursors_idx, "literal \"%zu\" cannot be represented in i16", value);
                }
            } break;
            case TkI32: {
                uint64_t value = expr.intlit;
                if (value > I32_MAX) {
                    elog(sema, expr.cursors_idx, "literal \"%zu\" cannot be represented in i32", value);
                }
            } break;
            case TkI64: {
                uint64_t value = expr.intlit;
                if (value > I64_MAX) {
                    elog(sema, expr.cursors_idx, "literal \"%zu\" cannot be represented in i64", value);
                }
            } break;
            case TkIsize: {
                uint64_t value = expr.intlit;
                if (value > I64_MAX) {
                    elog(sema, expr.cursors_idx, "literal \"%zu\" cannot be represented in isize", value);
                }
            } break;
            default:
                break;
        }
    } else if (expr.kind == EkUnop && expr.unop.kind == UkNegate && expr.unop.val->kind == EkIntLit) {
        switch (type.kind) {
            case TkI8: {
                uint64_t value = expr.intlit;
                if (value > I8_MAX) {
                    elog(sema, expr.cursors_idx, "literal \"%zu\" cannot be represented in i8", value);
                }
            } break;
            case TkI16: {
                uint64_t value = expr.intlit;
                if (value > I16_MAX) {
                    elog(sema, expr.cursors_idx, "literal \"%zu\" cannot be represented in i16", value);
                }
            } break;
            case TkI32: {
                uint64_t value = expr.intlit;
                if (value > I32_MAX) {
                    elog(sema, expr.cursors_idx, "literal \"%zu\" cannot be represented in i32", value);
                }
            } break;
            case TkI64: {
                uint64_t value = expr.intlit;
                if (value > I64_MAX) {
                    elog(sema, expr.cursors_idx, "literal \"%zu\" cannot be represented in i64", value);
                }
            } break;
            case TkIsize: {
                uint64_t value = expr.intlit;
                if (value > I64_MAX) {
                    elog(sema, expr.cursors_idx, "literal \"%zu\" cannot be represented in isize", value);
                }
            } break;
            default:
                break;
        }
    }
}

bool tc_is_unsigned(Sema *sema, Expr expr) {
    Type *type = resolve_expr_type(sema, &expr);

    switch (type->kind) {
        case TkU8:
        case TkU16:
        case TkU32:
        case TkU64:
        case TkUsize:
            return true;
        case TkI8:
        case TkI16:
        case TkI32:
        case TkI64:
        case TkIsize:
            return false;
        default: {
            strb t = string_from_type(*type);
            elog(sema, expr.cursors_idx, "expected an integer type, got %s", t);
            // TODO: later when providing more than one error message, uncomment the line below
            // strbfree(t);
            return false;
        }
    }
}

bool tc_can_compare_equality(Type lhs, Type rhs) {
    switch (lhs.kind) {
        case TkI8:
        case TkI16:
        case TkI32:
        case TkI64:
        case TkIsize:
            switch (rhs.kind) {
                case TkI8:
                case TkI16:
                case TkI32:
                case TkI64:
                case TkIsize:
                case TkUntypedInt:
                    return true;
                default:
                    return false;
            }
        case TkU8:
        case TkU16:
        case TkU32:
        case TkU64:
        case TkUsize:
            switch (rhs.kind) {
                case TkU8:
                case TkU16:
                case TkU32:
                case TkU64:
                case TkUsize:
                case TkUntypedInt:
                    return true;
                default:
                    return false;
            }
        case TkUntypedInt:
            switch (rhs.kind) {
                case TkU8:
                case TkU16:
                case TkU32:
                case TkU64:
                case TkUsize:
                case TkI8:
                case TkI16:
                case TkI32:
                case TkI64:
                case TkIsize:
                case TkUntypedInt:
                    return true;
                default:
                    return false;
            }
        case TkF32:
        case TkF64:
        case TkUntypedFloat:
            switch (rhs.kind) {
                case TkF32:
                case TkF64:
                case TkUntypedFloat:
                    return true;
                default:
                    return false;
            }
        default:
            return false;
    }
}

bool tc_can_compare_order(Type lhs, Type rhs) {
    switch (lhs.kind) {
        case TkI8:
        case TkI16:
        case TkI32:
        case TkI64:
        case TkIsize:
            switch (rhs.kind) {
                case TkI8:
                case TkI16:
                case TkI32:
                case TkI64:
                case TkIsize:
                    return true;
                default:
                    return false;
            }
        case TkU8:
        case TkU16:
        case TkU32:
        case TkU64:
        case TkUsize:
            switch (rhs.kind) {
                case TkU8:
                case TkU16:
                case TkU32:
                case TkU64:
                case TkUsize:
                    return true;
                default:
                    return false;
            }
        case TkUntypedInt:
            switch (rhs.kind) {
                case TkI8:
                case TkI16:
                case TkI32:
                case TkI64:
                case TkIsize:
                case TkU8:
                case TkU16:
                case TkU32:
                case TkU64:
                case TkUsize:
                    return true;
                default:
                    return false;
            }
        case TkF32:
        case TkF64:
        case TkUntypedFloat:
            switch (rhs.kind) {
                case TkF32:
                case TkF64:
                case TkUntypedFloat:
                    return true;
                default:
                    return false;
            }
        default:
            return false;
    }
}
