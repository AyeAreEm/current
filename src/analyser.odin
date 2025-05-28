package main

import "core:fmt"
import "core:os"
import "core:strings"

SymTab :: struct {
    keys: [dynamic][dynamic]Expr,
    values: [dynamic][dynamic]Stmnt,
    curr_scope: uint,
}

symtab_init :: proc() -> (symtab: SymTab) {
    symtab.keys = [dynamic][dynamic]Expr{}
    symtab.values = [dynamic][dynamic]Stmnt{}

    append(&symtab.keys, [dynamic]Expr{})
    append(&symtab.values, [dynamic]Stmnt{})
    symtab.curr_scope = 0
    return
}

sym_equals :: proc(lhs: Expr, rhs: Expr) -> bool {
    #partial switch el in lhs {
    case Ident:
        if k, ok := rhs.(Ident); ok {
            return strings.compare(k.literal, el.literal) == 0
        }
    case FieldAccess:
        if k, ok := rhs.(FieldAccess); ok {
            return sym_equals(k.expr^, el.expr^) && sym_equals(k.field^, el.field^)
        }
    case ArrayIndex:
        if r, ok := rhs.(ArrayIndex); ok {
            return sym_equals(el.ident^, r.ident^)
        }
        
        return false
    }

    return false
}

symtab_find_key :: proc(analyser: ^Analyser, key: Expr, location: int) -> Expr {
    using analyser.symtab

    for elem, i in keys[curr_scope] {
        if sym_equals(elem, key) {
            return elem
        }
    }

    elog(analyser, location, "use of undefined \"%v\"", key)
}

symtab_find :: proc(analyser: ^Analyser, key: Expr, location: int) -> Stmnt {
    using analyser.symtab

    index := -1
    for elem, i in keys[curr_scope] {
        if sym_equals(elem, key) {
            index = i
            break
        }
    }

    if index == -1 {
        elog(analyser, location, "use of undefined \"%v\"", key)
    }

    return values[curr_scope][index]
}

symtab_push :: proc(analyser: ^Analyser, key: Expr, value: Stmnt) {
    using analyser.symtab

    found := false
    elem: Expr
    for elem, i in keys[curr_scope] {
        if sym_equals(elem, key) {
            found = true
            break
        }
    }

    if found  {
        cur_index := get_cursor_index(elem)
        elog(analyser, get_cursor_index(value), "redeclaration of \"%v\" from %v:%v", key, analyser.cursors[cur_index][0], analyser.cursors[cur_index][1])
    }

    append(&keys[curr_scope], key)
    append(&values[curr_scope], value)
}

symtab_new_scope :: proc(analyser: ^Analyser) {
    using analyser.symtab

    scope_keys := [dynamic]Expr{}
    scope_values := [dynamic]Stmnt{}
    for key in keys[curr_scope] {
        append(&scope_keys, key)
    }
    for value in values[curr_scope] {
        append(&scope_values, value)
    }

    append(&keys, scope_keys)
    append(&values, scope_values)
    curr_scope += 1
}

symtab_pop_scope :: proc(analyser: ^Analyser) {
    using analyser.symtab

    pop(&keys)
    pop(&values)
    curr_scope -= 1
}

Analyser :: struct {
    ast: [dynamic]Stmnt,
    symtab: SymTab,
    current_fn: Maybe(FnDecl),

    compile_flags: struct {
        output: bool,
        optimise: bool,
    },

    // debug
    filename: string,
    cursors: [dynamic][2]u32,
}

analyser_init :: proc(ast: [dynamic]Stmnt, filename: string, cursors: [dynamic][2]u32) -> Analyser {
    return {
        ast = ast,
        symtab = symtab_init(),
        current_fn = nil,
        
        filename = filename,
        cursors = cursors,
    }
}

