package main

tc_equals :: proc(lhs: Type, rhs: Type) -> bool {
    if lhs == rhs {
        return true
    }

    // <ident>: <lhs> = <rhs>
    #partial switch lhs {
    case .I32:
        #partial switch rhs {
        case .I32, .Untyped_Int:
            return true
        }
    case .I64:
        #partial switch rhs {
        case .I64, .I32, .Untyped_Int:
            return true
        }
    }

    return false
}

tc_return :: proc(analyser: ^Analyser, fn: FnDecl, ret: ^Return) {
    if ret.type == nil {
        ret.type = fn.type // fn.type can't be nil
    }

    ret_expr_type := type_of_expr(ret.value)

    if !tc_equals(ret.type, ret_expr_type) {
        elog(analyser, get_cursor_index(cast(Stmnt)ret^), "mismatch types, return type %v, expression type %v", ret.type, ret_expr_type)
    }

    if !tc_equals(fn.type, ret.type) {
        elog(analyser, get_cursor_index(cast(Stmnt)ret^), "mismatch types, function type %v, return type %v", fn.type, ret.type)
    }
}

// returns nil if t != untyped
tc_default_untyped_type :: proc(t: Type) -> Type {
    #partial switch t {
    case .Untyped_Int:
        return .I64
    case:
        return nil
    }
}

tc_infer :: proc(lhs: ^Type, expr: Expr) {
    expr_type := type_of_expr(expr)
    expr_default_type := tc_default_untyped_type(expr_type)

    if expr_default_type != nil {
         lhs^ = expr_default_type
    } else {
        lhs^ = expr_type
    }
}

tc_var_decl :: proc(analyser: ^Analyser, vardecl: ^VarDecl) {
    expr_type := type_of_expr(vardecl.value)
    expr_default_type := tc_default_untyped_type(expr_type)

    if vardecl.type == nil {
        tc_infer(&vardecl.type, vardecl.value)
    } else if vardecl.type != expr_type && expr_default_type == nil {
        elog(analyser, get_cursor_index(vardecl.value), "mismatch types, variable \"%v\" type %v, expression type %v", vardecl.name, vardecl.type, expr_type)
    }
}

tc_const_decl :: proc(analyser: ^Analyser, constdecl: ^ConstDecl) {
    expr_type := type_of_expr(constdecl.value)
    expr_default_type := tc_default_untyped_type(expr_type)

    if constdecl.type == nil {
        tc_infer(&constdecl.type, constdecl.value)
    } else if constdecl.type != expr_type && expr_default_type == nil {
        elog(analyser, get_cursor_index(constdecl.value), "mismatch types, variable \"%v\" type %v, expression type %v", constdecl.name, constdecl.type, expr_type)
    }
}
