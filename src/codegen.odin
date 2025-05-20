package main

import "core:fmt"
import "core:strings"
import "core:math/rand"

Codegen :: struct {
    ast: [dynamic]Stmnt,
    code: strings.Builder,

    def_loc: int,
    generated_generics: [dynamic]string,
    linking: [dynamic]string,
    indent_level: u8,
}

codegen_init :: proc(ast: [dynamic]Stmnt) -> Codegen {
    return {
        ast = ast,
        code = strings.builder_make(),

        def_loc = 0,
        generated_generics = make([dynamic]string),
        linking = make([dynamic]string),
        indent_level = 0,
    }
}

ALPHABET :: []rune{
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
}

// returns allocated string, needs to be freed
gen_random_name :: proc() -> string {
    sb := strings.builder_make()

    for i in 0..<10 {
        fmt.sbprint(&sb, rand.choice(ALPHABET))
    }

    return strings.to_string(sb)
}

@(require_results)
gen_typename_array :: proc(self: ^Codegen, type: Type, dimension: int) -> strings.Builder {
    #partial switch t in type {
    case Array:
        if subtype, ok := t.type^.(Array); ok {
            curarray := gen_typename_array(self, subtype.type^, dimension + 1)

            length, length_alloc := gen_expr(self, subtype.len.?^)
            defer if length_alloc do delete(length)

            fmt.sbprintf(&curarray, "%v", length)

            if dimension == 1 {
                parent_len, parent_len_alloc := gen_expr(self, t.len.?^)
                defer if parent_len_alloc do delete(parent_len)
                fmt.sbprintf(&curarray, "%v", parent_len)
                return curarray
            }

            return curarray
        } else {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {t.type^}, &typename)

            length, length_alloc := gen_expr(self, t.len.?^)
            defer if length_alloc do delete(length)

            curarray := strings.builder_make()
            fmt.sbprintf(&curarray, "CurArray%vd_%v%v", dimension, strings.to_string(typename), length)
            return curarray
        }
    case:
        typename := strings.builder_make()
        defer delete(typename.buf)
        gen_typename(self, {t}, &typename)

        curarray := strings.builder_make()
        fmt.sbprintf(&curarray, "CurArray%vd_%v", dimension, strings.to_string(typename))
        return curarray
    }
}

// remember to free typename after
gen_typename :: proc(self: ^Codegen, types: []Type, typename: ^strings.Builder) {
    for type in types {
        switch t in type {
        case Void, Untyped_Int, Untyped_Float:
            panic("gen_typename not implemented yet")
        case I8, I16, I32, I64, Isize, U8, U16, U32, U64, Usize, F32, F64, Bool, Char, String:
            str, str_alloc := gen_type(self, t)
            defer if str_alloc do delete(str)
            fmt.sbprintf(typename, "%v", str)
        case Cstring:
            fmt.sbprintf(typename, "%v", "constcharptr")
        case Ptr:
            gen_typename(self, []Type{t.type^}, typename)
            fmt.sbprintf(typename, "%v", "ptr")
        case Array:
            curarray := gen_typename_array(self, type, 1)
            defer delete(curarray.buf)

            fmt.sbprintf(typename, "%v", strings.to_string(curarray))
        case Option:
            subtypename := strings.builder_make()
            defer delete(subtypename.buf)
            gen_typename(self, {t.type^}, &subtypename)

            fmt.sbprintf(typename, "CurOption_%v", strings.to_string(subtypename))
        }
    }
}

gen_c_array_decl :: proc(self: ^Codegen, array: Type, str: ^strings.Builder, name: Maybe(string)) {
    #partial switch subtype in array {
    case Array:
        length, length_alloced := gen_expr(self, subtype.len.?^)
        defer if length_alloced do delete(length)

        gen_c_array_decl(self, subtype.type^, str, nil)
        if n, ok := name.?; ok {
            fmt.sbprintf(str, " %v[%v]", n, length)
        } else {
            fmt.sbprintf(str, "[%v]", length)
        }
    case:
        t, t_alloc := gen_type(self, array)
        defer if t_alloc do delete(t)

        fmt.sbprintf(str, "%v", t)
    }
}

