package main

import "core:fmt"
import "core:strings"
import "core:math/rand"
import "core:os"

OptLevel :: enum {
    Zero,
    One,
    Two,
    Three,
    Debug,
    Fast,
    Small,
}

CompileFlags :: struct {
    linking: [dynamic]string,
    output: string,
    optimisation: OptLevel,
}

Codegen :: struct {
    ast: [dynamic]Stmnt,

    code: strings.Builder,
    defs: strings.Builder,

    indent_level: u8,

    in_defs: bool,
    def_deps: Dgraph,
    def_loc: int,

    impl_loc: int,
    generated_generics: [dynamic]string,

    compile_flags: CompileFlags,
}

codegen_init :: proc(ast: [dynamic]Stmnt, def_deps: Dgraph) -> Codegen {
    return {
        ast = ast,

        code = strings.builder_make(),
        defs = strings.builder_make(),

        indent_level = 0,

        in_defs = false,
        def_deps = def_deps,
        def_loc = 0,

        impl_loc = 0,
        generated_generics = make([dynamic]string),

        compile_flags = {
            linking = make([dynamic]string),
            optimisation = .Debug,
        },
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

gen_write :: proc(self: ^Codegen, format: string, args: ..any) {
    if self.in_defs {
        fmt.sbprintf(&self.defs, format, ..args)
    } else {
        fmt.sbprintf(&self.code, format, ..args)
    }
}

gen_writeln :: proc(self: ^Codegen, format: string, args: ..any) {
    if self.in_defs {
        fmt.sbprintfln(&self.defs, format, ..args)
    } else {
        fmt.sbprintfln(&self.code, format, ..args)
    }
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
        #partial switch t in type {
        case Untyped_Int, Untyped_Float:
            panic("gen_typename not implemented yet")
        case Cstring:
            fmt.sbprintf(typename, "%v", "constcharptr")
        case Ptr:
            gen_typename(self, []Type{t.type^}, typename)

            fmt.sbprintf(typename, "ptr")
        case Array:
            curarray := gen_typename_array(self, type, 1)
            defer delete(curarray.buf)

            fmt.sbprintf(typename, "%v", strings.to_string(curarray))
        case Option:
            subtypename := strings.builder_make()
            defer delete(subtypename.buf)
            gen_typename(self, {t.type^}, &subtypename)

            fmt.sbprintf(typename, "CurOption_%v", strings.to_string(subtypename))
        case:
            ty, ty_alloc := gen_type(self, type)
            defer if ty_alloc do delete(ty)

            tn, tn_alloc := strings.remove_all(ty, " ")
            defer if tn_alloc do delete(tn)

            fmt.sbprintf(typename, "%v", tn)
        }
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
        return fmt.aprintf("%v*", gen_ptr_type(self, subtype.type^))
    case:
        t, _ := gen_type(self, ptr)
        return t
    }
}

gen_type :: proc(self: ^Codegen, t: Type) -> (string, bool) {
    gen_generic_decl(self, t)

    if type_tag_equal(t, Untyped_Int{}) {
        panic("compiler error: should not be converting untyped_int to string")
    } else if type_tag_equal(t, Untyped_Float{}) {
        panic("compiler error: should not be converting untyped_float to string")
    }

    #partial switch subtype in t {
    case Array:
        ret := strings.builder_make()
        gen_array_type(self, t, &ret)
        return strings.to_string(ret), true
    case Option:
        ret := strings.builder_make()
        option_type, alloced := gen_type(self, subtype.type^)
        defer if alloced do delete(option_type)

        return fmt.sbprintf(&ret, "CurOption_%v", option_type), true
    case Ptr:
        return gen_ptr_type(self, t), true
    case Cstring:
        return "const char*", false
    case String:
        return "CurString", false
    case Char:
        // TODO: make this be a type that supports utf8
        return "u8", false
    case TypeDef:
        return subtype.name, false
    }

    for k, v in type_map {
        if type_tag_equal(t, v) {
            return k, false
        }
    }
    return "", false
}
gen_extern :: proc(self: ^Codegen, extern: Extern) {
    #partial switch stmnt in extern.body {
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

gen_indent :: proc(self: ^Codegen) {
    for i in 0..<self.indent_level {
        gen_write(self, "    ")
    }
}

gen_block :: proc(self: ^Codegen, block: [dynamic]Stmnt) {
    gen_writeln(self, "{{")
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
            gen_writeln(self, "")
        case FnDecl:
            gen_fn_decl(self, stmnt)
        case StructDecl:
            // do nothing, defs will be resolved later
        case EnumDecl:
            // do nothing, defs will be resolved later
        case VarDecl:
            gen_var_decl(self, stmnt)
        case ConstDecl:
            gen_const_decl(self, stmnt)
        case VarReassign:
            gen_var_reassign(self, stmnt)
        case Return:
            gen_return(self, stmnt)
        case Continue:
            gen_continue(self)
        case Break:
            gen_break(self)
        case FnCall:
            call := gen_fn_call(self, stmnt, true)
            defer delete(call)

            gen_writeln(self, "%v;", call)
        case If:
            gen_if(self, stmnt)
        case For:
            gen_for(self, stmnt)
        }
    }

    self.indent_level -= 1
    gen_indent(self)
    gen_writeln(self, "}}")
}

