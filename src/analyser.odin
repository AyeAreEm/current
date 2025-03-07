package main

import "core:fmt"
import "core:os"
import "core:strings"

analyse_expr :: proc(using env: ^Analyser, expr: ^Expr) {
    switch &ex in expr {
    case FuncCall:
        stmnt_funcdecl := symtab_find(&symtab, ex.name, ex.cursors_idx)
        if funcdecl, ok := stmnt_funcdecl.(FnDecl); ok {
            ex.type = funcdecl.type
        } else {
            elog(ex.cursors_idx, "expected \"%v\" to be a function call, got %v", ex.name, stmnt_funcdecl)
        }
    case Var:
        stmnt_vardecl := symtab_find(&symtab, ex.name, ex.cursors_idx)
        if vardecl, ok := stmnt_vardecl.(VarDecl); ok {
            ex.type = vardecl.type
        } else if constdecl, ok := stmnt_vardecl.(ConstDecl); ok {
            expr^ = Const {
                name = ex.name,
                type = constdecl.type,
                cursors_idx = ex.cursors_idx,
            }
        } else {
            elog(ex.cursors_idx, "expected \"%v\" to be a variable, got %v", ex.name, stmnt_vardecl)
        }
    case Const:
        stmnt_constdecl := symtab_find(&symtab, ex.name, ex.cursors_idx)
        if constdecl, ok := stmnt_constdecl.(ConstDecl); ok {
            ex.type = constdecl.type
        } else if vardecl, ok := stmnt_constdecl.(VarDecl); ok {
            ex.type = vardecl.type
        } else {
            elog(ex.cursors_idx, "expected \"%v\" to be a variable, got %v", ex.name, stmnt_constdecl)
        }
    case IntLit:
        return
    }
}

analyse_return :: proc(using env: ^Analyser, fn: FnDecl, ret: ^Return) {
    analyse_expr(env, &ret.value)
    expr_type := type_of_expr(ret.value)

    tc_return(fn, ret)
}

analyse_var_decl :: proc(using env: ^Analyser, vardecl: ^VarDecl) {
    analyse_expr(env, &vardecl.value)

    tc_var_decl(vardecl)

    symtab_push(&symtab, vardecl.name, vardecl^)
}

analyse_const_decl :: proc(using env: ^Analyser, constdecl: ^ConstDecl) {
    analyse_expr(env, &constdecl.value)

    tc_const_decl(constdecl)

    symtab_push(&symtab, constdecl.name, constdecl^)
}

analyse_func_call :: proc(using env: ^Analyser, fncall: ^FuncCall) {
    if fncall.type == nil {
        stmnt_fndecl := symtab_find(&symtab, fncall.name, fncall.cursors_idx)
        if fndecl, ok := stmnt_fndecl.(FnDecl); ok {
            fncall.type = fndecl.type
        } else {
            elog(fncall.cursors_idx, "expected \"%v\" to be a function, got %v", stmnt_fndecl)
        }
    }
}

analyse_fn :: proc(using env: ^Analyser, fn: FnDecl) {
    symtab_push(&symtab, fn.name, fn)

    symtab_new_scope(&symtab)
    defer symtab_pop_scope(&symtab)

    for arg in fn.args {
        symtab_push(&symtab, arg.(VarDecl).name, arg)
    }

    if strings.compare(fn.name, "main") == 0 && fn.type != .Void {
        elog(fn.cursors_idx, "illegal main function, expected return type to be void, got %v", fn.type)
    }

    for &statement in fn.body {
        switch &stmnt in statement {
        case Return:
            analyse_return(env, fn, &stmnt)
        case VarDecl:
            analyse_var_decl(env, &stmnt)
        case ConstDecl:
            analyse_const_decl(env, &stmnt)
        case FuncCall:
            analyse_func_call(env, &stmnt)
        case FnDecl:
            elog(stmnt.cursors_idx, "illegal function declaration \"%v\" inside another function", stmnt.name, fn.name)
        }
    }
}

analyse :: proc(using env: ^Analyser) {
    for statement in ast {
        switch &stmnt in statement {
        case FnDecl:
            analyse_fn(env, stmnt)
        case VarDecl:
            analyse_var_decl(env, &stmnt)
        case ConstDecl:
            analyse_const_decl(env, &stmnt)
        case Return:
            elog(stmnt.cursors_idx, "illegal use of return, not inside a function")
        case FuncCall:
            elog(stmnt.cursors_idx, "illegal use of function call \"%v\", not inside a function", stmnt.name)
        }
    }
}