gen_array_type :: proc(self: ^Codegen, array: Type, str: ^strings.Builder) {
    #partial switch subtype in array {
    case Array:
        length, length_alloced := gen_expr(self, subtype.len.?^)
        defer if length_alloced do delete(length)

        gen_array_type(self, subtype.type^, str)
        fmt.sbprintf(str, "[%v]", length)
    case:
        t, t_alloc := gen_type(self, array)
        defer if t_alloc do delete(t)

        fmt.sbprintf(str, "%v", t)
    }
}

gen_ptr_type :: proc(self: ^Codegen, ptr: Type) -> string {
    #partial switch subtype in ptr {
    case Ptr:
        return fmt.aprintf("%v%v*", gen_ptr_type(self, subtype.type^), " const" if subtype.constant else "")
    case:
        t, _ := gen_type(self, ptr)
        return t
    }
}

gen_type :: proc(self: ^Codegen, t: Type, declname: Maybe(string) = nil) -> (string, bool) {
    gen_generic_decl(self, t)

    if type_tag_equal(t, Untyped_Int{}) {
        panic("compiler error: should not be converting untyped_int to string")
    } else if type_tag_equal(t, Untyped_Float{}) {
        panic("compiler error: should not be converting untyped_float to string")
    }

    #partial switch subtype in t {
    case Array:
        ret := strings.builder_make()
        if name, ok := declname.?; ok {
            gen_c_array_decl(self, t, &ret, name)
        } else {
            gen_array_type(self, t, &ret)
        }
        return strings.to_string(ret), true
    case Ptr:
        return gen_ptr_type(self, t), true
    case Option:
        ret := strings.builder_make()
        option_type, alloced := gen_type(self, subtype.type^)
        defer if alloced do delete(option_type)

        return fmt.sbprintf(&ret, "?%v", option_type), true
    case Cstring:
        return "const char*", false
    case String:
        return "CurString", false
    case Char:
        // TODO: make this be a type that supports utf8
        return "u8", false
    }

    for k, v in type_map {
        if type_tag_equal(t, v) {
            return k, false
        }
    }
    return "", false
}

gen_extern :: proc(self: ^Codegen, extern: Extern) {
    for statement in extern.body {
        #partial switch stmnt in statement {
        case FnDecl:
            gen_fn_decl(self, stmnt, true)
        case VarDecl:
            gen_var_decl(self, stmnt)
        case ConstDecl:
            gen_const_decl(self, stmnt)
        case VarReassign:
            gen_var_reassign(self, stmnt)
        }
    }
}

gen_indent :: proc(self: ^Codegen) {
    for i in 0..<self.indent_level {
        fmt.sbprint(&self.code, "    ")
    }
}

gen_block :: proc(self: ^Codegen, block: [dynamic]Stmnt) {
    fmt.sbprintln(&self.code, "{")
    self.indent_level += 1

    for statement in block {
        switch stmnt in statement {
        case Directive:
            gen_directive(self, stmnt)
        case Extern:
            gen_extern(self, stmnt)
        case Block:
            gen_indent(self)
            gen_block(self, stmnt.body)
            fmt.sbprintln(&self.code)
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
            fmt.sbprintln(&self.code, ';')
        case If:
            gen_if(self, stmnt)
        case For:
            gen_for(self, stmnt)
        }
    }

    self.indent_level -= 1
    gen_indent(self)
    fmt.sbprintln(&self.code, "}")
}

gen_if :: proc(self: ^Codegen, ifs: If) {
    gen_indent(self)

    condition, alloced := gen_expr(self, ifs.condition)
    defer if alloced do delete(condition)

    if capture, ok := ifs.capture.?; ok {
        fmt.sbprintln(&self.code, "{");
        self.indent_level += 1

        proto := gen_decl_proto(self, capture.(ConstDecl))
        defer delete(proto)

        fmt.sbprintfln(&self.code, "const %v = %v.some;", proto, condition);
        gen_indent(self)
        fmt.sbprintf(&self.code, "if (%v.ok) ", condition)
    } else {
        fmt.sbprintf(&self.code, "if (%v) ", condition)
    }


    gen_block(self, ifs.body)
    strings.pop_byte(&self.code)

    fmt.sbprint(&self.code, " else ")
    gen_block(self, ifs.els)

    if _, ok := ifs.capture.?; ok {
        self.indent_level -= 1
        gen_indent(self)
        fmt.sbprintln(&self.code, "}");
    }
}

