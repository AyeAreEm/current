package main

import "core:fmt"
import "core:os"
import "core:strconv"

// TODO: rework this like a lot man, make TypeInfo
evaluate_expr :: proc(self: ^Analyser, expression: ^Expr) -> (u64, Type) {
    analyse_expr(self, expression)

    #partial switch expr in expression {
    case IntLit:
        return expr.literal, expr.type
    case Plus:
        lhs, lhs_type := evaluate_expr(self, expr.left)
        rhs, rhs_type := evaluate_expr(self, expr.right)

        return lhs + rhs, lhs_type
    case Minus:
        lhs, lhs_type := evaluate_expr(self, expr.left)
        rhs, rhs_type := evaluate_expr(self, expr.right)

        return lhs - rhs, lhs_type
    case Multiply:
        lhs, lhs_type := evaluate_expr(self, expr.left)
        rhs, rhs_type := evaluate_expr(self, expr.right)

        return lhs * rhs, lhs_type
    case Divide:
        lhs, lhs_type := evaluate_expr(self, expr.left)
        rhs, rhs_type := evaluate_expr(self, expr.right)

        return lhs / rhs, lhs_type
    case LessThan:
        lhs, lhs_type := evaluate_expr(self, expr.left)
        rhs, rhs_type := evaluate_expr(self, expr.right)

        return lhs < rhs, lhs_type
    case LessOrEqual:
        lhs, lhs_type := evaluate_expr(self, expr.left)
        rhs, rhs_type := evaluate_expr(self, expr.right)

        return lhs <= rhs, lhs_type
    case GreaterThan:
        lhs, lhs_type := evaluate_expr(self, expr.left)
        rhs, rhs_type := evaluate_expr(self, expr.right)

        return lhs > rhs, lhs_type
    case GreaterOrEqual:
        lhs, lhs_type := evaluate_expr(self, expr.left)
        rhs, rhs_type := evaluate_expr(self, expr.right)

        return lhs >= rhs, lhs_type
    case Negative:
        val, val_type := evaluate_expr(self, expr.value)
        return -val, val_type
    case:
        debug("not implemented")
        os.exit(1)
    }
}
