package main

import "core:strconv"
import "core:math"

I8_MAX  :: max(i8)
I8_MIN  :: min(i8)
I16_MAX :: max(i16)
I16_MIN :: min(i16)
I32_MAX :: max(i32)
I32_MIN :: min(i32)
I64_MAX :: max(i64)
I64_MIN :: min(i64)

U8_MAX  :: max(u8)
U8_MIN  :: min(u8)
U16_MAX :: max(u16)
U16_MIN :: min(u16)
U32_MAX :: max(u32)
U32_MIN :: min(u32)
U64_MAX :: max(u64)
U64_MIN :: min(u64)

F32_MIN :: min(f32)
F32_MAX :: min(f32)
F64_MIN :: min(f64)
F64_MAX :: min(f64)

tc_deref_ptr :: proc(analyser: ^Analyser, type: Type) -> Type {
    #partial switch t in type {
    case Ptr:
        return t.type^
    case:
        return t
    }
}

tc_array_equals :: proc(analyser: ^Analyser, lhs: Type, rhs: Type) -> bool {
    #partial switch l in lhs {
    case Array:
        l_len, _ := evaluate_expr(analyser, l.len)
        #partial switch r in rhs {
        case Array:
            r_len, _ := evaluate_expr(analyser, r.len)
            if l_len != r_len do return false
            return tc_array_equals(analyser, l.type^, r.type^)
        }
    case:
        return type_tag_equal(lhs, rhs)
    }

    unreachable()
}

tc_ptr_equals :: proc(analyser: ^Analyser, lhs: Type, rhs: Type) -> bool {
    #partial switch l in lhs {
    case Ptr:
        #partial switch r in rhs {
        case Ptr:
            if !l.constant && r.constant do return false
            if !l.constant && !r.constant do return tc_ptr_equals(analyser, l.type^, r.type^)
            if l.constant do return tc_ptr_equals(analyser, l.type^, r.type^)
        }
    case:
        return type_tag_equal(lhs, rhs)
    }

    unreachable()
}

tc_equals :: proc(analyser: ^Analyser, lhs: Type, rhs: Type) -> bool {
    // <ident>: <lhs> = <rhs>
    #partial switch l in lhs {
    case Ptr:
        return tc_ptr_equals(analyser, lhs, rhs)
    case Array:
        return tc_array_equals(analyser, lhs, rhs)
    case Untyped_Int:
        #partial switch r in rhs {
        case Untyped_Int, I8, I16, I32, I64, U8, U16, U32, U64:
            return true
        }
    case Bool:
        _, ok := rhs.(Bool)
        return ok
    case I8:
        #partial switch r in rhs {
        case I8, Untyped_Int:
            return true
        }
    case I16:
        #partial switch r in rhs {
        case I16, I8, Untyped_Int:
            return true
        }
    case I32:
        #partial switch r in rhs {
        case I32, I16, I8, Untyped_Int:
            return true
        }
    case I64:
        #partial switch r in rhs {
        case I64, I32, I16, I8, Untyped_Int:
            return true
        }
    case U8:
        #partial switch r in rhs {
        case U8, Untyped_Int:
            return true
        }
    case U16:
        #partial switch r in rhs {
        case U16, U8, Untyped_Int:
            return true
        }
    case U32:
        #partial switch r in rhs {
        case U32, U16, U8, Untyped_Int:
            return true
        }
    case U64:
        #partial switch r in rhs {
        case U64, U32, U16, U8, Untyped_Int:
            return true
        }
    case F32:
        #partial switch r in rhs {
        case F32, Untyped_Float:
            return true
        }
    case F64:
        #partial switch r in rhs {
        case F64, F32, Untyped_Float:
            return true
        }
    }

    return false
}