gen_for :: proc(self: ^Codegen, forl: For) {
    gen_indent(self)

    fmt.sbprintln(&self.code, "{");
    self.indent_level += 1

    gen_var_decl(self, forl.decl)

    condition, condition_alloc := gen_expr(self, forl.condition)
    defer if condition_alloc do delete(condition)

    reassigned, reassigned_alloced := gen_expr(self, forl.reassign.name)
    defer if reassigned_alloced do delete(reassigned)

    value, value_alloced := gen_expr(self, forl.reassign.value)
    defer if value_alloced do delete(value)

    gen_indent(self)
    fmt.sbprintf(&self.code, "for (; %v; %v = %v) ", condition, reassigned, value)
    gen_block(self, forl.body)

    self.indent_level -= 1
    gen_indent(self)
    fmt.sbprintln(&self.code, "}");
}

// returns allocated string, needs to be freed
@(require_results)
gen_decl_proto :: proc(self: ^Codegen, decl: union{VarDecl, ConstDecl, FnDecl}) -> string {
    name: string
    type: Type
    const := false

    if d, ok := decl.(VarDecl); ok {
        name = d.name.literal
        type = d.type
    } else if d, ok := decl.(ConstDecl); ok {
        name = d.name.literal
        type = d.type
        const = true
    } else if d, ok := decl.(FnDecl); ok {
        name = d.name.literal
        type = d.type
    }

    gen_indent(self)
    if type_tag_equal(type, Array{}) {
        return gen_decl_array_proto(self, decl)
    } else if type_tag_equal(type, Option{}) {
        return gen_decl_option_proto(self, decl)
    }

    var_type_str, var_type_str_alloced := gen_type(self, type)
    defer if var_type_str_alloced do delete(var_type_str)

    return fmt.aprintf("%v%v %v", var_type_str, " const" if const else "", name)
}