type_of_expr :: proc(analyser: ^Analyser, expr: ^Expr) -> ^Type {
    switch &ex in expr {
    case Null:
        return &ex.type
    case CstrLit:
        return &ex.type
    case StrLit:
        return &ex.type
    case CharLit:
        return &ex.type
    case Address:
        return &ex.type
    case Literal:
        return &ex.type
    case Bool, Char, String, Cstring,
         I8, I16, I32, I64, Isize,
         U8, U16, U32, U64, Usize,
         F32, F64:

        index := get_cursor_index(ex)
        elog(analyser, index, "not implemented, can't return type from a type right now")
    case Negative:
        return &ex.type
    case Grouping:
        return &ex.type
    case IntLit:
        return &ex.type
    case FloatLit:
        return &ex.type
    case FieldAccess:
        if ex.type != nil {
            if ex.deref {
                return tc_deref_ptr(analyser, &ex.type)
            }
            return &ex.type
        }

        decl := symtab_find(analyser, ex.expr^, ex.cursors_idx)
        if var, ok := decl.(VarDecl); ok {
            ex.type = var.type
        } else if var, ok := decl.(ConstDecl); ok {
            ex.type = var.type
        } else {
            elog(analyser, ex.cursors_idx, "expected a variable or constant, got %v", decl)
        }
        return &ex.type
    case ArrayIndex:
        return &ex.type
    case Ident:
        if ex.type != nil {
            return &ex.type
        }

        decl := symtab_find(analyser, ex, ex.cursors_idx)
        if var, ok := decl.(VarDecl); ok {
            ex.type = var.type
        } else if var, ok := decl.(ConstDecl); ok {
            ex.type = var.type
        } else {
            elog(analyser, ex.cursors_idx, "expected ident to be a variable or constant, got %v", decl)
        }
        return &ex.type
    case FnCall:
        call := symtab_find(analyser, ex.name, ex.cursors_idx).(FnDecl)
        ex.type = call.type
        return &ex.type
    case LessThan:
        return &ex.type
    case LessOrEqual:
        return &ex.type
    case GreaterThan:
        return &ex.type
    case GreaterOrEqual:
        return &ex.type
    case Equality:
        return &ex.type
    case Inequality:
        return &ex.type
    case Not:
        return &ex.type
    case Plus:
        return &ex.type
    case Minus:
        return &ex.type
    case Multiply:
        return &ex.type
    case Divide:
        return &ex.type
    case True:
        return &ex.type
    case False:
        return &ex.type
    }

    panic("can't get the type of a non-expression in type_of_expr()")
}

get_field :: proc(analyser: ^Analyser, type: Type, field: Expr, cursor_index: int) -> Expr {
    #partial switch t in type {
    case String:
        index := 0
        found := false
        for f, i in String_fields {
            if sym_equals(field, f) {
                found = true
                index = i
                break
            }
        }

        if found {
            return String_fields[index]
        }

        elog(analyser, cursor_index, "string does not have field %v", field)
    case Array:
        index := 0
        found := false
        for f, i in Array_fields {
            if sym_equals(field, f) {
                found = true
                index = i
                break
            }
        }

        if found {
            return Array_fields[index]
        }

        elog(analyser, cursor_index, "array does not have field %v", field)
    case:
        elog(analyser, cursor_index, "primitive type does not have field %v", field)
    }
}

stmnt_is_constant :: proc(analyser: ^Analyser, statement: Stmnt) -> bool {
    #partial switch stmnt in statement {
    case ConstDecl:
        return true
    case VarDecl:
        return false
    case:
        elog(analyser, get_cursor_index(statement), "should not be checking constness of %v", statement)
    }
}

type_of_stmnt :: proc(using analyser: ^Analyser, statement: Stmnt) -> Type {
    switch stmnt in statement {
    case FnDecl:
        return stmnt.type
    case FnCall:
        return stmnt.type
    case VarDecl:
        return stmnt.type
    case VarReassign:
        return stmnt.type
    case ConstDecl:
        return stmnt.type
    case Return:
        return stmnt.type
    case Block:
        elog(analyser, stmnt.cursors_idx, "unexpected scope block")
    case If:
        elog(analyser, stmnt.cursors_idx, "unexpected if statement")
    case For:
        elog(analyser, stmnt.cursors_idx, "unexpected for loop")
    case Extern:
        elog(analyser, stmnt.cursors_idx, "unexpected extern statement")
    case Directive:
        elog(analyser, get_cursor_index(cast(Stmnt)stmnt), "unexpected directive")
    }

    return nil
}

