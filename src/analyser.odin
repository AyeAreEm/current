package main

import "core:fmt"
import "core:os"
import "core:strings"

SymTab :: struct {
    scopes: [dynamic]map[string]Stmnt,
    curr_scope: uint,
}

symtab_find :: proc(using analyser: ^Analyser, key: string, location: int) -> Stmnt {
    using symtab

    elem, ok := scopes[curr_scope][key]
    if !ok {
        elog(analyser, location, "use of undefined \"%v\"", key)
    }

    return elem
}

symtab_push :: proc(using analyser: ^Analyser, key: string, value: Stmnt) {
    using symtab

    elem, ok := scopes[curr_scope][key]
    if !ok {
        scopes[curr_scope][key] = value
        return
    }
    
    cur_index := get_cursor_index(elem)
    elog(analyser, get_cursor_index(value), "redeclaration of \"%v\" from %v:%v", key, cursors[cur_index][0], cursors[cur_index][1])
}

symtab_new_scope :: proc(using analyser: ^Analyser) {
    using symtab

    // maybe im dumb but i fully expected
    // append(&scopes, scopes[curr_scope])
    // to copy `scopes[curr_scope]` and append it but no, it's a reference
    // so any mutation to the newly appended scope also mutates the previous scope
    // idk how i feel about this, on one hand, no implicit copies is good.
    // on the other hand, implicit pointer is bad.

    scope := map[string]Stmnt{}

    for key, value in scopes[curr_scope] {
        scope[key] = value
    }

    append(&scopes, scope)
    curr_scope += 1
}

symtab_pop_scope :: proc(using analyser: ^Analyser) {
    using symtab

    pop(&scopes)
    curr_scope -= 1
}

Analyser :: struct {
    ast: [dynamic]Stmnt,
    symtab: SymTab,
    current_fn: Maybe(FnDecl),

    // debug
    filename: string,
    cursors: [dynamic][2]u32,
}

type_of_expr :: proc(using analyser: ^Analyser, expr: Expr) -> Type {
    switch ex in expr {
    case IntLit:
        return ex.type
    case Var:
        var := symtab_find(analyser, ex.name, ex.cursors_idx).(VarDecl)
        return var.type
    case Const:
        const := symtab_find(analyser, ex.name, ex.cursors_idx).(ConstDecl)
        return const.type
    case FnCall:
        call := symtab_find(analyser, ex.name, ex.cursors_idx).(FnDecl)
        return call.type
    case Plus:
        return ex.type
    case Minus:
        return ex.type
    case Multiply:
        return ex.type
    case Divide:
        return ex.type
    case True:
        return ex.type
    case False:
        return ex.type
    }

    if expr == nil {
        return .Void
    }

    return nil
}

analyse_elog :: proc(using analyser: ^Analyser, i: int, format: string, args: ..any) -> ! {
    if DEBUG_MODE {
        debug("elog from analyser")
    }
    fmt.eprintf("%v:%v:%v \x1b[91;1merror\x1b[0m: ", filename, cursors[i][0], cursors[i][1])
    fmt.eprintfln(format, ..args)

    os.exit(1)
}

analyse_expr :: proc(using env: ^Analyser, expr: ^Expr) {
    switch &ex in expr {
    case FnCall:
        analyse_fn_call(env, &ex)
    case Var:
        stmnt_vardecl := symtab_find(env, ex.name, ex.cursors_idx)
        if vardecl, ok := stmnt_vardecl.(VarDecl); ok {
            ex.type = vardecl.type
        } else if constdecl, ok := stmnt_vardecl.(ConstDecl); ok {
            expr^ = Const {
                name = ex.name,
                type = constdecl.type,
                cursors_idx = ex.cursors_idx,
            }
        } else {
            elog(env, ex.cursors_idx, "expected \"%v\" to be a variable, got %v", ex.name, stmnt_vardecl)
        }
    case Const:
        stmnt_constdecl := symtab_find(env, ex.name, ex.cursors_idx)
        if constdecl, ok := stmnt_constdecl.(ConstDecl); ok {
            ex.type = constdecl.type
        } else if vardecl, ok := stmnt_constdecl.(VarDecl); ok {
            ex.type = vardecl.type
        } else {
            elog(env, ex.cursors_idx, "expected \"%v\" to be a variable, got %v", ex.name, stmnt_constdecl)
        }
    case IntLit:
        return
    case True, False:
        return
    case Plus:
        analyse_expr(env, ex.left)
        analyse_expr(env, ex.right)

        lt := type_of_expr(env, ex.left^)
        rt := type_of_expr(env, ex.right^)
        if !tc_equals(lt, rt) {
            elog(env, ex.cursors_idx, "mismatch types, %v + %v", lt, rt)
        }

        if t := tc_default_untyped_type(lt); t != nil {
            ex.type = t
        } else {
            ex.type = lt
        }
    case Minus:
        analyse_expr(env, ex.left)
        analyse_expr(env, ex.right)

        lt := type_of_expr(env, ex.left^)
        rt := type_of_expr(env, ex.right^)
        if !tc_equals(lt, rt) {
            elog(env, ex.cursors_idx, "mismatch types, %v - %v", lt, rt)
        }

        if t := tc_default_untyped_type(lt); t != nil {
            ex.type = t
        } else {
            ex.type = lt
        }
    case Multiply:
        analyse_expr(env, ex.left)
        analyse_expr(env, ex.right)

        lt := type_of_expr(env, ex.left^)
        rt := type_of_expr(env, ex.right^)
        if !tc_equals(lt, rt) {
            elog(env, ex.cursors_idx, "mismatch types, %v * %v", lt, rt)
        }

        if t := tc_default_untyped_type(lt); t != nil {
            ex.type = t
        } else {
            ex.type = lt
        }
    case Divide:
        analyse_expr(env, ex.left)
        analyse_expr(env, ex.right)

        lt := type_of_expr(env, ex.left^)
        rt := type_of_expr(env, ex.right^)
        if !tc_equals(lt, rt) {
            elog(env, ex.cursors_idx, "mismatch types, %v / %v", lt, rt)
        }

        if t := tc_default_untyped_type(lt); t != nil {
            ex.type = t
        } else {
            ex.type = lt
        }
    }
}