tc_return :: proc(analyser: ^Analyser, fn: FnDecl, ret: ^Return) {
    if ret.type == nil {
        ret.type = fn.type // fn.type can't be nil
    }

    ret_expr_type := type_of_expr(analyser, ret.value)

    if !tc_equals(analyser, ret.type, ret_expr_type) {
        elog(analyser, get_cursor_index(cast(Stmnt)ret^), "mismatch types, return type %v, expression type %v", ret.type, ret_expr_type)
    }

    if !tc_equals(analyser, fn.type, ret.type) {
        elog(analyser, get_cursor_index(cast(Stmnt)ret^), "mismatch types, function type %v, return type %v", fn.type, ret.type)
    }
}

// returns nil if t != untyped
tc_default_untyped_type :: proc(t: Type) -> Type {
    #partial switch _ in t {
    case Untyped_Int:
        return I64{}
    case Untyped_Float:
        return F64{}
    case:
        return nil
    }
}

tc_infer :: proc(analyser: ^Analyser, lhs: ^Type, expr: Expr) {
    expr_type := type_of_expr(analyser, expr)
    expr_default_type := tc_default_untyped_type(expr_type)

    if expr_default_type != nil {
         lhs^ = expr_default_type
    } else {
        lhs^ = expr_type
    }
}

tc_number_within_bounds :: proc(analyser: ^Analyser, type: Type, expression: Expr) {
    #partial switch expr in expression {
    case IntLit:
        #partial switch t in type {
        case F32:
            value, _ := strconv.parse_f64(expr.literal)
            if value > auto_cast F32_MAX {
                elog(analyser, get_cursor_index(expression), "literal \"%v\" cannot be represented in f32", value)
            }
        case F64:
            value, _ := strconv.parse_f64(expr.literal)
            if value > auto_cast F64_MAX {
                elog(analyser, get_cursor_index(expression), "literal \"%v\" cannot be represented in f64", value)
            }
        case U8:
            value, _ := strconv.parse_u64(expr.literal)
            if value > auto_cast U8_MAX {
                elog(analyser, get_cursor_index(expression), "literal \"%v\" cannot be represented in u8", value)
            }
        case U16:
            value, _ := strconv.parse_u64(expr.literal)
            if value > auto_cast U16_MAX {
                elog(analyser, get_cursor_index(expression), "literal \"%v\" cannot be represented in u16", value)
            }
        case U32:
            value, _ := strconv.parse_u64(expr.literal)
            if value > auto_cast U32_MAX {
                elog(analyser, get_cursor_index(expression), "literal \"%v\" cannot be represented in u32", value)
            }
        case U64:
            value, _ := strconv.parse_u64(expr.literal)
            if value > auto_cast U64_MAX {
                elog(analyser, get_cursor_index(expression), "literal \"%v\" cannot be represented in u64", value)
            }
        case I8:
            value, _ := strconv.parse_i64(expr.literal)
            if value > auto_cast I8_MAX {
                elog(analyser, get_cursor_index(expression), "literal \"%v\" cannot be represented in i8", value)
            }
        case I16:
            value, _ := strconv.parse_i64(expr.literal)
            if value > auto_cast I16_MAX {
                elog(analyser, get_cursor_index(expression), "literal \"%v\" cannot be represented in i16", value)
            }
        case I32:
            value, _ := strconv.parse_i64(expr.literal)
            if value > auto_cast I32_MAX {
                elog(analyser, get_cursor_index(expression), "literal \"%v\" cannot be represented in i32", value)
            }
        case I64:
            value, _ := strconv.parse_i64(expr.literal)
            if value > auto_cast I64_MAX {
                elog(analyser, get_cursor_index(expression), "literal \"%v\" cannot be represented in i64", value)
            }
        }
    case Negative:
        #partial switch ex in expr.value^ {
        case IntLit:
            #partial switch t in type {
            case I8:
                value, _ := strconv.parse_i64(ex.literal)
                if -value < auto_cast I8_MIN {
                    elog(analyser, get_cursor_index(expression), "literal \"-%v\" cannot be represented in i8", value)
                }
            case I16:
                value, _ := strconv.parse_i64(ex.literal)
                if -value < auto_cast I16_MIN {
                    elog(analyser, get_cursor_index(expression), "literal \"-%v\" cannot be represented in i16", value)
                }
            case I32:
                value, _ := strconv.parse_i64(ex.literal)
                if -value < auto_cast I32_MIN {
                    elog(analyser, get_cursor_index(expression), "literal \"-%v\" cannot be represented in i32", value)
                }
            case I64:
                value, _ := strconv.parse_i64(ex.literal)
                if -value < auto_cast I64_MIN {
                    elog(analyser, get_cursor_index(expression), "literal \"-%v\" cannot be represented in i64", value)
                }
            }
        }
    }
}