gen_fn_decl :: proc(self: ^Codegen, fndecl: FnDecl, is_extern := false) {
    self.def_loc = len(self.code.buf)
    gen_indent(self)

    if strings.compare(fndecl.name.literal, "main") == 0 {
        fmt.sbprint(&self.code, "int main(")
    } else {
        proto := gen_decl_proto(self, fndecl)
        defer delete(proto)

        fmt.sbprintf(&self.code, "%v(", proto)
    }

    for stmnt, i in fndecl.args {
        arg := stmnt.(ConstDecl)
        proto := gen_decl_proto(self, arg)
        defer delete(proto)

        if i == 0 {
            fmt.sbprintf(&self.code, "%v", proto)
        } else {
            fmt.sbprintf(&self.code, ", %v", proto)
        }
    }
    fmt.sbprint(&self.code, ")")

    if fndecl.has_body {
        fmt.sbprint(&self.code, " ")
        gen_block(self, fndecl.body)
    } else {
        fmt.sbprintln(&self.code, ";")
    }
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

gen_array_literal :: proc(self: ^Codegen, expr: Literal) -> (string, bool) {
    literal := strings.builder_make()
    arr := expr.type.(Array)

    typename := strings.builder_make()
    defer delete(typename.buf)
    gen_typename(self, {arr}, &typename)

    types := strings.split_n(strings.to_string(typename), "_", 2)
    defer delete(types)
    types[0] = strings.to_lower(types[0])

    curarray_gen := strings.join(types, "_")
    defer delete(curarray_gen)

    fmt.sbprintf(&literal, "%v(", curarray_gen)

    if subarr, ok := arr.type^.(Array); ok {
        clear(&typename.buf)
        gen_typename(self, {arr.type^}, &typename)
        length, length_alloc := gen_expr(self, arr.len.?^)
        defer if length_alloc do delete(length)

        fmt.sbprintf(&literal, "(%v[%v]){{", strings.to_string(typename), length)
    } else {
        expr_type_str, expr_type_str_alloced := gen_type(self, expr.type)
        defer if expr_type_str_alloced do delete(expr_type_str)

        fmt.sbprintf(&literal, "(%v){{", expr_type_str)
    }

    for val, i in expr.values {
        str_val, alloced := gen_expr(self, val)
        defer if alloced do delete(str_val)

        if i == 0 {
            fmt.sbprintf(&literal, "%v", str_val)
        } else {
            fmt.sbprintf(&literal, ", %v", str_val)
        }
    }
    fmt.sbprint(&literal, "}")

    len, len_alloc := gen_expr(self, arr.len.?^)
    defer if len_alloc do delete(len)
    fmt.sbprintf(&literal, ", %v)", len)

    return strings.to_string(literal), true
}

// returns string and true if string is allocated
gen_expr :: proc(self: ^Codegen, expression: Expr) -> (string, bool) {
    expression := expression

    switch &expr in expression {
    case Cstring:
        return gen_type(self, expr)
    case String:
        return gen_type(self, expr)
    case Char:
        return gen_type(self, expr)
    case Bool:
        return gen_type(self, expr)
    case I8:
        return gen_type(self, expr)
    case I16:
        return gen_type(self, expr)
    case I32:
        return gen_type(self, expr)
    case I64:
        return gen_type(self, expr)
    case Isize:
        return gen_type(self, expr)
    case U8:
        return gen_type(self, expr)
    case U16:
        return gen_type(self, expr)
    case U32:
        return gen_type(self, expr)
    case U64:
        return gen_type(self, expr)
    case Usize:
        return gen_type(self, expr)
    case F32:
        return gen_type(self, expr)
    case F64:
        return gen_type(self, expr)
    case Ident:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }
        return expr.literal, false
    case IntLit:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }
        return expr.literal, false
    case FloatLit:
        if opt, ok := expr.type.(Option); ok && opt.gen_option{
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }
        return expr.literal, false
    case CharLit:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }
        literal := fmt.aprintf("'%v'", expr.literal)
        return literal, true
    case StrLit:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }
        literal := fmt.aprintf("curstr(\"%v\")", expr.literal)
        return literal, true
    case CstrLit:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }
        literal := fmt.aprintf("\"%v\"", expr.literal)
        return literal, true
    case True:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }
        return "true", false
    case False:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }
        return "false", false
    case Null:
        typename := strings.builder_make()
        defer delete(typename.buf)
        gen_typename(self, {expr.type.(Option).type^}, &typename)

        curoption := fmt.aprintf("curoptionnull_%v()", strings.to_string(typename))
        return curoption, true
    case FieldAccess:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }

        subexpr, subexpr_alloced := gen_expr(self, expr.expr^)
        if expr.deref {
            ret := fmt.aprintf("*%v", subexpr)
            return ret, true
        }

        field, field_alloced := gen_expr(self, expr.field^)
        ret := fmt.aprintf("%v.%v", subexpr, field)

        if subexpr_alloced {
            delete(subexpr)
        }
        if field_alloced {
            delete(field)
        }

        return ret, true
    case ArrayIndex:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }

        ident, ident_alloced := gen_expr(self, expr.ident^)
        index, index_alloced := gen_expr(self, expr.index^)
        ret := fmt.aprintf("%v.ptr[%v]", ident, index)

        if ident_alloced {
            delete(ident)
        }
        if index_alloced {
            delete(index)
        }
        
        return ret, true
    case Address:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }
        value, alloced := gen_expr(self, expr.value^)
        ret := fmt.aprintf("&%v", value)
        
        if alloced {
            delete(value)
        }

        return ret, true
    case FnCall:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }

        return gen_fn_call(self, expr), true
    case Literal:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }

        literal := strings.builder_make()

        if arr, ok := expr.type.(Array); ok {
            delete(literal.buf)
            return gen_array_literal(self, expr)
        }

        expr_type_str, expr_type_str_alloced := gen_type(self, expr.type)
        defer if expr_type_str_alloced do delete(expr_type_str)
        fmt.sbprintf(&literal, "(%v){{", expr_type_str)

        for val, i in expr.values {
            str_val, alloced := gen_expr(self, val)
            defer if alloced do delete(str_val)

            if i == 0 {
                fmt.sbprintf(&literal, "%v", str_val)
            } else {
                fmt.sbprintf(&literal, ", %v", str_val)
            }
        }

        fmt.sbprint(&literal, "}")
        return strings.to_string(literal), true
    case Grouping:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }

        value, alloced := gen_expr(self, expr.value^)
        ret := fmt.aprintf("(%v)", value)
        if alloced {
            delete(value)
        }

        return ret, true
    case Negative:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }

        value, alloced := gen_expr(self, expr.value^)
        ret := fmt.aprintf("-%v", value)
        
        if alloced {
            delete(value)
        }

        return ret, true
    case Not:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }

        cond, alloced := gen_expr(self, expr.condition^)
        ret := fmt.aprintf("!%v", cond)
        
        if alloced {
            delete(cond)
        }

        return ret, true
    case LessThan:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }

        lhs, lhs_alloc := gen_expr(self, expr.left^)
        rhs, rhs_alloc := gen_expr(self, expr.right^)
        ret := fmt.aprintf("%v < %v", lhs, rhs)

        if lhs_alloc {
            delete(lhs)
        }
        if rhs_alloc {
            delete(rhs)
        }

        return ret, true
    case LessOrEqual:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }

        lhs, lhs_alloc := gen_expr(self, expr.left^)
        rhs, rhs_alloc := gen_expr(self, expr.right^)
        ret := fmt.aprintf("%v <= %v", lhs, rhs)

        if lhs_alloc {
            delete(lhs)
        }
        if rhs_alloc {
            delete(rhs)
        }

        return ret, true
    case GreaterThan:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }

        lhs, lhs_alloc := gen_expr(self, expr.left^)
        rhs, rhs_alloc := gen_expr(self, expr.right^)
        ret := fmt.aprintf("%v > %v", lhs, rhs)

        if lhs_alloc {
            delete(lhs)
        }
        if rhs_alloc {
            delete(rhs)
        }

        return ret, true
    case GreaterOrEqual:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }

        lhs, lhs_alloc := gen_expr(self, expr.left^)
        rhs, rhs_alloc := gen_expr(self, expr.right^)
        ret := fmt.aprintf("%v >= %v", lhs, rhs)

        if lhs_alloc {
            delete(lhs)
        }
        if rhs_alloc {
            delete(rhs)
        }

        return ret, true
    case Equality:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }

        lhs, lhs_alloc := gen_expr(self, expr.left^)
        rhs, rhs_alloc := gen_expr(self, expr.right^)
        ret := fmt.aprintf("%v == %v", lhs, rhs)

        if lhs_alloc {
            delete(lhs)
        }
        if rhs_alloc {
            delete(rhs)
        }

        return ret, true
    case Inequality:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }

        lhs, lhs_alloc := gen_expr(self, expr.left^)
        rhs, rhs_alloc := gen_expr(self, expr.right^)
        ret := fmt.aprintf("%v != %v", lhs, rhs)

        if lhs_alloc {
            delete(lhs)
        }
        if rhs_alloc {
            delete(rhs)
        }

        return ret, true
    case Plus:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }

        lhs, lhs_alloc := gen_expr(self, expr.left^)
        rhs, rhs_alloc := gen_expr(self, expr.right^)
        ret := fmt.aprintf("%v + %v", lhs, rhs)

        if lhs_alloc {
            delete(lhs)
        }
        if rhs_alloc {
            delete(rhs)
        }

        return ret, true
    case Minus:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }

        lhs, lhs_alloc := gen_expr(self, expr.left^)
        rhs, rhs_alloc := gen_expr(self, expr.right^)
        ret := fmt.aprintf("%v - %v", lhs, rhs)

        if lhs_alloc {
            delete(lhs)
        }
        if rhs_alloc {
            delete(rhs)
        }

        return ret, true
    case Multiply:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }

        lhs, lhs_alloc := gen_expr(self, expr.left^)
        rhs, rhs_alloc := gen_expr(self, expr.right^)
        ret := fmt.aprintf("%v * %v", lhs, rhs)

        if lhs_alloc {
            delete(lhs)
        }
        if rhs_alloc {
            delete(rhs)
        }

        return ret, true
    case Divide:
        if opt, ok := expr.type.(Option); ok && opt.gen_option {
            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {opt.type^}, &typename)

            expr.type = opt.type^
            value, alloced := gen_expr(self, expr)
            defer if alloced do delete(value)

            curoption := fmt.aprintf("curoption_%v(%v)", strings.to_string(typename), value)
            return curoption, true
        }

        lhs, lhs_alloc := gen_expr(self, expr.left^)
        rhs, rhs_alloc := gen_expr(self, expr.right^)
        ret := fmt.aprintf("%v / %v", lhs, rhs)

        if lhs_alloc {
            delete(lhs)
        }
        if rhs_alloc {
            delete(rhs)
        }

        return ret, true
    }

    unreachable()
}