analyse_return :: proc(using env: ^Analyser, fn: FnDecl, ret: ^Return) {
    analyse_expr(env, &ret.value)

    tc_return(env, fn, ret)
}

analyse_var_decl :: proc(using env: ^Analyser, vardecl: ^VarDecl) {
    analyse_expr(env, &vardecl.value)

    tc_var_decl(env, vardecl)

    symtab_push(env, vardecl.name, vardecl^)
}

analyse_var_reassign :: proc(using env: ^Analyser, varre: ^VarReassign) {
    analyse_expr(env, &varre.value)

    stmnt_vardecl := symtab_find(env, varre.name, varre.cursors_idx)
    if vardecl, ok := stmnt_vardecl.(VarDecl); ok {
        varre.type = vardecl.type
    } else if _, ok := stmnt_vardecl.(ConstDecl); ok {
        elog(env, varre.cursors_idx, "cannot mutate constant variable \"%v\"", varre.name)
    } else {
        elog(env, varre.cursors_idx, "expected \"%v\" to be a variable, got %v", varre.name, stmnt_vardecl)
    }

    tc_equals(varre.type, type_of_expr(env, varre.value))
}

analyse_const_decl :: proc(using env: ^Analyser, constdecl: ^ConstDecl) {
    analyse_expr(env, &constdecl.value)

    tc_const_decl(env, constdecl)

    symtab_push(env, constdecl.name, constdecl^)
}

analyse_fn_call :: proc(using env: ^Analyser, fncall: ^FnCall) {
    stmnt_fndecl := symtab_find(env, fncall.name, fncall.cursors_idx)
    fndecl, fndecl_ok := stmnt_fndecl.(FnDecl)
    if !fndecl_ok {
        elog(env, fncall.cursors_idx, "expected \"%v\" to be a function, got %v", stmnt_fndecl)
    }

    if fncall.type == nil {
        fncall.type = fndecl.type
    }

    decl_args_len := len(fndecl.args)
    fncall_args_len := len(fncall.args)
    if decl_args_len != fncall_args_len {
        elog(env, fncall.cursors_idx, "expected %v argument(s) in function call \"%v\", got %v", decl_args_len, fncall.name, fncall_args_len)
    }

    for &call_arg, i in fncall.args {
        analyse_expr(env, &call_arg)
    }

    for decl_arg, i in fndecl.args {
        darg_type := type_of_stmnt(env, decl_arg)
        carg_type := type_of_expr(env, fncall.args[i])

        if !tc_equals(darg_type, carg_type) {
            elog(env, fncall.cursors_idx, "mismatch types, argument %v is expected to be of type %v, got %v", i + 1, darg_type, carg_type)
        }
    }
}

analyse_if :: proc(using env: ^Analyser, ifs: ^If) {
    analyse_expr(env, &ifs.condition)
    condition_type := type_of_expr(env, ifs.condition)
    if !tc_equals(.Bool, condition_type) {
        elog(env, ifs.cursors_idx, "condition must be bool, got %v", condition_type)
    }

    symtab_new_scope(env)
    defer symtab_pop_scope(env)

    analyse_block(env, ifs.body)
}

analyse_block :: proc(using env: ^Analyser, block: [dynamic]Stmnt) {
    for &statement in block {
        switch &stmnt in statement {
        case Return:
            if fn, ok := current_fn.?; ok {
                analyse_return(env, fn, &stmnt)
            } else {
                elog(env, stmnt.cursors_idx, "illegal use of return, not inside a function")
            }
        case VarDecl:
            analyse_var_decl(env, &stmnt)
        case VarReassign:
            analyse_var_reassign(env, &stmnt)
        case ConstDecl:
            analyse_const_decl(env, &stmnt)
        case FnCall:
            analyse_fn_call(env, &stmnt)
        case If:
            analyse_if(env, &stmnt)
        case FnDecl:
            elog(env, stmnt.cursors_idx, "illegal function declaration \"%v\" inside another function", stmnt.name)
        }
    }
}

analyse_fn_decl :: proc(using env: ^Analyser, fn: FnDecl) {
    symtab_push(env, fn.name, fn)

    symtab_new_scope(env)
    defer symtab_pop_scope(env)

    for arg in fn.args {
        symtab_push(env, arg.(ConstDecl).name, arg)
    }

    if strings.compare(fn.name, "main") == 0 && fn.type != .Void {
        elog(env, fn.cursors_idx, "illegal main function, expected return type to be void, got %v", fn.type)
    }
    current_fn = fn

    analyse_block(env, fn.body)
}

analyse :: proc(using env: ^Analyser) {
    for statement in ast {
        switch &stmnt in statement {
        case FnDecl:
            analyse_fn_decl(env, stmnt)
        case VarDecl:
            analyse_var_decl(env, &stmnt)
        case VarReassign:
            analyse_var_reassign(env, &stmnt)
        case ConstDecl:
            analyse_const_decl(env, &stmnt)
        case Return:
            elog(env, stmnt.cursors_idx, "illegal use of return, not inside a function")
        case FnCall:
            elog(env, stmnt.cursors_idx, "illegal use of function call \"%v\", not inside a function", stmnt.name)
        case If:
            elog(env, stmnt.cursors_idx, "illegal use of if statement, not inside a function")
        }
    }
}
