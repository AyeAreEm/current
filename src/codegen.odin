package main

import "core:fmt"
import "core:strings"

Codegen :: struct {
    ast: [dynamic]Stmnt,
    symtab: SymTab,
    code: strings.Builder,
    indent_level: u8,
}

gen_indent :: proc(self: ^Codegen) {
    for i in 0..<self.indent_level {
        fmt.sbprint(&self.code, "    ")
    }
}

gen_block :: proc(self: ^Codegen, block: [dynamic]Stmnt) {
    for statement in block {
        switch stmnt in statement {
        case FnDecl:
            gen_fn_decl(self, stmnt)
        case VarDecl:
            gen_var_decl(self, stmnt)
        case ConstDecl:
            gen_const_decl(self, stmnt)
        case VarReassign:
            gen_var_reassign(self, stmnt)
        case Return:
            gen_return(self, stmnt)
        case FnCall:
            call := gen_fn_call(self, stmnt, true)
            defer delete(call)
            fmt.sbprint(&self.code, call)
        case If:
            gen_if(self, stmnt)
        }
    }
}

gen_if :: proc(self: ^Codegen, ifs: If) {
    gen_indent(self)
    fmt.sbprint(&self.code, "if (")

    condition, alloced := gen_expr(self, ifs.condition)
    defer if alloced do delete(condition)

    fmt.sbprintfln(&self.code, "%v) {{", condition)
    self.indent_level += 1
    gen_block(self, ifs.body)

    self.indent_level -= 1
    gen_indent(self)
    fmt.sbprint(&self.code, "}")

    self.indent_level += 1
    fmt.sbprintln(&self.code, " else {")
    gen_block(self, ifs.els)

    self.indent_level -= 1
    gen_indent(self)
    fmt.sbprintln(&self.code, "}")
}

gen_fn_decl :: proc(self: ^Codegen, fndecl: FnDecl) {
    gen_indent(self)
    fmt.sbprintf(&self.code, "pub fn %v(", fndecl.name)

    for stmnt, i in fndecl.args {
        arg := stmnt.(ConstDecl)

        if i == 0 {
            fmt.sbprintf(&self.code, "%v: %v", arg.name, string_from_type(arg.type))
        } else {
            fmt.sbprintf(&self.code, ", %v: %v", arg.name, string_from_type(arg.type))
        }
    }
    fmt.sbprintfln(&self.code, ") %v {{", string_from_type(fndecl.type))
    defer fmt.sbprintln(&self.code, "}")

    self.indent_level += 1
    defer self.indent_level -= 1

    gen_block(self, fndecl.body)
}

// returns allocated string, needs to be freed
@(require_results)
gen_fn_call :: proc(self: ^Codegen, fncall: FnCall, with_indent: bool = false) -> string {
    if with_indent {
        gen_indent(self)
    }

    call := strings.builder_make()
    fmt.sbprintf(&call, "%v(", fncall.name.literal)
    for arg, i in fncall.args {
        expr, alloced := gen_expr(self, arg)
        defer if alloced do delete(expr)

        if i == 0 {
            fmt.sbprintf(&call, "%v", expr)
        } else {
            fmt.sbprintf(&call, ", %v", expr)
        }
    }
    fmt.sbprint(&call, ")")

    return strings.to_string(call)
}