analyse_elog :: proc(self: ^Analyser, i: int, format: string, args: ..any) -> ! {
    if DEBUG_MODE {
        debug("elog from analyser")
    }
    fmt.eprintf("%v:%v:%v \x1b[91;1merror\x1b[0m: ", self.filename, self.cursors[i][0], self.cursors[i][1])
    fmt.eprintfln(format, ..args)

    os.exit(1)
}

analyse_literal :: proc(self: ^Analyser, literal: ^Literal) {
    for &value in literal.values {
        analyse_expr(self, &value)
    }

    tc_literal(self, literal)
}

analyse_field_access :: proc(self: ^Analyser, expr: ^FieldAccess) {
    analyse_expr(self, expr.expr)

    type := type_of_expr(self, expr.expr)
    if !expr.deref {
        field := get_field(self, type^, expr.field^, expr.cursors_idx)
        expr.field^ = field
        expr.type = type_of_expr(self, &field)^
        analyse_expr(self, expr.field)
        return
    }

    // dereferencing
    if t, ok := type.(Ptr); ok {
        expr.type = tc_deref_ptr(self, type)^
        expr.constant = t.constant
    } else {
        elog(self, expr.cursors_idx, "cannot derefernce %v, not a pointer", type^)
    }
}

analyse_array_index :: proc(self: ^Analyser, expr: ^ArrayIndex) {
    analyse_expr(self, expr.ident)
    arrtype := type_of_expr(self, expr.ident)

    if arr, ok := arrtype.(Array); ok {
        expr.type = arr.type^
    } else {
        elog(self, expr.cursors_idx, "cannot index into %v, not an array", arrtype^)
    }

    analyse_expr(self, expr.index)
}