@(require_results)
gen_generic_array_decl :: proc(self: ^Codegen, type: Type, dimension: int) -> (strings.Builder, bool) {
    #partial switch t in type {
    case Array:
        if subtype, ok := t.type^.(Array); ok {
            gen_generic_decl(self, subtype)
            curarray, add := gen_generic_array_decl(self, subtype.type^, dimension + 1)

            length, length_alloc := gen_expr(self, subtype.len.?^)
            defer if length_alloc do delete(length)

            fmt.sbprintf(&curarray, ", %v", length)

            if dimension == 1 {
                parent_len, parent_len_alloc := gen_expr(self, t.len.?^)
                defer if parent_len_alloc do delete(parent_len)

                fmt.sbprintfln(&curarray, ", %v);", parent_len)

                for generics in self.generated_generics {
                    if strings.compare(strings.to_string(curarray), generics) == 0 {
                        return curarray, false
                    }
                }

                return curarray, true
            }

            return curarray, true
        } else {
            type_str, type_str_alloc := gen_type(self, t.type^)
            defer if type_str_alloc do delete(type_str)

            typename := strings.builder_make()
            defer delete(typename.buf)
            gen_typename(self, {t.type^}, &typename)

            length, length_alloc := gen_expr(self, t.len.?^)
            defer if length_alloc do delete(length)

            curarray := strings.builder_make()
            fmt.sbprintfln(&curarray, "CurArray%vd(%v, %v, %v);", dimension, type_str, strings.to_string(typename), length)

            for generics in self.generated_generics {
                if strings.compare(strings.to_string(curarray), generics) == 0 {
                    return curarray, false
                }
            }

            return curarray, true
        }
    case:
        type_str, type_str_alloc := gen_type(self, t)
        defer if type_str_alloc do delete(type_str)

        typename := strings.builder_make()
        defer delete(typename.buf)
        gen_typename(self, {t}, &typename)

        curarray := strings.builder_make()
        fmt.sbprintf(&curarray, "CurArray%vd(%v, %v", dimension, type_str, strings.to_string(typename))
        return curarray, true
    }
}