gen_if :: proc(self: ^Codegen, ifs: If) {
    gen_indent(self)

    condition, alloced := gen_expr(self, ifs.condition)
    defer if alloced do delete(condition)

    if capture, ok := ifs.capture.?; ok {
        gen_writeln(self, "{{")
        self.indent_level += 1

        proto := gen_decl_proto(self, capture.(ConstDecl))
        defer delete(proto)

        gen_writeln(self, "%v = %v.some;", proto, condition)
        gen_indent(self)
        gen_write(self, "if (%v.ok) ", condition)
    } else {
        gen_write(self, "if (%v) ", condition)
    }


    gen_block(self, ifs.body)
    strings.pop_byte(&self.code)

    gen_write(self, " else ")
    gen_block(self, ifs.els)

    if _, ok := ifs.capture.?; ok {
        self.indent_level -= 1
        gen_indent(self)
        gen_writeln(self, "}}")
    }
}

gen_for :: proc(self: ^Codegen, forl: For) {
    gen_indent(self)

    gen_writeln(self, "{{")
    self.indent_level += 1

    gen_var_decl(self, forl.decl)

    condition, condition_alloc := gen_expr(self, forl.condition)
    defer if condition_alloc do delete(condition)

    reassigned, reassigned_alloced := gen_expr(self, forl.reassign.name)
    defer if reassigned_alloced do delete(reassigned)

    value, value_alloced := gen_expr(self, forl.reassign.value)
    defer if value_alloced do delete(value)

    gen_indent(self)
    gen_write(self, "for (; %v; %v = %v) ", condition, reassigned, value)
    gen_block(self, forl.body)

    self.indent_level -= 1
    gen_indent(self)
    gen_writeln(self, "}}")
}

