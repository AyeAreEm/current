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
    case Deref:
        _, ok := rhs.(Deref)
        return ok
    case FieldAccess:
        if k, ok := rhs.(FieldAccess); ok {
            return sym_equals(k.expr^, el.expr^) && sym_equals(k.field^, el.field^)
        }
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

symtab_propogate :: proc(analyser: ^Analyser, key: Expr) {
    using analyser.symtab

    value := symtab_find(analyser, key, get_cursor_index(key))
    #partial switch v in value {
    case VarDecl:
        if type_tag_equal(v.type, Ptr{}) {
            expr := new(Expr); expr^ = v.name
            field := new(Expr); field^ = Deref{
                cursors_idx = get_cursor_index(key),
            }
            field_access := FieldAccess{
                expr = expr,
                field = field,
                type = tc_deref_ptr(analyser, v.type),
                constant = v.type.(Ptr).constant,
                cursors_idx = get_cursor_index(key),
            }

            append(&keys[curr_scope], field_access)
            append(&values[curr_scope], nil)
        }
    case ConstDecl:
        if type_tag_equal(v.type, Ptr{}) {
            expr := new(Expr); expr^ = v.name
            field := new(Expr); field^ = Deref{
                cursors_idx = get_cursor_index(key),
            }
            field_access := FieldAccess{
                expr = expr,
                field = field,
                type = tc_deref_ptr(analyser, v.type),
                constant = v.type.(Ptr).constant,
                cursors_idx = get_cursor_index(key),
            }

            append(&keys[curr_scope], field_access)
            append(&values[curr_scope], nil)
        }
    }
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

    symtab_propogate(analyser, key)
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

    // debug
    filename: string,
    cursors: [dynamic][2]u32,
}

analyser_init :: proc(ast: [dynamic]Stmnt, symtab: SymTab, filename: string, cursors: [dynamic][2]u32) -> Analyser {
    return {
        ast = ast,
        symtab = symtab,
        current_fn = nil,
        
        filename = filename,
        cursors = cursors,
    }
}

type_of_expr :: proc(analyser: ^Analyser, expr: Expr) -> Type {
    expr := expr

    switch &ex in expr {
    case CharLit:
        return ex.type
    case Address:
        atype := new(Type); atype^ = ex.type
        decl := symtab_find(analyser, ex.value^, get_cursor_index(ex.value^))
        return Ptr{
            type = atype,
            constant = stmnt_is_constant(analyser, decl)
        }
    case Literal:
        return ex.type
    case Bool:
        return TypeId{}
    case Char:
        return TypeId{}
    case I8:
        return TypeId{}
    case I16:
        return TypeId{}
    case I32:
        return TypeId{}
    case I64:
        return TypeId{}
    case U8:
        return TypeId{}
    case U16:
        return TypeId{}
    case U32:
        return TypeId{}
    case U64:
        return TypeId{}
    case F32:
        return TypeId{}
    case F64:
        return TypeId{}
    case Negative:
        return ex.type
    case Grouping:
        return ex.type
    case IntLit:
        return ex.type
    case FloatLit:
        return ex.type
    case Deref:
        // TODO: this should probably give an actual type
        elog(analyser, ex.cursors_idx, "not implemented, can't return type from Deref right now")
    case FieldAccess:
        decl := symtab_find(analyser, ex.expr^, ex.cursors_idx)
        if var, ok := decl.(VarDecl); ok {
            return var.type
        } else if var, ok := decl.(ConstDecl); ok {
            return var.type
        } else {
            elog(analyser, ex.cursors_idx, "expected a variable or constant, got %v", decl)
        }
    case Ident:
        decl := symtab_find(analyser, ex, ex.cursors_idx)
        if var, ok := decl.(VarDecl); ok {
            return var.type
        } else if var, ok := decl.(ConstDecl); ok {
            return var.type
        } else {
            elog(analyser, ex.cursors_idx, "expected ident to be a variable or constant, got %v", decl)
        }
    case FnCall:
        call := symtab_find(analyser, ex.name, ex.cursors_idx).(FnDecl)
        return call.type
    case LessThan:
        return Bool{}
    case LessOrEqual:
        return Bool{}
    case GreaterThan:
        return Bool{}
    case GreaterOrEqual:
        return Bool{}
    case Equality:
        return Bool{}
    case Inequality:
        return Bool{}
    case Not:
        return Bool{}
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
        return Void{}
    }

    return nil
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
    }

    // if statement == nil {
    //     return .Void
    // }

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
    
    // TODO: check if elems are the correct type.
    // i.e. if elems are the subtype of the array type
    // or if elems are the correct type in type declaration
}