gen_generic_decl :: proc(self: ^Codegen, type: Type) {
    #partial switch t in type {
    case Array:
        curarray, add := gen_generic_array_decl(self, t, 1)
        if add {
            self.code = sbinsert(&self.code, strings.to_string(curarray), self.def_loc)
            self.def_loc += len(strings.to_string(curarray))
            append(&self.generated_generics, strings.to_string(curarray))
        } else {
            delete(curarray.buf)
        }
    case Option:
        type_str, type_str_alloc := gen_type(self, t.type^)
        defer if type_str_alloc do delete(type_str)

        typename := strings.builder_make()
        defer delete(typename.buf)
        gen_typename(self, {t.type^}, &typename)

        curoption := fmt.aprintfln("CurOption(%v, %v);", type_str, strings.to_string(typename))
        for generics in self.generated_generics {
            if strings.compare(curoption, generics) == 0 {
                delete(curoption)
                return
            }
        }

        self.code = sbinsert(&self.code, curoption, self.def_loc)
        self.def_loc += len(curoption)
        append(&self.generated_generics, curoption)
    }
}

gen_decl_array2d :: proc(self: ^Codegen, decl: union{VarDecl, ConstDecl, FnDecl}, t2d: Array) -> string {
    name: string
    type: Type
    const := false

    if d, ok := decl.(VarDecl); ok {
        name = d.name.literal
        type = d.type
    } else if d, ok := decl.(ConstDecl); ok {
        name = d.name.literal
        type = d.type
        const = true
    } else if d, ok := decl.(FnDecl); ok {
        name = d.name.literal
        type = d.type
    }

    gen_generic_decl(self, type)

    typename := strings.builder_make()
    defer delete(typename.buf)
    gen_typename(self, {type}, &typename)

    // T[N]
    type_str, type_str_alloced := gen_type(self, type)
    defer if type_str_alloced do delete(type_str)

    return fmt.aprintf("%v%v %v", strings.to_string(typename), " const" if const else "",name)
}