// returns allocated string, needs to be freed
@(require_results)
gen_decl_proto :: proc(self: ^Codegen, decl: union{VarDecl, ConstDecl, FnDecl}) -> string {
    name: string
    type: Type

    if d, ok := decl.(VarDecl); ok {
        name = d.name.literal
        type = d.type
    } else if d, ok := decl.(ConstDecl); ok {
        name = d.name.literal
        type = d.type
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

    return fmt.aprintf("%v %v", var_type_str, name)
}

gen_struct_decl :: proc(self: ^Codegen, structd: StructDecl) {
    struct_def := fmt.aprintf("struct %v", structd.name.literal)
    for generated in self.generated_generics {
        if generated == struct_def {
            delete(struct_def)
            return
        }
    }
    append(&self.generated_generics, struct_def)

    self.def_loc = len(self.defs.buf)
    gen_indent(self)

    self.in_defs = true

    gen_write(self, "%v", struct_def)
    gen_block(self, structd.fields)
    gen_writeln(self, ";")

    self.in_defs = false
}

gen_enum_decl :: proc(self: ^Codegen, enumd: EnumDecl) {
    enum_def := fmt.aprintf("enum %v", enumd.name.literal)
    for generated in self.generated_generics {
        if generated == enum_def {
            delete(enum_def)
            return
        }
    }
    append(&self.generated_generics, enum_def)

    self.def_loc = len(self.defs.buf)
    gen_indent(self)

    self.in_defs = true

    gen_writeln(self, "%v {{", enum_def)
    self.indent_level += 1
    for field in enumd.fields {
        f := field.(ConstDecl)

        expr, alloced := gen_expr(self, f.value)
        defer if alloced do delete(expr)

        gen_indent(self)
        gen_writeln(self, "%v = %v,", f.name.literal, expr)
    }
    self.indent_level -= 1
    gen_writeln(self, "}};")

    self.in_defs = false
}

gen_fn_decl :: proc(self: ^Codegen, fndecl: FnDecl, is_extern := false) {
    self.impl_loc = len(self.code.buf)
    self.def_loc = len(self.defs.buf)
    gen_indent(self)

    if fndecl.name.literal == "main" {
        gen_write(self, "int main() ")
        gen_block(self, fndecl.body)
        return
    }

    proto := gen_decl_proto(self, fndecl)
    defer delete(proto)

    code := strings.builder_make()
    defer delete(code.buf)

    fmt.sbprintf(&code, "%v(", proto)

    for stmnt, i in fndecl.args {
        arg := stmnt.(ConstDecl)
        arg_proto := gen_decl_proto(self, arg)
        defer delete(arg_proto)

        if i == 0 {
            fmt.sbprintf(&code, "%v", arg_proto)
        } else {
            fmt.sbprintf(&code, ", %v", arg_proto)
        }
    }
    fmt.sbprint(&code, ")")

    self.in_defs = true;
    gen_writeln(self, "%v;", strings.to_string(code))
    self.in_defs = false;

    if fndecl.has_body {
        gen_write(self, "%v ", strings.to_string(code))
        gen_block(self, fndecl.body)
    } else if !is_extern {
        gen_writeln(self, "%v;", strings.to_string(code))
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

    for val, i in expr.values.([dynamic]Expr) {
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

        return fmt.aprintf("%v", internal_int_cast(expr.type, expr.literal)), true
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

        return fmt.aprintf("%v", internal_int_cast(expr.type, expr.literal)), true
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
        ret: string

        if _, ok := expr.expr_type.(Ptr); ok {
            ret = fmt.aprintf("%v->%v", subexpr, field)
        } else {
            ret = fmt.aprintf("%v.%v", subexpr, field)
        }

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

        if values, ok := expr.values.([dynamic]Expr); ok {
            for val, i in values {
                str_val, alloced := gen_expr(self, val)
                defer if alloced do delete(str_val)

                if i == 0 {
                    fmt.sbprintf(&literal, "%v", str_val)
                } else {
                    fmt.sbprintf(&literal, ", %v", str_val)
                }
            }
        } else {
            values := expr.values.([dynamic]VarReassign)
            for val, i in values {
                reassigned, reassigned_alloced := gen_expr(self, val.name)
                defer if reassigned_alloced do delete(reassigned)

                value, value_alloced := gen_expr(self, val.value)
                defer if value_alloced do delete(value)

                if i == 0 {
                    fmt.sbprintf(&literal, ".%v = %v", reassigned, value)
                } else {
                    fmt.sbprintf(&literal, ", .%v = %v", reassigned, value)
                }
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
                    if strings.to_string(curarray) == generics {
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
            fmt.sbprintfln(&curarray, "CurArray1dDef(%v, %v, %v);", type_str, strings.to_string(typename), length)

            for generics in self.generated_generics {
                if strings.to_string(curarray) == generics {
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
        fmt.sbprintf(&curarray, "CurArray%vdDef(%v, %v", dimension, type_str, strings.to_string(typename))
        return curarray, true
    }
}

gen_generic_decl :: proc(self: ^Codegen, type: Type) {
    #partial switch t in type {
    case Array:
        curarray_def, add := gen_generic_array_decl(self, t, 1)
        curarray_impl, alloced := strings.replace(strings.to_string(curarray_def), "Def", "Impl", 1)

        if add {
            self.defs = sbinsert(&self.defs, strings.to_string(curarray_def), self.def_loc)
            self.code = sbinsert(&self.code, curarray_impl, self.impl_loc)

            self.def_loc += len(strings.to_string(curarray_def))
            self.impl_loc += len(curarray_impl)

            append(&self.generated_generics, strings.to_string(curarray_def))
        } else {
            delete(curarray_def.buf)
            if alloced do delete(curarray_impl)
        }
    case Option:
        type_str, type_str_alloc := gen_type(self, t.type^)
        defer if type_str_alloc do delete(type_str)

        typename := strings.builder_make()
        defer delete(typename.buf)
        gen_typename(self, {t.type^}, &typename)

        curoption_def := fmt.aprintfln("CurOptionDef(%v, %v);", type_str, strings.to_string(typename))
        curoption_impl, alloced := strings.replace(curoption_def, "Def", "Impl", 1)

        for generics in self.generated_generics {
            if curoption_def == generics {
                delete(curoption_def)
                if alloced do delete(curoption_impl)
                return
            }
        }

        self.defs = sbinsert(&self.defs, curoption_def, self.def_loc)
        self.code = sbinsert(&self.code, curoption_impl, self.impl_loc)

        self.def_loc += len(curoption_def)
        self.impl_loc += len(curoption_impl)
        append(&self.generated_generics, curoption_def)
    case TypeDef:
        // NOTE: no generics right now, just for forward declaration
        // TODO: add typedef generics
        typedef: string

        stmnt, _ := ast_find_decl(self.ast, t.name)
        if _, ok := stmnt.(StructDecl); ok {
            typedef = fmt.aprintfln("typedef struct %v %v;", t.name, t.name)
        } else if _, ok := stmnt.(EnumDecl); ok {
            typedef = fmt.aprintfln("typedef enum %v %v;", t.name, t.name)
        }

        for generic in self.generated_generics {
            if typedef == generic {
                delete(typedef)
                return
            }
        }

        self.defs = sbinsert(&self.defs, typedef, self.def_loc)
        self.def_loc += len(typedef)
        append(&self.generated_generics, typedef)
    }
}

gen_decl_array2d :: proc(self: ^Codegen, decl: union{VarDecl, ConstDecl, FnDecl}, t2d: Array) -> string {
    name: string
    type: Type

    if d, ok := decl.(VarDecl); ok {
        name = d.name.literal
        type = d.type
    } else if d, ok := decl.(ConstDecl); ok {
        name = d.name.literal
        type = d.type
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

    return fmt.aprintf("%v %v", strings.to_string(typename), name)
}

// returns allocated string, needs to be freed
gen_decl_array_proto :: proc(self: ^Codegen, decl: union{VarDecl, ConstDecl, FnDecl}) -> string {
    name: string
    type: Type

    if d, ok := decl.(VarDecl); ok {
        name = d.name.literal
        type = d.type
    } else if d, ok := decl.(ConstDecl); ok {
        name = d.name.literal
        type = d.type
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

    return fmt.aprintf("%v %v", strings.to_string(typename), name)
}

// returns allocated string, needs to be freed
gen_decl_option_proto :: proc(self: ^Codegen, decl: union{VarDecl, ConstDecl, FnDecl}) -> string {
    name: string
    type: Type

    if d, ok := decl.(VarDecl); ok {
        name = d.name.literal
        type = d.type
    } else if d, ok := decl.(ConstDecl); ok {
        name = d.name.literal
        type = d.type
    } else if d, ok := decl.(FnDecl); ok {
        name = d.name.literal
        type = d.type
    }

    gen_generic_decl(self, type)

    typename := strings.builder_make()
    defer delete(typename.buf)
    gen_typename(self, {type}, &typename)

    return fmt.aprintf("%v %v", strings.to_string(typename), name)
}

gen_var_decl :: proc(self: ^Codegen, vardecl: VarDecl) {
    proto := gen_decl_proto(self, vardecl)
    defer delete(proto)
    gen_write(self, "%v", proto)

    if vardecl.value == nil {
        if _, ok := vardecl.type.(Array); ok {
            gen_write(self, " = ")

            value, alloced := gen_array_literal(self, Literal{
                values = [dynamic]Expr{},
                type = vardecl.type,
                cursors_idx = vardecl.cursors_idx
            })
            defer if alloced do delete(value)

            gen_writeln(self, "%v;", value)
            return
        }

        gen_writeln(self, ";")
    } else {
        gen_write(self, " = ")

        value, alloced := gen_expr(self, vardecl.value)
        defer if alloced do delete(value)
        gen_writeln(self, "%v;", value)
    }
}

gen_var_reassign :: proc(self: ^Codegen, varre: VarReassign) {
    gen_indent(self)
    reassigned, reassigned_alloced := gen_expr(self, varre.name)
    defer if reassigned_alloced do delete(reassigned)

    value, value_alloced := gen_expr(self, varre.value)
    defer if value_alloced do delete(value)

    gen_writeln(self, "%v = %v;", reassigned, value)
}

gen_const_decl :: proc(self: ^Codegen, constdecl: ConstDecl) {
    proto := gen_decl_proto(self, constdecl)
    defer delete(proto)

    gen_write(self, "%v = ", proto)

    value, alloced := gen_expr(self, constdecl.value)
    defer if alloced do delete(value)

    gen_writeln(self, "%v;", value)
}

gen_return :: proc(self: ^Codegen, ret: Return) {
    gen_indent(self)
    if ret.value == nil {
        gen_writeln(self, "return;")
        return
    }

    value, alloced := gen_expr(self, ret.value)
    defer if alloced do delete(value)

    gen_writeln(self, "return %v;", value)
}

gen_continue :: proc(self: ^Codegen) {
    gen_indent(self)
    gen_writeln(self, "continue;")
}

gen_break :: proc(self: ^Codegen) {
    gen_indent(self)
    gen_writeln(self, "break;")
}

gen_directive :: proc(self: ^Codegen, directive: Directive) {
    switch d in directive {
    case DirectiveLink:
        append(&self.compile_flags.linking, strings.clone(d.link))
    case DirectiveSysLink:
        l := fmt.aprintf("-l%v", d.link)
        append(&self.compile_flags.linking, l)
    case DirectiveOutput:
        self.compile_flags.output = d.name
    case DirectiveO0:
        self.compile_flags.optimisation = .Zero
    case DirectiveO1:
        self.compile_flags.optimisation = .One
    case DirectiveO2:
        self.compile_flags.optimisation = .Two
    case DirectiveO3:
        self.compile_flags.optimisation = .Three
    case DirectiveOdebug:
        self.compile_flags.optimisation = .Debug
    case DirectiveOfast:
        self.compile_flags.optimisation = .Fast
    case DirectiveOsmall:
        self.compile_flags.optimisation = .Small
    }
}

gen_resolve_def :: proc(self: ^Codegen, node: Dnode) {
    for child_name in node.children {
        gen_resolve_def(self, self.def_deps.children[child_name])
    }

    statement := node.us
    #partial switch stmnt in statement {
    case StructDecl:
        gen_struct_decl(self, stmnt)
    case EnumDecl:
        gen_enum_decl(self, stmnt)
    }
}

gen_resolve_defs ::proc(self: ^Codegen) {
    for _, def in self.def_deps.children {
        gen_resolve_def(self, def)
    }
}

gen :: proc(self: ^Codegen) {
    // TODO: this won't work if current is called from another directory, fix it
    defs_slice, _ := os.read_entire_file("./src/current_builtin_defs.txt")
    defer delete(defs_slice)
    defs := transmute(string)defs_slice

    fmt.sbprintf(&self.defs, "%v", defs)
    fmt.sbprintln(&self.code, "#include \"output.h\"")

    for statement in self.ast {
        #partial switch stmnt in statement {
        case Directive:
            gen_directive(self, stmnt)
        case Extern:
            gen_extern(self, stmnt)
        case FnDecl:
            gen_fn_decl(self, stmnt)
        case StructDecl:
            // do nothing, defs will be resolved later
        case VarDecl:
            gen_var_decl(self, stmnt)
        case ConstDecl:
            gen_const_decl(self, stmnt)
        case VarReassign:
            gen_var_reassign(self, stmnt)
        }
    }

    gen_resolve_defs(self)

    fmt.sbprintln(&self.defs, "#endif // CURRENT_DEFS_H")
}