analyse_expr :: proc(self: ^Analyser, expr: ^Expr) {
    switch &ex in expr {
    case FieldAccess:
        analyse_field_access(self, &ex)
    case ArrayIndex:
        analyse_array_index(self, &ex)
    case I8, I16, I32, I64, Isize:
        return
    case U8, U16, U32, U64, Usize:
        return
    case F32, F64:
        return
    case Bool:
        return
    case Char:
        return
    case String:
        return
    case Cstring:
        return
    case Address:
        analyse_expr(self, ex.value)

        #partial switch &addr_expr in ex.value {
        case Ident:
            stmnt := symtab_find(self, addr_expr, addr_expr.cursors_idx)
            type := new(Type); type^ = type_of_stmnt(self, stmnt)
            ex.type = Ptr{
                type = type,
                constant = stmnt_is_constant(self, stmnt)
            }
            ex.to_constant = stmnt_is_constant(self, stmnt)
        case:
            elog(self, ex.cursors_idx, "can't take address of {}", ex.value^)
        }
    case Literal:
        analyse_literal(self, &ex)
    case FnCall:
        analyse_fn_call(self, &ex)
    case Ident:
        if ex.type != nil {
            return
        }

        stmnt_vardecl := symtab_find(self, ex, ex.cursors_idx)
        if decl, ok := stmnt_vardecl.(VarDecl); ok {
            ex.type = decl.type
        } else if decl, ok := stmnt_vardecl.(ConstDecl); ok {
            ex.type = decl.type
        } else {
            elog(self, ex.cursors_idx, "expected \"%v\" to be a variable, got %v", ex.literal, stmnt_vardecl)
        }
    case IntLit:
        return
    case FloatLit:
        return
    case CharLit:
        length := 0
        for elem in ex.literal {
            length += 1
        }

        if length > 1 {
            elog(self, ex.cursors_idx, "character literal cannot be more than one character")
        }
    case StrLit:
        ex.len = len(ex.literal)
    case CstrLit:
        ex.len = len(ex.literal)
    case True, False, Null:
        return
    case Grouping:
        analyse_expr(self, ex.value)
        value_type := type_of_expr(self, ex.value)

        ex.type = value_type^
    case Negative:
        analyse_expr(self, ex.value)

        if tc_is_unsigned(self, ex.value^) {
            elog(self, ex.cursors_idx, "cannot negate unsigned integers")
        }

        value_type := type_of_expr(self, ex.value)
        ex.type = value_type^
    case Not:
        analyse_expr(self, ex.condition)
        t := type_of_expr(self, ex.condition)

        if !tc_equals(self, Bool{}, t) {
            elog(self, ex.cursors_idx, "expected a boolean after '!' operator, got %v", t)
        }
    // you may be asking "hey... wtf... why don't you do `case Equality, Inequality:`"
    // best believe i tried, odin just doesn't let you because `ex.left` cannot be used
    // since one of those types (Equality, Inequality) may not have a left field, EVEN THO THEY DO
    // so there's no duck typing and I have to fully separate them, even tho the ONLY difference
    // in the code block is the error message using "==" or "!="
    case Equality:
        analyse_expr(self, ex.left)
        analyse_expr(self, ex.right)

        lt := type_of_expr(self, ex.left)
        rt := type_of_expr(self, ex.right)
        if !tc_equals(self, lt^, rt) {
            elog(self, ex.cursors_idx, "mismatch types, %v == %v", lt, rt)
        }

        if !tc_can_compare_value(self, lt^, rt^) {
            elog(self, ex.cursors_idx, "cannot compare %v and %v", lt, rt)
        }
    case Inequality:
        analyse_expr(self, ex.left)
        analyse_expr(self, ex.right)

        lt := type_of_expr(self, ex.left)
        rt := type_of_expr(self, ex.right)
        if !tc_equals(self, lt^, rt) {
            elog(self, ex.cursors_idx, "mismatch types, %v != %v", lt, rt)
        }

        if !tc_can_compare_value(self, lt^, rt^) {
            elog(self, ex.cursors_idx, "cannot compare %v and %v", lt, rt)
        }
    case LessThan:
        analyse_expr(self, ex.left)
        analyse_expr(self, ex.right)

        lt := type_of_expr(self, ex.left)
        rt := type_of_expr(self, ex.right)
        if !tc_equals(self, lt^, rt) {
            elog(self, ex.cursors_idx, "mismatch types, %v < %v", lt, rt)
        }

        if !tc_can_compare_order(self, lt^, rt^) {
            elog(self, ex.cursors_idx, "cannot compare %v and %v", lt, rt)
        }
    case LessOrEqual:
        analyse_expr(self, ex.left)
        analyse_expr(self, ex.right)

        lt := type_of_expr(self, ex.left)
        rt := type_of_expr(self, ex.right)
        if !tc_equals(self, lt^, rt) {
            elog(self, ex.cursors_idx, "mismatch types, %v <= %v", lt, rt)
        }

        if !tc_can_compare_order(self, lt^, rt^) {
            elog(self, ex.cursors_idx, "cannot compare %v and %v", lt, rt)
        }
    case GreaterThan:
        analyse_expr(self, ex.left)
        analyse_expr(self, ex.right)

        lt := type_of_expr(self, ex.left)
        rt := type_of_expr(self, ex.right)
        if !tc_equals(self, lt^, rt) {
            elog(self, ex.cursors_idx, "mismatch types, %v > %v", lt, rt)
        }

        if !tc_can_compare_order(self, lt^, rt^) {
            elog(self, ex.cursors_idx, "cannot compare %v and %v", lt, rt)
        }
    case GreaterOrEqual:
        analyse_expr(self, ex.left)
        analyse_expr(self, ex.right)

        lt := type_of_expr(self, ex.left)
        rt := type_of_expr(self, ex.right)
        if !tc_equals(self, lt^, rt) {
            elog(self, ex.cursors_idx, "mismatch types, %v >= %v", lt, rt)
        }

        if !tc_can_compare_order(self, lt^, rt^) {
            elog(self, ex.cursors_idx, "cannot compare %v and %v", lt, rt)
        }
    case Plus:
        analyse_expr(self, ex.left)
        analyse_expr(self, ex.right)

        lt := type_of_expr(self, ex.left)
        rt := type_of_expr(self, ex.right)
        if !tc_equals(self, lt^, rt) {
            elog(self, ex.cursors_idx, "mismatch types, %v + %v", lt, rt)
        }

        _, lt_ok := lt.(Untyped_Int)
        _, rt_ok := rt.(Untyped_Int)

        if lt_ok && rt_ok {
            ex.type = lt^
        } else if rt_ok {
            ex.type = lt^
        } else {
            ex.type = rt^
        }

    case Minus:
        analyse_expr(self, ex.left)
        analyse_expr(self, ex.right)

        lt := type_of_expr(self, ex.left)
        rt := type_of_expr(self, ex.right)
        if !tc_equals(self, lt^, rt) {
            elog(self, ex.cursors_idx, "mismatch types, %v - %v", lt, rt)
        }

        _, lt_ok := lt.(Untyped_Int)
        _, rt_ok := rt.(Untyped_Int)

        if lt_ok && rt_ok {
            ex.type = lt^
        } else if rt_ok {
            ex.type = lt^
        } else {
            ex.type = rt^
        }
    case Multiply:
        analyse_expr(self, ex.left)
        analyse_expr(self, ex.right)

        lt := type_of_expr(self, ex.left)
        rt := type_of_expr(self, ex.right)
        if !tc_equals(self, lt^, rt) {
            elog(self, ex.cursors_idx, "mismatch types, %v * %v", lt, rt)
        }

        _, lt_ok := lt.(Untyped_Int)
        _, rt_ok := rt.(Untyped_Int)

        if lt_ok && rt_ok {
            ex.type = lt^
        } else if rt_ok {
            ex.type = lt^
        } else {
            ex.type = rt^
        }
    case Divide:
        analyse_expr(self, ex.left)
        analyse_expr(self, ex.right)

        lt := type_of_expr(self, ex.left)
        rt := type_of_expr(self, ex.right)
        if !tc_equals(self, lt^, rt) {
            elog(self, ex.cursors_idx, "mismatch types, %v / %v", lt, rt)
        }

        _, lt_ok := lt.(Untyped_Int)
        _, rt_ok := rt.(Untyped_Int)

        if lt_ok && rt_ok {
            ex.type = lt^
        } else if rt_ok {
            ex.type = lt^
        } else {
            ex.type = rt^
        }
    }
}