// returns allocated string, needs to be freed
gen_decl_array_proto :: proc(self: ^Codegen, decl: union{VarDecl, ConstDecl, FnDecl}) -> string {
    name: string
    type: Type
    const := false

    if d, ok := decl.(VarDecl); ok {
        name = d.name.literal
        type = d.type
    } else if d, ok := decl.(ConstDecl); ok {
        name = d.name.literal
        type = d.type
        const = true
    } else if d, ok := decl.(FnDecl); ok {
        name = d.name.literal
        type = d.type
    }

    if t, ok := type.(Array).type.(Array); ok {
        return gen_decl_array2d(self, decl, t)
    }

    gen_generic_decl(self, type)

    typename := strings.builder_make()
    defer delete(typename.buf)
    gen_typename(self, {type}, &typename)

    return fmt.aprintf("%v%v %v", strings.to_string(typename), " const" if const else "", name)
}

// returns allocated string, needs to be freed
gen_decl_option_proto :: proc(self: ^Codegen, decl: union{VarDecl, ConstDecl, FnDecl}) -> string {
    name: string
    type: Type
    const := false

    if d, ok := decl.(VarDecl); ok {
        name = d.name.literal
        type = d.type
    } else if d, ok := decl.(ConstDecl); ok {
        name = d.name.literal
        type = d.type
        const = true
    } else if d, ok := decl.(FnDecl); ok {
        name = d.name.literal
        type = d.type
    }

    gen_generic_decl(self, type)

    typename := strings.builder_make()
    defer delete(typename.buf)
    gen_typename(self, {type}, &typename)

    return fmt.aprintf("%v%v %v", strings.to_string(typename), " const" if const else "", name)
}

gen_var_decl :: proc(self: ^Codegen, vardecl: VarDecl) {
    proto := gen_decl_proto(self, vardecl)
    defer delete(proto)
    fmt.sbprintf(&self.code, "%v", proto)

    if vardecl.value == nil {
        if _, ok := vardecl.type.(Array); ok {
            fmt.sbprint(&self.code, " = ")

            value, alloced := gen_array_literal(self, Literal{
                values = [dynamic]Expr{},
                type = vardecl.type,
                cursors_idx = vardecl.cursors_idx
            })
            defer if alloced do delete(value)
            fmt.sbprintfln(&self.code, "%v;", value)
            return
        }

        fmt.sbprintln(&self.code, ";")
    } else {
        fmt.sbprint(&self.code, " = ")

        value, alloced := gen_expr(self, vardecl.value)
        defer if alloced do delete(value)
        fmt.sbprintfln(&self.code, "%v;", value)
    }
}

gen_var_reassign :: proc(self: ^Codegen, varre: VarReassign) {
    gen_indent(self)
    reassigned, reassigned_alloced := gen_expr(self, varre.name)
    defer if reassigned_alloced do delete(reassigned)

    value, value_alloced := gen_expr(self, varre.value)
    defer if value_alloced do delete(value)

    fmt.sbprintfln(&self.code, "%v = %v;", reassigned, value)
}

gen_const_decl :: proc(self: ^Codegen, constdecl: ConstDecl) {
    proto := gen_decl_proto(self, constdecl)
    defer delete(proto)

    fmt.sbprintf(&self.code, "%v = ", proto)

    if _, ok := constdecl.type.(Array); ok {
        value, alloced := gen_array_literal(self, Literal{
            values = [dynamic]Expr{},
            type = constdecl.type,
            cursors_idx = constdecl.cursors_idx
        })
        defer if alloced do delete(value)
        fmt.sbprintfln(&self.code, "%v;", value)
        return
    }

    value, alloced := gen_expr(self, constdecl.value)
    defer if alloced do delete(value)

    fmt.sbprintfln(&self.code, "%v;", value)
}