tc_var_decl :: proc(analyser: ^Analyser, vardecl: ^VarDecl) {
    expr_type := type_of_expr(analyser, vardecl.value)

    if type_tag_equal(expr_type, Void{}) {
        return
    }

    if vardecl.type == nil {
        tc_infer(analyser, &vardecl.type, vardecl.value)
    } else if !tc_equals(analyser, vardecl.type, expr_type) {
        elog(analyser, vardecl.cursors_idx, "mismatch types, variable \"%v\" type %v, expression type %v", vardecl.name, vardecl.type, expr_type)
    }

    tc_number_within_bounds(analyser, vardecl.type, vardecl.value)
}

tc_const_decl :: proc(analyser: ^Analyser, constdecl: ^ConstDecl) {
    expr_type := type_of_expr(analyser, constdecl.value)

    if constdecl.type == nil {
        tc_infer(analyser, &constdecl.type, constdecl.value)
    } else if !tc_equals(analyser, constdecl.type, expr_type) {
        elog(analyser, constdecl.cursors_idx, "mismatch types, variable \"%v\" type %v, expression type %v", constdecl.name, constdecl.type, expr_type)
    }

    tc_number_within_bounds(analyser, constdecl.type, constdecl.value)
}

tc_array_literal :: proc(analyser: ^Analyser, literal: ^Literal) {
    // TODO: finish this

    #partial switch array in literal.type {
    case Array:
        length, _ := evaluate_expr(analyser, array.len)
        if len(literal.values) != cast(int)length {
            elog(analyser, literal.cursors_idx, "array length {}, literal length {}", length, len(literal.values))
        }
    }
}

tc_literal :: proc(analyser: ^Analyser, literal: ^Literal) {
    if type_tag_equal(literal.type, Array{}) {
        tc_array_literal(analyser, literal)
    }
}

tc_can_compare_value :: proc(analyser: ^Analyser, lhs, rhs: Type) -> bool {
    #partial switch l in lhs {
    case Bool:
        return type_tag_equal(rhs, Bool{})
    case I8, I16, I32, I64:
        #partial switch r in rhs {
        case I8, I16, I32, I64:
            return true
        case:
            return false
        }
    case U8, U16, U32, U64:
        #partial switch r in rhs {
        case U8, U16, U32, U64:
            return true
        case:
            return false
        }
    case Untyped_Int:
        #partial switch r in rhs {
        case Untyped_Int, I8, I16, I32, I64, U8, U16, U32, U64:
            return true
        case:
            return false
        }
    case F32, F64, Untyped_Float:
        #partial switch r in rhs {
        case F32, F64, Untyped_Float:
            return true
        case:
            return false
        }
    case:
        return false
    }
}

tc_can_compare_order :: proc(analyser: ^Analyser, lhs, rhs: Type) -> bool {
    #partial switch l in lhs {
    case I8, I16, I32, I64:
        #partial switch r in rhs {
        case I8, I16, I32, I64:
            return true
        case:
            return false
        }
    case U8, U16, U32, U64:
        #partial switch r in rhs {
        case U8, U16, U32, U64:
            return true
        case:
            return false
        }
    case Untyped_Int:
        #partial switch r in rhs {
        case Untyped_Int, I8, I16, I32, I64, U8, U16, U32, U64:
            return true
        case:
            return false
        }
    case F32, F64, Untyped_Float:
        #partial switch r in rhs {
        case F32, F64, Untyped_Float:
            return true
        case:
            return false
        }
    case:
        return false
    }
}