analyse_return :: proc(self: ^Analyser, fn: FnDecl, ret: ^Return) {
    analyse_expr(self, &ret.value)

    tc_return(self, fn, ret)
}

analyse_var_decl :: proc(self: ^Analyser, vardecl: ^VarDecl) {
    #partial switch &val in vardecl.value {
    case Literal:
        if val.type == nil {
            if vardecl.type == nil {
                // <name> := {..}; can't do that
                elog(self, vardecl.cursors_idx, "missing type for literal")
            } else {
                // <name>: <type> = {..};
                val.type = vardecl.type
            }
        } else if vardecl.type != nil {
            // <name>: <type> = <type>{..};
            if !tc_equals(self, vardecl.type, &val.type) {
                elog(self, vardecl.cursors_idx, "mismatch types, variable \"%v\" type %v, expression type %v", vardecl.name, vardecl.type, val.type)
            }
        } else {
            // <name> := <type>{..};
            vardecl.type = val.type
        }
    }

    analyse_expr(self, &vardecl.value)

    tc_var_decl(self, vardecl)

    symtab_push(self, vardecl.name, vardecl^)
}

analyse_var_reassign :: proc(self: ^Analyser, varre: ^VarReassign) {
    analyse_expr(self, &varre.name)
    analyse_expr(self, &varre.value)
    value_type := type_of_expr(self, &varre.value)

    if re, ok := varre.name.(FieldAccess); ok {
        if re.constant {
            elog(self, varre.cursors_idx, "cannot mutate constant variable \"%v\"", varre.name)
        }

        varre.type = re.type
        if !tc_equals(self, varre.type, value_type) {
            elog(self, varre.cursors_idx, "mismatch types, variable \"%v\" type %v, expression type %v", varre.name, varre.type, value_type)
        }
        return
    } else if re, ok := varre.name.(ArrayIndex); ok {
        varre.type = re.type
        if !tc_equals(self, varre.type, value_type) {
            elog(self, varre.cursors_idx, "mismatch types, variable \"%v\" type %v, expression type %v", varre.name, varre.type, value_type)
        }
        return
    }

    stmnt_vardecl := symtab_find(self, varre.name, varre.cursors_idx)
    if vardecl, ok := stmnt_vardecl.(VarDecl); ok {
        varre.type = vardecl.type
    } else if _, ok := stmnt_vardecl.(ConstDecl); ok {
        elog(self, varre.cursors_idx, "cannot mutate constant variable \"%v\"", varre.name)
    } else {
        elog(self, varre.cursors_idx, "expected \"%v\" to be a variable, got %v", varre.name, stmnt_vardecl)
    }

    if !tc_equals(self, varre.type, value_type) {
        elog(self, varre.cursors_idx, "mismatch types, variable \"%v\" type %v, expression type %v", varre.name, varre.type, value_type)
    }
}