analyse_expr :: proc(self: ^Analyser, expr: ^Expr) {
    switch &ex in expr {
    case Deref:
        elog(self, ex.cursors_idx, "deref not implemented yet in analyse_expr")
    case FieldAccess:
        fa := symtab_find_key(self, expr^, ex.cursors_idx).(FieldAccess)
        ex = fa
    case I8, I16, I32, I64:
        return
    case U8, U16, U32, U64:
        return
    case F32, F64:
        return
    case Bool:
        return
    case Char:
        return
    case Address:
        analyse_expr(self, ex.value)

        #partial switch &addr_expr in ex.value {
        case Ident:
            stmnt := symtab_find(self, addr_expr, addr_expr.cursors_idx)
            type := type_of_stmnt(self, stmnt)
            ex.type = type
            ex.to_constant = stmnt_is_constant(self, stmnt)
        case:
            elog(self, ex.cursors_idx, "can't take address of {}", ex.value^)
        }
    case Literal:
        analyse_literal(self, &ex)
    case FnCall:
        analyse_fn_call(self, &ex)
    case Ident:
        stmnt_vardecl := symtab_find(self, ex, ex.cursors_idx)
        if _, ok := stmnt_vardecl.(VarDecl); ok {
        } else if _, ok := stmnt_vardecl.(ConstDecl); ok {
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
    case True, False:
        return
    case Grouping:
        analyse_expr(self, ex.value)
        value_type := type_of_expr(self, ex.value^)

        if t := tc_default_untyped_type(value_type); t != nil {
            ex.type = t
        } else {
            ex.type = value_type
        }
    case Negative:
        analyse_expr(self, ex.value)
        value_type := type_of_expr(self, ex.value^)

        ex.type = value_type
    case Not:
        analyse_expr(self, ex.condition)
        t := type_of_expr(self, ex.condition^)

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

        lt := type_of_expr(self, ex.left^)
        rt := type_of_expr(self, ex.right^)
        if !tc_equals(self, lt, rt) {
            elog(self, ex.cursors_idx, "mismatch types, %v == %v", lt, rt)
        }

        if !tc_can_compare_value(self, lt, rt) {
            elog(self, ex.cursors_idx, "cannot compare %v and %v", lt, rt)
        }
    case Inequality:
        analyse_expr(self, ex.left)
        analyse_expr(self, ex.right)

        lt := type_of_expr(self, ex.left^)
        rt := type_of_expr(self, ex.right^)
        if !tc_equals(self, lt, rt) {
            elog(self, ex.cursors_idx, "mismatch types, %v != %v", lt, rt)
        }

        if !tc_can_compare_value(self, lt, rt) {
            elog(self, ex.cursors_idx, "cannot compare %v and %v", lt, rt)
        }
    case LessThan:
        analyse_expr(self, ex.left)
        analyse_expr(self, ex.right)

        lt := type_of_expr(self, ex.left^)
        rt := type_of_expr(self, ex.right^)
        if !tc_equals(self, lt, rt) {
            elog(self, ex.cursors_idx, "mismatch types, %v < %v", lt, rt)
        }

        if !tc_can_compare_order(self, lt, rt) {
            elog(self, ex.cursors_idx, "cannot compare %v and %v", lt, rt)
        }
    case LessOrEqual:
        analyse_expr(self, ex.left)
        analyse_expr(self, ex.right)

        lt := type_of_expr(self, ex.left^)
        rt := type_of_expr(self, ex.right^)
        if !tc_equals(self, lt, rt) {
            elog(self, ex.cursors_idx, "mismatch types, %v <= %v", lt, rt)
        }

        if !tc_can_compare_order(self, lt, rt) {
            elog(self, ex.cursors_idx, "cannot compare %v and %v", lt, rt)
        }
    case GreaterThan:
        analyse_expr(self, ex.left)
        analyse_expr(self, ex.right)

        lt := type_of_expr(self, ex.left^)
        rt := type_of_expr(self, ex.right^)
        if !tc_equals(self, lt, rt) {
            elog(self, ex.cursors_idx, "mismatch types, %v > %v", lt, rt)
        }

        if !tc_can_compare_order(self, lt, rt) {
            elog(self, ex.cursors_idx, "cannot compare %v and %v", lt, rt)
        }
    case GreaterOrEqual:
        analyse_expr(self, ex.left)
        analyse_expr(self, ex.right)

        lt := type_of_expr(self, ex.left^)
        rt := type_of_expr(self, ex.right^)
        if !tc_equals(self, lt, rt) {
            elog(self, ex.cursors_idx, "mismatch types, %v >= %v", lt, rt)
        }

        if !tc_can_compare_order(self, lt, rt) {
            elog(self, ex.cursors_idx, "cannot compare %v and %v", lt, rt)
        }
    case Plus:
        analyse_expr(self, ex.left)
        analyse_expr(self, ex.right)

        lt := type_of_expr(self, ex.left^)
        rt := type_of_expr(self, ex.right^)
        if !tc_equals(self, lt, rt) {
            elog(self, ex.cursors_idx, "mismatch types, %v + %v", lt, rt)
        }

        _, lt_ok := lt.(Untyped_Int)
        _, rt_ok := rt.(Untyped_Int)

        if lt_ok && rt_ok {
            ex.type = lt
        } else if rt_ok {
            ex.type = lt
        } else {
            ex.type = rt
        }

    case Minus:
        analyse_expr(self, ex.left)
        analyse_expr(self, ex.right)

        lt := type_of_expr(self, ex.left^)
        rt := type_of_expr(self, ex.right^)
        if !tc_equals(self, lt, rt) {
            elog(self, ex.cursors_idx, "mismatch types, %v - %v", lt, rt)
        }

        _, lt_ok := lt.(Untyped_Int)
        _, rt_ok := rt.(Untyped_Int)

        if lt_ok && rt_ok {
            ex.type = lt
        } else if rt_ok {
            ex.type = lt
        } else {
            ex.type = rt
        }
    case Multiply:
        analyse_expr(self, ex.left)
        analyse_expr(self, ex.right)

        lt := type_of_expr(self, ex.left^)
        rt := type_of_expr(self, ex.right^)
        if !tc_equals(self, lt, rt) {
            elog(self, ex.cursors_idx, "mismatch types, %v * %v", lt, rt)
        }

        _, lt_ok := lt.(Untyped_Int)
        _, rt_ok := rt.(Untyped_Int)

        if lt_ok && rt_ok {
            ex.type = lt
        } else if rt_ok {
            ex.type = lt
        } else {
            ex.type = rt
        }
    case Divide:
        analyse_expr(self, ex.left)
        analyse_expr(self, ex.right)

        lt := type_of_expr(self, ex.left^)
        rt := type_of_expr(self, ex.right^)
        if !tc_equals(self, lt, rt) {
            elog(self, ex.cursors_idx, "mismatch types, %v / %v", lt, rt)
        }

        _, lt_ok := lt.(Untyped_Int)
        _, rt_ok := rt.(Untyped_Int)

        if lt_ok && rt_ok {
            ex.type = lt
        } else if rt_ok {
            ex.type = lt
        } else {
            ex.type = rt
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
            if !tc_equals(self, vardecl.type, val.type) {
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

    stmnt_vardecl := symtab_find(self, varre.name, varre.cursors_idx)
    if vardecl, ok := stmnt_vardecl.(VarDecl); ok {
        varre.type = vardecl.type
    } else if stmnt_vardecl == nil {
        if field_access, ok := varre.name.(FieldAccess); ok {
            if field_access.constant {
                elog(self, varre.cursors_idx, "cannot mutate constant variable \"%v\"", varre.name)
            }
        }

        // NOTE: this can happend when it's a propogated field or function argument (maybe)
        // because something like `p := &n` would have a `p.&` that doesn't have a value or
        // statement to declare it

        tc_infer(self, &varre.type, varre.value)
    } else if _, ok := stmnt_vardecl.(ConstDecl); ok {
        elog(self, varre.cursors_idx, "cannot mutate constant variable \"%v\"", varre.name)
    } else {
        elog(self, varre.cursors_idx, "expected \"%v\" to be a variable, got %v", varre.name, stmnt_vardecl)
    }

    tc_equals(self, varre.type, type_of_expr(self, varre.value))
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
            if !tc_equals(self, constdecl.type, val.type) {
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

    for &call_arg, i in fncall.args {
        analyse_expr(self, &call_arg)
    }

    for decl_arg, i in fndecl.args {
        darg_type := type_of_stmnt(self, decl_arg)
        carg_type := type_of_expr(self, fncall.args[i])

        if !tc_equals(self, darg_type, carg_type) {
            elog(self, fncall.cursors_idx, "mismatch types, argument %v is expected to be of type %v, got %v", i + 1, darg_type, carg_type)
        }
    }
}

analyse_if :: proc(self: ^Analyser, ifs: ^If) {
    analyse_expr(self, &ifs.condition)
    condition_type := type_of_expr(self, ifs.condition)
    if !tc_equals(self, Bool{}, condition_type) {
        elog(self, ifs.cursors_idx, "condition must be bool, got %v", condition_type)
    }

    symtab_new_scope(self)
    defer symtab_pop_scope(self)

    analyse_block(self, ifs.body)
    analyse_block(self, ifs.els)
}

analyse_block :: proc(self: ^Analyser, block: [dynamic]Stmnt) {
    for &statement in block {
        switch &stmnt in statement {
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

analyse :: proc(self: ^Analyser) {
    for statement in self.ast {
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
        }
    }
}
