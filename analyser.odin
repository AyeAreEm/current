package main

import "core:fmt"
import "core:os"

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

    if ret.type == nil {
        ret.type = expr_type
    } else if ret.type != expr_type {
        elog(get_cursor_index(ret.value), "mismatch types, return type %v, expression type %v", ret.type, expr_type)
    }

    if fn.type != ret.type {
        elog(get_cursor_index(ret.value), "mismatch types, function returns %v, returning %v", fn.type, ret.type)
    }
}

analyse_var_decl :: proc(using env: ^Analyser, vardecl: ^StmntVarDecl) {
    analyse_expr(env, &vardecl.value)
    expr_type := type_of_expr(vardecl.value)

    if expr_type == .Void {
        elog(get_cursor_index(vardecl.value), "illegal variable \"%v\" type Void", vardecl.name)
    }

    if vardecl.type == nil {
        vardecl.type = expr_type
    } else if vardecl.type != expr_type && expr_type != .Untyped_Int {
        elog(get_cursor_index(vardecl.value), "mismatch types, variable \"%v\" type %v, expression type %v", vardecl.name, vardecl.type, expr_type)
    }

    symtab_push(&symtab, vardecl.name, vardecl^)
}

analyse_fn :: proc(using env: ^Analyser, fn: StmntFnDecl) {
    symtab_push(&symtab, fn.name, fn)
    symtab_new_scope(&symtab)

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
        }
    }
}