analyse_const_decl :: proc(self: ^Analyser, constdecl: ^ConstDecl) {
    #partial switch &val in constdecl.value {
    case Literal:
        if val.type == nil {
            if constdecl.type == nil {
                // <name> := {..}; can't do that
                elog(self, constdecl.cursors_idx, "missing type for literal")
            } else {
                // <name>: <type> = {..};
                val.type = constdecl.type
            }
        } else if constdecl.type != nil {
            // <name>: <type> = <type>{..};
            if !tc_equals(self, constdecl.type, &val.type) {
                elog(self, constdecl.cursors_idx, "mismatch types, variable \"%v\" type %v, expression type %v", constdecl.name, constdecl.type, val.type)
            }
        } else {
            // <name> := <type>{..};
            constdecl.type = val.type
        }
    }

    analyse_expr(self, &constdecl.value)

    tc_const_decl(self, constdecl)

    symtab_push(self, constdecl.name, constdecl^)
}

analyse_fn_call :: proc(self: ^Analyser, fncall: ^FnCall) {
    stmnt_fndecl := symtab_find(self, fncall.name, fncall.cursors_idx)
    fndecl, fndecl_ok := stmnt_fndecl.(FnDecl)
    if !fndecl_ok {
        elog(self, fncall.cursors_idx, "expected \"%v\" to be a function, got %v", stmnt_fndecl)
    }

    if fncall.type == nil {
        fncall.type = fndecl.type
    }

    decl_args_len := len(fndecl.args)
    fncall_args_len := len(fncall.args)
    if decl_args_len != fncall_args_len {
        elog(self, fncall.cursors_idx, "expected %v argument(s) in function call \"%v\", got %v", decl_args_len, fncall.name, fncall_args_len)
    }

    for &call_arg in fncall.args {
        analyse_expr(self, &call_arg)
    }

    for decl_arg, i in fndecl.args {
        darg_type := type_of_stmnt(self, decl_arg)
        carg_type := type_of_expr(self, &fncall.args[i])

        if !tc_equals(self, darg_type, carg_type) {
            elog(self, fncall.cursors_idx, "mismatch types, argument %v is expected to be of type %v, got %v", i + 1, darg_type, carg_type)
        }
    }
}

