package main

import "core:fmt"
import "core:os"
import "core:strconv"

// equiv_odin_type :: proc(type: Type) -> typeid {
//     switch t in type {
//     case I8:
//         return i8
//     case I16:
//         return i16
//     case I32:
//         return i32
//     case I64:
//         return i64
//     case U8:
//         return u8
//     case U16:
//         return U16
//     case U32:
//         return u32
//     case U64:
//         return u64
//     case Bool:
//         return bool
//     case Untyped_Int:
//         return i64
//     case TypeId:
//         return typeid
//     case Array:
//         debug("not implemented array in equivalent_odin_type()")
//         unreachable()
//     case Void:
//         return nil
//     }
//
//     return nil
// }

// TODO: rework this like a lot man, make TypeInfo, maybe return u128 or rawptr?
evaluate_expr :: proc(self: ^Analyser, expression: ^Expr) -> (i128, Type) {
    analyse_expr(self, expression)

    #partial switch expr in expression {
    case IntLit:
        val, _ := strconv.parse_i128(expr.literal) // this should always be ok
        return val, expr.type
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
