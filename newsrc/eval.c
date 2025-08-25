#include <assert.h>
#include <stdlib.h>
#include <stdint.h>
#include "include/eval.h"
#include "include/exprs.h"
#include "include/sema.h"
#include "include/types.h"
#include "include/utils.h"

uint64_t eval_binop(Sema *sema, Expr *expr) {
    assert(expr->kind == EkBinop);

    uint64_t lhs = eval_expr(sema, expr->binop.left);
    uint64_t rhs = eval_expr(sema, expr->binop.right);

    switch (expr->binop.kind) {
        case BkPlus:
            return lhs + rhs;
        case BkMinus:
            return lhs - rhs;
        case BkMultiply:
            return lhs * rhs;
        case BkDivide:
            return lhs / rhs;
        case BkLess:
            return lhs < rhs;
        case BkLessEqual:
            return lhs <= rhs;
        case BkGreater:
            return lhs > rhs;
        case BkGreaterEqual:
            return lhs >= rhs;
        case BkEquals:
            return lhs == rhs;
        case BkInequals:
            return lhs != rhs;
    }
}

uint64_t eval_unop(Sema *sema, Expr *expr) {
    assert(expr->kind == EkUnop);

    uint64_t val = eval_expr(sema, expr->unop.val);

    switch (expr->unop.kind) {
        case UkNot:
            return !val;
        case UkNegate:
            return -val;
        case UkAddress:
            comp_elog("cannot take address at compile time");
            return 0;
    }
}

uint64_t eval_expr(Sema *sema, Expr *expr) {
    sema_expr(sema, expr);

    switch (expr->kind) {
        case EkIntLit:
            return expr->intlit;
        case EkBinop:
            return eval_binop(sema, expr);
        case EkUnop:
            return eval_unop(sema, expr);
        default:
            debug("not implemented in eval_expr");
            exit(1);
    }
}

Number eval_int_cast(Type type, uint64_t value) {
    Number n;

    switch (type.kind) {
        case TkF32:
            n.kind = NkF32;
            n.f32 = (float)value;
            break;
        case TkF64:
            n.kind = NkF64;
            n.f64 = (double)value;
            break;

        case TkU8:
            n.kind = NkU8;
            n.u8 = (uint8_t)value;
            break;
        case TkU16:
            n.kind = NkU16;
            n.u16 = (uint16_t)value;
            break;
        case TkU32:
            n.kind = NkU32;
            n.u32 = (uint32_t)value;
            break;
        case TkU64:
            n.kind = NkU64;
            n.u64 = (uint64_t)value;
            break;
        case TkUsize:
            n.kind = NkUsize;
            n.usize = (size_t)value;
            break;

        case TkI8:
            n.kind = NkI8;
            n.i8 = (int8_t)value;
            break;
        case TkI16:
            n.kind = NkI16;
            n.i16 = (int16_t)value;
            break;
        case TkI32:
            n.kind = NkI32;
            n.i32 = (int32_t)value;
            break;
        case TkI64:
            n.kind = NkI64;
            n.i64 = (int64_t)value;
            break;
        case TkIsize:
            n.kind = NkIsize;
            n.isize = (ssize_t)value;
            break;

        default:
            n.kind = NkI64;
            n.usize = (int64_t)value;
    }

    return n;
}
