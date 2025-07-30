#include <assert.h>
#include <stdlib.h>
#include <stdint.h>
#include "include/eval.h"
#include "include/exprs.h"
#include "include/sema.h"
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