// returns string and true if string is allocated
gen_expr :: proc(self: ^Codegen, expression: Expr) -> (string, bool) {
    switch expr in expression {
    case Ident:
        return expr.literal, false
    case Const:
        return expr.name, false
    case IntLit:
        return expr.literal, false
    case True:
        return "true", false
    case False:
        return "false", false
    case FnCall:
        return gen_fn_call(self, expr), true
    case Grouping:
        value, alloced := gen_expr(self, expr.value^)
        ret := fmt.aprintf("(%v)", value)
        if alloced {
            debug("memory leak")
        }

        return ret, true
    case Negative:
        value, alloced := gen_expr(self, expr.value^)
        ret := fmt.aprintf("-%v", value)
        
        if alloced {
            debug("memory leak")
        }

        return ret, true
    case Not:
        cond, alloced := gen_expr(self, expr.condition^)
        ret := fmt.aprintf("!%v", cond)
        
        if alloced {
            debug("memory leak")
        }

        return ret, true
    case LessThan:
        lhs, lhs_alloc := gen_expr(self, expr.left^)
        rhs, rhs_alloc := gen_expr(self, expr.right^)
        ret := fmt.aprintf("%v < %v", lhs, rhs)

        if lhs_alloc || rhs_alloc {
            debug("memory leak")
        }

        return ret, true
    case LessOrEqual:
        lhs, lhs_alloc := gen_expr(self, expr.left^)
        rhs, rhs_alloc := gen_expr(self, expr.right^)
        ret := fmt.aprintf("%v <= %v", lhs, rhs)

        if lhs_alloc || rhs_alloc {
            debug("memory leak")
        }

        return ret, true
    case GreaterThan:
        lhs, lhs_alloc := gen_expr(self, expr.left^)
        rhs, rhs_alloc := gen_expr(self, expr.right^)
        ret := fmt.aprintf("%v > %v", lhs, rhs)

        if lhs_alloc || rhs_alloc {
            debug("memory leak")
        }

        return ret, true
    case GreaterOrEqual:
        lhs, lhs_alloc := gen_expr(self, expr.left^)
        rhs, rhs_alloc := gen_expr(self, expr.right^)
        ret := fmt.aprintf("%v >= %v", lhs, rhs)

        if lhs_alloc || rhs_alloc {
            debug("memory leak")
        }

        return ret, true
    case Equality:
        lhs, lhs_alloc := gen_expr(self, expr.left^)
        rhs, rhs_alloc := gen_expr(self, expr.right^)
        ret := fmt.aprintf("%v == %v", lhs, rhs)

        if lhs_alloc || rhs_alloc {
            debug("memory leak")
        }

        return ret, true
    case Inequality:
        lhs, lhs_alloc := gen_expr(self, expr.left^)
        rhs, rhs_alloc := gen_expr(self, expr.right^)
        ret := fmt.aprintf("%v != %v", lhs, rhs)

        if lhs_alloc || rhs_alloc {
            debug("memory leak")
        }

        return ret, true
    case Plus:
        lhs, lhs_alloc := gen_expr(self, expr.left^)
        rhs, rhs_alloc := gen_expr(self, expr.right^)
        ret := fmt.aprintf("%v + %v", lhs, rhs)

        if lhs_alloc || rhs_alloc {
            debug("memory leak")
        }

        return ret, true
    case Minus:
        lhs, lhs_alloc := gen_expr(self, expr.left^)
        rhs, rhs_alloc := gen_expr(self, expr.right^)
        ret := fmt.aprintf("%v - %v", lhs, rhs)

        if lhs_alloc || rhs_alloc {
            debug("memory leak")
        }

        return ret, true
    case Multiply:
        lhs, lhs_alloc := gen_expr(self, expr.left^)
        rhs, rhs_alloc := gen_expr(self, expr.right^)
        ret := fmt.aprintf("%v * %v", lhs, rhs)

        if lhs_alloc || rhs_alloc {
            debug("memory leak")
        }

        return ret, true
    case Divide:
        lhs, lhs_alloc := gen_expr(self, expr.left^)
        rhs, rhs_alloc := gen_expr(self, expr.right^)
        ret := fmt.aprintf("%v / %v", lhs, rhs)

        if lhs_alloc || rhs_alloc {
            debug("memory leak")
        }

        return ret, true
    }

    unreachable()
}

gen_var_decl :: proc(self: ^Codegen, vardecl: VarDecl) {
    gen_indent(self)
    fmt.sbprintf(&self.code, "var %v: %v = ", vardecl.name, string_from_type(vardecl.type))

    if vardecl.value == nil {
        fmt.sbprintln(&self.code, "undefined;")
    } else {
        value, alloced := gen_expr(self, vardecl.value)
        defer if alloced do delete(value)
        fmt.sbprintfln(&self.code, "%v;", value)
    }
}

gen_var_reassign :: proc(self: ^Codegen, varre: VarReassign) {
    gen_indent(self)
    value, alloced := gen_expr(self, varre.value)
    defer if alloced do delete(value)

    fmt.sbprintfln(&self.code, "%v = %v;", varre.name, value)
}

gen_const_decl :: proc(self: ^Codegen, constdecl: ConstDecl) {
    gen_indent(self)
    value, alloced := gen_expr(self, constdecl.value)
    defer if alloced do delete(value)

    fmt.sbprintfln(&self.code, "const %v: %v = %v;", constdecl.name, string_from_type(constdecl.type), value);
}

gen_return :: proc(self: ^Codegen, ret: Return) {
    gen_indent(self)
    value, alloced := gen_expr(self, ret.value)
    defer if alloced do delete(value)

    fmt.sbprintfln(&self.code, "return %v;", value)
}

gen :: proc(self: ^Codegen) {
    for statement in self.ast {
        #partial switch stmnt in statement {
        case FnDecl:
            gen_fn_decl(self, stmnt)
        case VarDecl:
            gen_var_decl(self, stmnt)
        case ConstDecl:
            gen_const_decl(self, stmnt)
        case VarReassign:
            gen_var_reassign(self, stmnt)
        }
    }
}