analyse_if :: proc(self: ^Analyser, ifs: ^If) {
    analyse_expr(self, &ifs.condition)
    condition_type := type_of_expr(self, &ifs.condition)
    if !tc_equals(self, Bool{}, condition_type) && !type_tag_equal(Option{}, condition_type^) {
        elog(self, ifs.cursors_idx, "condition must be bool or option, got %v", condition_type)
    }

    captured: Maybe(union{Ident, ConstDecl}) = nil
    if capture, ok := ifs.capture.?; ok {
        subtype := condition_type.(Option).type^
        captured = ConstDecl{
            name = capture.(Ident),
            type = subtype,
            value = Null{},
            cursors_idx = capture.(Ident).cursors_idx,
        }
        ifs.capture = captured
    }

    symtab_new_scope(self)
    if c, ok := captured.?; ok {
        symtab_push(self, c.(ConstDecl).name, c.(ConstDecl))
    }

    analyse_block(self, ifs.body)
    symtab_pop_scope(self)

    symtab_new_scope(self)
    analyse_block(self, ifs.els)
    symtab_pop_scope(self)
}

analyse_for :: proc(self: ^Analyser, forl: ^For) {
    symtab_new_scope(self)

    analyse_var_decl(self, &forl.decl)
    analyse_expr(self, &forl.condition)
    condition_type := type_of_expr(self, &forl.condition)
    if !tc_equals(self, Bool{}, condition_type) && !type_tag_equal(Option{}, condition_type^) {
        elog(self, get_cursor_index(forl.condition), "condition must be bool, got %v", condition_type)
    }
    analyse_var_reassign(self, &forl.reassign)

    symtab_new_scope(self)
    analyse_block(self, forl.body)
    symtab_pop_scope(self)

    symtab_pop_scope(self)
}

analyse_block :: proc(self: ^Analyser, block: [dynamic]Stmnt) {
    for &statement in block {
        switch &stmnt in statement {
        case Directive:
            analyse_directive(self, &stmnt)
        case Extern:
            analyse_extern(self, &stmnt)
        case Block:
            symtab_new_scope(self)
            analyse_block(self, stmnt.body)
            symtab_pop_scope(self)
        case Return:
            if fn, ok := self.current_fn.?; ok {
                analyse_return(self, fn, &stmnt)
            } else {
                elog(self, stmnt.cursors_idx, "illegal use of return, not inside a function")
            }
        case VarDecl:
            analyse_var_decl(self, &stmnt)
        case VarReassign:
            analyse_var_reassign(self, &stmnt)
        case ConstDecl:
            analyse_const_decl(self, &stmnt)
        case FnCall:
            analyse_fn_call(self, &stmnt)
        case If:
            analyse_if(self, &stmnt)
        case For:
            analyse_for(self, &stmnt)
        case FnDecl:
            elog(self, stmnt.cursors_idx, "illegal function declaration \"%v\" inside another function", stmnt.name)
        }
    }
}

analyse_fn_decl :: proc(self: ^Analyser, fn: FnDecl) {
    fn := fn
    symtab_push(self, fn.name, fn)

    symtab_new_scope(self)
    defer symtab_pop_scope(self)

    for &arg in fn.args {
        symtab_push(self, arg.(ConstDecl).name, arg)
    }

    if strings.compare(fn.name.literal, "main") == 0 && !type_tag_equal(fn.type, Void{}) {
        elog(self, fn.cursors_idx, "illegal main function, expected return type to be void, got %v", fn.type)
    }
    self.current_fn = fn

    analyse_block(self, fn.body)
}

