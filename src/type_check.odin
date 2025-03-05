package main

tc_compare :: proc(lhs: Type, rhs: Type) -> bool {
    if lhs == rhs {
        return true
    }

    #partial switch lhs {
    case .I32:
        #partial switch rhs {
        case .I32, .Untyped_Int:
            return true
        }
    case .I64:
        #partial switch rhs {
        case .I32, .I64, .Untyped_Int:
            return true
        }
    }

    return false
}

tc_return :: proc(fn: StmntFnDecl, ret: ^StmntReturn) {
    if ret.type == nil {
        ret.type = fn.type // fn.type can't be nil
    }

    ret_expr_type := type_of_expr(ret.value)

    if !tc_compare(ret.type, ret_expr_type) {
        elog(get_cursor_index(cast(Stmnt)ret^), "mismatch types, return type %v, expression type %v", ret.type, ret_expr_type)
    }

    if !tc_compare(fn.type, ret.type) {
        elog(get_cursor_index(cast(Stmnt)ret^), "mismatch types, function type %v, return type %v", fn.type, ret.type)
    }
}
