package main

import "core:fmt"
import "core:os"
import "core:strings"

analyse_expr :: proc(using env: ^Analyser, expr: ^Expr) {
    switch &ex in expr {
    case ExprVar:
        if stmnt_vardecl := symtab_find(&symtab, ex.name); stmnt_vardecl != nil {
            vardecl := stmnt_vardecl.(StmntVarDecl)
            ex.type = vardecl.type
        }
        return
    case ExprIntLit:
        return
    }
}

analyse_return :: proc(using env: ^Analyser, fn: StmntFnDecl, ret: ^StmntReturn) {
    analyse_expr(env, &ret.value)
    expr_type := type_of_expr(ret.value)

    tc_return(fn, ret)
}

analyse_var_decl :: proc(using env: ^Analyser, vardecl: ^StmntVarDecl) {
    analyse_expr(env, &vardecl.value)
    expr_type := type_of_expr(vardecl.value)

    if expr_type == .Void {
        elog(get_cursor_index(vardecl.value), "illegal variable \"%v\" type Void", vardecl.name)
    }

    if vardecl.type == nil {
        if expr_type == .Untyped_Int {
            vardecl.type = .I64
        } else {
            vardecl.type = expr_type
        }
    } else if vardecl.type != expr_type && expr_type != .Untyped_Int {
        elog(get_cursor_index(vardecl.value), "mismatch types, variable \"%v\" type %v, expression type %v", vardecl.name, vardecl.type, expr_type)
    }

    symtab_push(&symtab, vardecl.name, vardecl^)
}

analyse_fn :: proc(using env: ^Analyser, fn: StmntFnDecl) {
    symtab_push(&symtab, fn.name, fn)
    symtab_new_scope(&symtab)

    if strings.compare(fn.name, "main") == 0 && fn.type != .Void {
        elog(fn.cursors_idx, "illegal main function, expected return type to be void, got %v", fn.type)
    }

    for &statement in fn.body {
        #partial switch &stmnt in statement {
        case StmntReturn:
            analyse_return(env, fn, &stmnt)
        case StmntVarDecl:
            analyse_var_decl(env, &stmnt)
        }
    }
    symtab_pop_scope(&symtab)
}

analyse :: proc(using env: ^Analyser) {
    for statement in ast {
        #partial switch stmnt in statement {
        case StmntFnDecl:
            analyse_fn(env, stmnt)
        case StmntReturn:
            elog(stmnt.cursors_idx, "illegal use of return, not inside a function")
        }
    }
}