analyse_extern :: proc(self: ^Analyser, extern: ^Extern) {
    for statement in extern.body {
        switch &stmnt in statement {
        case FnDecl:
            analyse_fn_decl(self, stmnt)
        case VarDecl:
            analyse_var_decl(self, &stmnt)
        case VarReassign:
            analyse_var_reassign(self, &stmnt)
        case ConstDecl:
            analyse_const_decl(self, &stmnt)
        case Block:
            elog(self, stmnt.cursors_idx, "illegal use of scope block, not inside a function")
        case Return:
            elog(self, stmnt.cursors_idx, "illegal use of return, not inside a function")
        case FnCall:
            elog(self, stmnt.cursors_idx, "illegal use of function call \"%v\", not inside a function", stmnt.name)
        case If:
            elog(self, stmnt.cursors_idx, "illegal use of if statement, not inside a function")
        case For:
            elog(self, stmnt.cursors_idx, "illegal use of for loop, not inside a function")
        case Extern:
            elog(self, stmnt.cursors_idx, "illegal use of extern, already inside extern")
        case Directive:
            elog(self, get_cursor_index(cast(Stmnt)stmnt), "illegal use of directive, can't be inside extern")
        }
    }
}

analyse_directive :: proc(self: ^Analyser, directive: ^Directive) {
    switch d in directive {
    case DirectiveLink, DirectiveSysLink:
        return
    case DirectiveOutput:
        if !self.compile_flags.output {
            self.compile_flags.output = true
        } else {
            elog(self, d.cursors_idx, "output already set, cannot have more than one output directive")
        }
    case DirectiveO0:
        if !self.compile_flags.optimise {
            self.compile_flags.optimise = true
        } else {
            elog(self, d.cursors_idx, "optimisation already set, cannot have more than one optimisation directive")
        }
    case DirectiveO1:
        if !self.compile_flags.optimise {
            self.compile_flags.optimise = true
        } else {
            elog(self, d.cursors_idx, "optimisation already set, cannot have more than one optimisation directive")
        }
    case DirectiveO2:
        if !self.compile_flags.optimise {
            self.compile_flags.optimise = true
        } else {
            elog(self, d.cursors_idx, "optimisation already set, cannot have more than one optimisation directive")
        }
    case DirectiveO3:
        if !self.compile_flags.optimise {
            self.compile_flags.optimise = true
        } else {
            elog(self, d.cursors_idx, "optimisation already set, cannot have more than one optimisation directive")
        }
    case DirectiveOdebug:
        if !self.compile_flags.optimise {
            self.compile_flags.optimise = true
        } else {
            elog(self, d.cursors_idx, "optimisation already set, cannot have more than one optimisation directive")
        }
    case DirectiveOfast:
        if !self.compile_flags.optimise {
            self.compile_flags.optimise = true
        } else {
            elog(self, d.cursors_idx, "optimisation already set, cannot have more than one optimisation directive")
        }
    case DirectiveOsmall:
        if !self.compile_flags.optimise {
            self.compile_flags.optimise = true
        } else {
            elog(self, d.cursors_idx, "optimisation already set, cannot have more than one optimisation directive")
        }
    }
}

analyse :: proc(self: ^Analyser) {
    for statement in self.ast {
        switch &stmnt in statement {
        case Directive:
            analyse_directive(self, &stmnt)
            continue
        case Extern:
            analyse_extern(self, &stmnt)
        case FnDecl:
            analyse_fn_decl(self, stmnt)
        case VarDecl:
            analyse_var_decl(self, &stmnt)
        case VarReassign:
            analyse_var_reassign(self, &stmnt)
        case ConstDecl:
            analyse_const_decl(self, &stmnt)
        case Block:
            elog(self, stmnt.cursors_idx, "illegal use of scope block, not inside a function")
        case Return:
            elog(self, stmnt.cursors_idx, "illegal use of return, not inside a function")
        case FnCall:
            elog(self, stmnt.cursors_idx, "illegal use of function call \"%v\", not inside a function", stmnt.name)
        case If:
            elog(self, stmnt.cursors_idx, "illegal use of if statement, not inside a function")
        case For:
            elog(self, stmnt.cursors_idx, "illegal use of for loop, not inside a function")
        }
    }
}
