package main

import "core:fmt"
import "core:strings"

Codegen :: struct {
    ast: [dynamic]Stmnt,
    symtab: SymTab,
    code: strings.Builder,
    indent_level: u8,
}

gen_indent :: proc(using env: ^Codegen) {
    for i in 0..<indent_level {
        fmt.sbprint(&code, "    ")
    }
}

gen_block :: proc(using env: ^Codegen, block: [dynamic]Stmnt) {
    for statement in block {
        switch stmnt in statement {
        case FnDecl:
            gen_fn_decl(env, stmnt)
        case VarDecl:
            gen_var_decl(env, stmnt)
        case ConstDecl:
            gen_const_decl(env, stmnt)
        case VarReassign:
            gen_var_reassign(env, stmnt)
        case Return:
            gen_return(env, stmnt)
        case FnCall:
            gen_fn_call(env, stmnt, true)
        case If:
            gen_if(env, stmnt)
        }
    }
}

gen_if :: proc(using env: ^Codegen, ifs: If) {
    gen_indent(env)
    fmt.sbprint(&code, "if (")

    condition, alloced := gen_expr(env, ifs.condition)
    defer if alloced do delete(condition)

    fmt.sbprintfln(&code, "%v) {{", condition)
    defer {
        gen_indent(env)
        fmt.sbprintln(&code, "}")
    }

    gen_block(env, ifs.body)
}

gen_fn_decl :: proc(using env: ^Codegen, fndecl: FnDecl) {
    gen_indent(env)
    fmt.sbprintf(&code, "pub fn %v(", fndecl.name)

    for stmnt, i in fndecl.args {
        arg := stmnt.(ConstDecl)

        if i == 0 {
            fmt.sbprintf(&code, "%v: %v", arg.name, string_from_type(arg.type))
        } else {
            fmt.sbprintf(&code, ", %v: %v", arg.name, string_from_type(arg.type))
        }
    }
    fmt.sbprintfln(&code, ") %v {{", string_from_type(fndecl.type))
    defer fmt.sbprintln(&code, "}")

    indent_level += 1
    defer indent_level -= 1

    gen_block(env, fndecl.body)
}

gen_fn_call :: proc(using env: ^Codegen, fncall: FnCall, with_indent: bool = false) {
    if with_indent {
        gen_indent(env)
    }

    fmt.sbprintf(&code, "%v(", fncall.name)
    for arg, i in fncall.args {
        expr, alloced := gen_expr(env, arg)
        defer if alloced do delete(expr)

        if i == 0 {
            fmt.sbprintf(&code, "%v", expr)
        } else {
            fmt.sbprintf(&code, ", %v", expr)
        }
    }
    fmt.sbprint(&code, ")")
}

// returns string and true if string is allocated
gen_expr :: proc(using env: ^Codegen, expression: Expr) -> (string, bool) {
    switch expr in expression {
    case Var:
        return expr.name, false
    case Const:
        return expr.name, false
    case IntLit:
        return expr.literal, false
    case True:
        return "true", false
    case False:
        return "false", false
    case FnCall:
        gen_fn_call(env, expr)
    case Plus:
        lhs, lhs_alloc := gen_expr(env, expr.left^)
        rhs, rhs_alloc := gen_expr(env, expr.right^)
        ret := fmt.aprintf("%v + %v", lhs, rhs)

        if lhs_alloc || rhs_alloc {
            debug("memory leak")
        }

        return ret, true
    case Minus:
        lhs, lhs_alloc := gen_expr(env, expr.left^)
        rhs, rhs_alloc := gen_expr(env, expr.right^)
        ret := fmt.aprintf("%v - %v", lhs, rhs)

        if lhs_alloc || rhs_alloc {
            debug("memory leak")
        }

        return ret, true
    case Multiply:
        lhs, lhs_alloc := gen_expr(env, expr.left^)
        rhs, rhs_alloc := gen_expr(env, expr.right^)
        ret := fmt.aprintf("%v * %v", lhs, rhs)

        if lhs_alloc || rhs_alloc {
            debug("memory leak")
        }

        return ret, true
    case Divide:
        lhs, lhs_alloc := gen_expr(env, expr.left^)
        rhs, rhs_alloc := gen_expr(env, expr.right^)
        ret := fmt.aprintf("%v / %v", lhs, rhs)

        if lhs_alloc || rhs_alloc {
            debug("memory leak")
        }

        return ret, true
    }

    unreachable()
}

gen_var_decl :: proc(using env: ^Codegen, vardecl: VarDecl) {
    gen_indent(env)
    fmt.sbprintf(&code, "var %v: %v = ", vardecl.name, string_from_type(vardecl.type))

    if vardecl.value == nil {
        fmt.sbprintln(&code, "undefined;")
    } else {
        value, alloced := gen_expr(env, vardecl.value)
        defer if alloced do delete(value)
        fmt.sbprintfln(&code, "%v;", value)
    }
}

gen_var_reassign :: proc(using env: ^Codegen, varre: VarReassign) {
    gen_indent(env)
    value, alloced := gen_expr(env, varre.value)
    defer if alloced do delete(value)

    fmt.sbprintfln(&code, "%v = %v;", varre.name, value)
}

gen_const_decl :: proc(using env: ^Codegen, constdecl: ConstDecl) {
    gen_indent(env)
    value, alloced := gen_expr(env, constdecl.value)
    defer if alloced do delete(value)

    fmt.sbprintfln(&code, "const %v: %v = %v;", constdecl.name, string_from_type(constdecl.type), value);
}

gen_return :: proc(using env: ^Codegen, ret: Return) {
    gen_indent(env)
    value, alloced := gen_expr(env, ret.value)
    defer if alloced do delete(value)

    fmt.sbprintfln(&code, "return %v;", value)
}

gen :: proc(using env: ^Codegen) {
    for statement in ast {
        #partial switch stmnt in statement {
        case FnDecl:
            gen_fn_decl(env, stmnt)
        case VarDecl:
            gen_var_decl(env, stmnt)
        case ConstDecl:
            gen_const_decl(env, stmnt)
        case VarReassign:
            gen_var_reassign(env, stmnt)
        }
    }
}