gen_return :: proc(self: ^Codegen, ret: Return) {
    gen_indent(self)
    value, alloced := gen_expr(self, ret.value)
    defer if alloced do delete(value)

    fmt.sbprintfln(&self.code, "return %v;", value)
}

gen_directive :: proc(self: ^Codegen, directive: Directive) {
    switch d in directive {
    case DirectiveLink:
        append(&self.linking, d.link)
    }
}

gen_c_necessities :: proc(self: ^Codegen) {
    fmt.sbprintln(&self.code, "#include <stdint.h>")
    fmt.sbprintln(&self.code, "#include <stddef.h>")
    fmt.sbprintln(&self.code, "#include <string.h>")
    fmt.sbprintln(&self.code, "#include <stdbool.h>")
    fmt.sbprintln(&self.code, 
`#if defined(__linux__) || defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__) || defined(__sun) || defined(__CYGWIN__)
#include <sys/types.h>
#elif defined(_WIN32) || defined(__MINGW32__)
#include <BaseTsd.h>
typedef SSIZE_T ssize_t;
#endif`
    )

    fmt.sbprintln(&self.code, "typedef int8_t i8;")
    fmt.sbprintln(&self.code, "typedef int16_t i16;")
    fmt.sbprintln(&self.code, "typedef int32_t i32;")
    fmt.sbprintln(&self.code, "typedef int64_t i64;")
    fmt.sbprintln(&self.code, "typedef ssize_t isize;")
    fmt.sbprintln(&self.code, "typedef uint8_t u8;")
    fmt.sbprintln(&self.code, "typedef uint16_t u16;")
    fmt.sbprintln(&self.code, "typedef uint32_t u32;")
    fmt.sbprintln(&self.code, "typedef uint64_t u64;")
    fmt.sbprintln(&self.code, "typedef size_t usize;")
    fmt.sbprintln(&self.code, "typedef float f32;")
    fmt.sbprintln(&self.code, "typedef double f64;")
    fmt.sbprintln(&self.code, 
`typedef struct CurString {
    const char *ptr;
    usize len;
} CurString;`
    )
    fmt.sbprintln(&self.code, "#define curstr(s) ((CurString){.ptr = s, strlen(s)})")
    // array
    fmt.sbprintln(&self.code, 
`#define CurArray1d(T, Tname, A)\
typedef struct CurArray1d_##Tname##A {\
    T *ptr;\
    usize len;\
} CurArray1d_##Tname##A;\
CurArray1d_##Tname##A curarray1d_##Tname##A(T *ptr, usize len) {\
    CurArray1d_##Tname##A ret;\
    ret.ptr = ptr;\
    ret.len = len;\
    return ret;\
}
#define CurArray2d(T, Tname, A, B)\
typedef struct CurArray2d_##Tname##B##A {\
    CurArray1d_##Tname##A* ptr;\
    usize len;\
} CurArray2d_##Tname##B##A;\
CurArray2d_##Tname##B##A curarray2d_##Tname##B##A(CurArray1d_##Tname##A *ptr, usize len) {\
    CurArray2d_##Tname##B##A ret;\
    ret.ptr = ptr;\
    ret.len = len;\
    return ret;\
}`
    )
    // option
    fmt.sbprintln(&self.code, 
`#define CurOption(T, Tname)\
typedef struct CurOption_##Tname {\
    T some;\
    bool ok;\
} CurOption_##Tname;\
CurOption_##Tname curoption_##Tname(T some) {\
    CurOption_##Tname ret;\
    ret.some = some;\
    ret.ok = true;\
    return ret;\
}\
CurOption_##Tname curoptionnull_##Tname() {\
    CurOption_##Tname ret;\
    ret.ok = false;\
    return ret;\
}`
    )
}

gen :: proc(self: ^Codegen) {
    gen_c_necessities(self)

    for statement in self.ast {
        #partial switch stmnt in statement {
        case Directive:
            gen_directive(self, stmnt)
        case Extern:
            gen_extern(self, stmnt)
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
