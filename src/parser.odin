#+feature dynamic-literals
package main

import "core:fmt"
import "core:strings"
import "core:os"
import "core:mem"

Type :: enum {
    Void,
    Bool,
    I32,
    I64,
    Untyped_Int,
}
type_map := map[string]Type{
    "void" = .Void,
    "i32" = .I32,
    "i64" = .I64,
    "bool" = .Bool,
}

string_from_type :: proc(t: Type) -> string {
    switch t {
    case .Bool:
        return "bool"
    case .I64:
        return "i64"
    case .I32:
        return "i32"
    case .Void:
        return "void"
    case .Untyped_Int:
        panic("compiler error: should not be converting untyped_int to a string")
    }

    return ""
}

Keyword :: enum {
    Fn,
    Return,
    True,
    False,
    If,
    Else,
}
keyword_map := map[string]Keyword{
    "fn" = .Fn,
    "return" = .Return,
    "true" = .True,
    "false" = .False,
    "if" = .If,
    "else" = .Else,
}
expr_from_keyword :: proc(using parser: ^Parser, k: Keyword) -> Expr {
    #partial switch k {
    case .True:
        return True{type = .Bool, cursors_idx = cursors_idx}
    case .False:
        return False{type = .Bool, cursors_idx = cursors_idx}
    case:
        elog(parser, cursors_idx, "expected an expression, got keyword %v", k)
    }
}

IntLit :: struct {
    literal: string,
    type: Type,
    cursors_idx: int,
}
Ident :: struct {
    literal: string,
    type: Type,
    cursors_idx: int,
}
Const :: struct {
    name: string,
    type: Type,
    cursors_idx: int,
}
FnCall :: struct {
    name: Ident,
    type: Type,
    args: [dynamic]Expr,
    cursors_idx: int,
}
Plus :: struct {
    left: ^Expr, // these have to be pointers
    right: ^Expr,
    type: Type,
    cursors_idx: int,
}
Minus :: struct {
    left: ^Expr, // these have to be pointers
    right: ^Expr,
    type: Type,
    cursors_idx: int,
}
Divide :: struct {
    left: ^Expr, // these have to be pointers
    right: ^Expr,
    type: Type,
    cursors_idx: int,
}
Multiply :: struct {
    left: ^Expr, // these have to be pointers
    right: ^Expr,
    type: Type,
    cursors_idx: int,
}
LessThan :: struct {
    left: ^Expr, // these have to be pointers
    right: ^Expr,
    cursors_idx: int,
}
LessOrEqual :: struct {
    left: ^Expr, // these have to be pointers
    right: ^Expr,
    cursors_idx: int,
}
GreaterThan :: struct {
    left: ^Expr, // these have to be pointers
    right: ^Expr,
    cursors_idx: int,
}
GreaterOrEqual :: struct {
    left: ^Expr, // these have to be pointers
    right: ^Expr,
    cursors_idx: int,
}
Equality :: struct {
    left: ^Expr, // these have to be pointers
    right: ^Expr,
    cursors_idx: int,
}
Inequality :: struct {
    left: ^Expr, // these have to be pointers
    right: ^Expr,
    cursors_idx: int,
}
Not :: struct {
    condition: ^Expr,
    cursors_idx: int,
}
Negative :: struct {
    value: ^Expr,
    type: Type,
    cursors_idx: int,
}
True :: struct {
    type: Type,
    cursors_idx: int,
}
False :: struct {
    type: Type,
    cursors_idx: int,
}
Grouping :: struct {
    value: ^Expr,
    type: Type,
    cursors_idx: int,
}
Expr :: union {
    IntLit,
    Ident,
    Const,
    FnCall,

    Plus,
    Minus,
    Multiply,
    Divide,

    LessThan,
    LessOrEqual,
    GreaterThan,
    GreaterOrEqual,
    Equality,
    Inequality,
    Not,
    Negative,

    True,
    False,
    Grouping,
}

FnDecl :: struct {
    name: string, // allocated
    type: Type,
    args: [dynamic]Stmnt,
    body: [dynamic]Stmnt,
    cursors_idx: int,
}
VarDecl :: struct {
    name: string, // allocated
    type: Type,
    value: Expr,
    cursors_idx: int,
}
VarReassign :: struct {
    name: string,
    type: Type,
    value: Expr,
    cursors_idx: int,
}
ConstDecl :: struct {
    name: string, // allocated
    type: Type,
    value: Expr,
    cursors_idx: int,
}
Return :: struct {
    type: Type,
    value: Expr,
    cursors_idx: int,
}
If :: struct {
    // type: Type,
    condition: Expr,
    // capture: Const,
    body: [dynamic]Stmnt,
    els: [dynamic]Stmnt,
    cursors_idx: int,
}
Stmnt :: union {
    FnDecl,
    VarDecl,
    VarReassign,
    Return,
    FnCall,
    ConstDecl,
    If,
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
    case If:
        elog(analyser, stmnt.cursors_idx, "unexpected if statement")
    }

    if statement == nil {
        return .Void
    }

    return nil
}

get_cursor_index :: proc(item: union {Stmnt, Expr}) -> int {
    switch it in item {
    case Expr:
        switch expr in it {
        case Grouping:
            return expr.cursors_idx
        case FnCall:
            return expr.cursors_idx
        case Ident:
            return expr.cursors_idx
        case Const:
            return expr.cursors_idx
        case IntLit:
            return expr.cursors_idx
        case Plus:
            return expr.cursors_idx
        case Minus:
            return expr.cursors_idx
        case Multiply:
            return expr.cursors_idx
        case Divide:
            return expr.cursors_idx
        case LessThan:
            return expr.cursors_idx
        case LessOrEqual:
            return expr.cursors_idx
        case GreaterThan:
            return expr.cursors_idx
        case GreaterOrEqual:
            return expr.cursors_idx
        case Equality:
            return expr.cursors_idx
        case Inequality:
            return expr.cursors_idx
        case Not:
            return expr.cursors_idx
        case Negative:
            return expr.cursors_idx
        case True:
            return expr.cursors_idx
        case False:
            return expr.cursors_idx
        }
    case Stmnt:
        switch stmnt in it {
        case VarDecl:
            return stmnt.cursors_idx
        case VarReassign:
            return stmnt.cursors_idx
        case Return:
            return stmnt.cursors_idx
        case FnDecl:
            return stmnt.cursors_idx
        case FnCall:
            return stmnt.cursors_idx
        case ConstDecl:
            return stmnt.cursors_idx
        case If:
            return stmnt.cursors_idx
        }
    }

    unreachable()
}

expr_print :: proc(expression: Expr) {
    switch expr in expression {
    case Grouping:
        fmt.printf("(")
        expr_print(expr.value^)
        fmt.printf(")")
    case True:
        fmt.printf("True")
    case False:
        fmt.printf("False")
    case Not:
        fmt.printf("Not ")
        expr_print(expr.condition^)
    case Negative:
        fmt.printf("- ")
        expr_print(expr.value^)
    case LessThan:
        expr_print(expr.left^)
        fmt.printf(" Less Than ")
        expr_print(expr.right^)
    case LessOrEqual:
        expr_print(expr.left^)
        fmt.printf(" Less Or Equal ")
        expr_print(expr.right^)
    case GreaterThan:
        expr_print(expr.left^)
        fmt.printf(" Greater Than ")
        expr_print(expr.right^)
    case GreaterOrEqual:
        expr_print(expr.left^)
        fmt.printf(" Greater Or Equal ")
        expr_print(expr.right^)
    case Equality:
        expr_print(expr.left^)
        fmt.printf(" Equals ")
        expr_print(expr.right^)
    case Inequality:
        expr_print(expr.left^)
        fmt.printf(" Not Equals ")
        expr_print(expr.right^)
    case Plus:
        expr_print(expr.left^)
        fmt.printf(" Plus(%v) ", expr.type)
        expr_print(expr.right^)
    case Minus:
        expr_print(expr.left^)
        fmt.printf(" Minus(%v) ", expr.type)
        expr_print(expr.right^)
    case Multiply:
        expr_print(expr.left^)
        fmt.printf(" Multiply(%v) ", expr.type)
        expr_print(expr.right^)
    case Divide:
        expr_print(expr.left^)
        fmt.printf(" Divide(%v) ", expr.type)
        expr_print(expr.right^)
    case IntLit:
        fmt.printf("IntLit(%v) %v", expr.type, expr.literal)
    case FnCall:
        fmt.printf("FnCall(%v) %v(", expr.type, expr.name)
        for arg, i in expr.args {
            if i == 0 {
                expr_print(arg)
            } else {
                fmt.print(", ")
                expr_print(arg)
            }
        }
        fmt.print(")")
    case Ident:
        fmt.printf("Ident(%v) %v", expr.type, expr.literal)
    case Const:
        fmt.printf("Const(%v) %v", expr.type, expr.name)
    case:
        fmt.printf("")
    }
}

stmnt_print :: proc(statement: Stmnt, indent: uint = 0) {
    for _ in 0..<indent {
        fmt.print("    ")
    }

    switch stmnt in statement {
    case If:
        fmt.printf("If (")
        expr_print(stmnt.condition)
        fmt.print(")")
    case FnDecl:
        fmt.printf("Fn(%v) %v(", stmnt.type, stmnt.name)
        for arg, i in stmnt.args {
            if i == 0 {
                stmnt_print(arg, 0)
            } else {
                fmt.print(", ")
                stmnt_print(arg, 0)
            }
        }
        fmt.println(")")

        for s in stmnt.body {
            stmnt_print(s, indent+1)
        }
    case VarDecl:
        if stmnt.value == nil {
            fmt.printf("Var(%v) %v", stmnt.type, stmnt.name)
            return
        }

        fmt.printf("Var(%v) %v = ", stmnt.type, stmnt.name)
        expr_print(stmnt.value)
        fmt.println("")
    case VarReassign:
        fmt.printf("VarReassign(%v) %v = ", stmnt.type, stmnt.name)
        expr_print(stmnt.value)
        fmt.println("")
    case ConstDecl:
        if stmnt.value == nil {
            fmt.printf("Const(%v) %v", stmnt.type, stmnt.name)
            return
        }

        fmt.printf("Const(%v) %v = ", stmnt.type, stmnt.name)
        expr_print(stmnt.value)
        fmt.println("")
    case Return:

        fmt.printf("Return(%v) ", stmnt.type)
        expr_print(stmnt.value)
        fmt.println("")
    case FnCall:
        expr_print(stmnt)
    }
}

convert_ident :: proc(using token: TokenIdent) -> union {Type, Keyword, string} {
    if ident in keyword_map {
        return keyword_map[ident]
    } else if ident in type_map {
        return type_map[ident]
    } else {
        return ident
    }
}
Parser :: struct {
    tokens: [dynamic]Token,
    in_func_decl_args: bool,
    in_func_call_args: bool,

    // debug
    filename: string,
    cursors: [dynamic][2]u32,
    cursors_idx: int,
}

parse_elog :: proc(self: ^Parser, i: int, format: string, args: ..any) -> ! {
    if DEBUG_MODE {
        debug("elog from parser")
    }

    fmt.eprintf("%v:%v:%v \x1b[91;1merror\x1b[0m: ", self.filename, self.cursors[i][0], self.cursors[i][1])
    fmt.eprintfln(format, ..args)

    os.exit(1)
}

parse_fn_decl :: proc(self: ^Parser, name: string) -> Stmnt {
    index := self.cursors_idx

    self.in_func_decl_args = true
    args := parse_block(self, TokenLb{}, TokenRb{})
    self.in_func_decl_args = false

    type_ident := token_expect(self, TokenIdent{})
    type := convert_ident(type_ident.(TokenIdent)).(Type)

    body := parse_block(self)

    return FnDecl{
        name = name,
        type = type,
        args = args,
        body = body,
        cursors_idx = index,
    }
}

parse_block :: proc(self: ^Parser, start: Token = TokenLc{}, end: Token = TokenRc{}) -> [dynamic]Stmnt {
    _ = token_expect(self, start)

    block := [dynamic]Stmnt{}

    // if there's nothing inside the block
    if token := token_peek(self); token_tag_equal(token, end) {
        token_next(self)
        return block
    }

    for stmnt := parse(self); stmnt != nil; stmnt = parse(self) {
        append(&block, stmnt)

        token := token_peek(self)
        if token_tag_equal(token, end) {
            token_next(self)
            break
        }
    }

    if len(block) == 0 {
        _ = token_expect(self, end)
    }

    return block
}

parse_comparison :: proc(self: ^Parser) -> Expr {
    expr := parse_term(self)

    for token := token_peek(self); token != nil; token = token_peek(self) {
        index := self.cursors_idx
        if !token_tag_equal(token, TokenLa{}) && !token_tag_equal(token, TokenRa{}) {
            break
        }
        token_next(self)

        left := new(Expr); left^ = expr
        right := new(Expr); right^ = parse_term(self)

        after := token_peek(self)
        if token_tag_equal(after, TokenEqual{}) {
            token_next(self)

            if token_tag_equal(token, TokenLa{}) {
                expr = LessOrEqual{
                    left = left,
                    right = right,
                    cursors_idx = index,
                }
            } else {
                expr = GreaterOrEqual{
                    left = left,
                    right = right,
                    cursors_idx = index,
                }
            }
        } else {
            if token_tag_equal(token, TokenLa{}) {
                expr = LessThan{
                    left = left,
                    right = right,
                    cursors_idx = index,
                }
            } else {
                expr = GreaterThan{
                    left = left,
                    right = right,
                    cursors_idx = index,
                }
            }
        }
    }

    return expr
}

parse_equality :: proc(self: ^Parser) -> Expr {
    expr := parse_comparison(self)

    for token := token_peek(self); token != nil; token = token_peek(self) {
        index := self.cursors_idx
        if !token_tag_equal(token, TokenExclaim{}) && !token_tag_equal(token, TokenEqual{}) {
            break
        }
        token_next(self)

        after := token_next(self)
        if !token_tag_equal(after, TokenEqual{}) {
            break
        }

        left := new(Expr); left^ = expr;
        right := new(Expr); right^ = parse_comparison(self)
        if token_tag_equal(token, TokenExclaim{}) {
            expr = Inequality{
                left = left,
                right = right,
                cursors_idx = index,
            }
        } else {
            expr = Equality{
                left = left,
                right = right,
                cursors_idx = index,
            }
        }
    }

    return expr
}

parse_expr :: proc(self: ^Parser) -> Expr {
    return parse_equality(self)
}

parse_primary :: proc(self: ^Parser) -> Expr {
    token := token_next(self)

    #partial switch tok in token {
    case TokenIdent:
        converted_ident := convert_ident(tok)
        if name, ok := converted_ident.(string); ok {
            return Ident{
                literal = tok.ident,
                type = nil,
                cursors_idx = self.cursors_idx,
            }
        } else if keyword, ok := converted_ident.(Keyword); ok {
            return expr_from_keyword(self, keyword)
        } else {
            elog(self, self.cursors_idx, "expected identifier, got %v", converted_ident)
        }
    case TokenIntLit:
        return IntLit{
            literal = tok.literal,
            type = .Untyped_Int,
            cursors_idx = self.cursors_idx
        }
    case TokenLb:
        index := self.cursors_idx
        expr := new(Expr); expr^ = parse_expr(self)
        token_expect(self, TokenRb{})
        return Grouping{
            value = expr,
            type = nil,
            cursors_idx = index
        }
    case:
        elog(self, self.cursors_idx, "unexpected token %v", tok)
    }
}

parse_end_call :: proc(self: ^Parser, callee: Ident) -> FnCall {
    index := self.cursors_idx
    args := [dynamic]Expr{}

    token := token_peek(self)
    if !token_tag_equal(token, TokenRb{}) {
        token_next(self)

        append(&args, parse_expr(self))
        for after := token_peek(self); token_tag_equal(after, TokenSemiColon{}); after = token_peek(self) {
            token_next(self)
            append(&args, parse_expr(self))
        }
    }

    token_expect(self, TokenRb{})
    return FnCall{
        name = callee,
        type = nil,
        args = args,
        cursors_idx = index,
    }
}

parse_fn_call :: proc(self: ^Parser, ident: Maybe(Ident) = nil) -> Expr {
    expr := parse_primary(self)

    for {
        token := token_peek(self)
        if token_tag_equal(token, TokenLb{}) {
            token_next(self)
            expr = parse_end_call(self, expr.(Ident))
        } else {
            break
        }
    }

    return expr
}

parse_unary :: proc(self: ^Parser) -> Expr {
    op := token_peek(self)
    index := self.cursors_idx
    if !token_tag_equal(op, TokenExclaim{}) && !token_tag_equal(op, TokenMinus{}) {
        return parse_fn_call(self)
    }

    token_next(self)

    right := new(Expr); right^ = parse_unary(self)
    if token_tag_equal(op, TokenExclaim{}) {
        return Not{
            condition = right,
            cursors_idx = index,
        }
    } else {
        return Negative{
            value = right,
            cursors_idx = index,
        }
    }
}

parse_factor :: proc(self: ^Parser) -> Expr {
    expr := parse_unary(self)

    for op := token_peek(self); op != nil; op = token_peek(self) {
        if !token_tag_equal(op, TokenStar{}) && !token_tag_equal(op, TokenSlash{}) {
            break
        }
        token_next(self)

        index := self.cursors_idx
        left := new(Expr); left^ = expr
        right := new(Expr); right^ = parse_unary(self)

        if token_tag_equal(op, TokenStar{}) {
            expr = Multiply{
                left = left,
                right = right,
                type = nil,
                cursors_idx = index,
            }
        } else {
            expr = Divide{
                left = left,
                right = right,
                type = nil,
                cursors_idx = index,
            }
        }
    }

    return expr
}

parse_term :: proc(self: ^Parser) -> Expr {
    expr := parse_factor(self)

    for op := token_peek(self); op != nil; op = token_peek(self) {
        if !token_tag_equal(op, TokenPlus{}) && !token_tag_equal(op, TokenMinus{}) {
            break
        }
        token_next(self)

        index := self.cursors_idx
        left := new(Expr); left^ = expr
        right := new(Expr); right^ = parse_factor(self)

        if token_tag_equal(op, TokenPlus{}) {
            expr = Plus{
                left = left,
                right = right,
                type = nil,
                cursors_idx = index,
            }
        } else {
            expr = Minus{
                left = left,
                right = right,
                type = nil,
                cursors_idx = index,
            }
        }
    }
    return expr 
}

parse_const_decl :: proc(self: ^Parser, ident: string, type: Type = nil) -> Stmnt {
    // <ident> : <type?> :

    token := token_peek(self)
    if token == nil do return nil

    index := self.cursors_idx

    #partial switch tok in token {
    case TokenIdent:
        converted_ident := convert_ident(tok)
        if keyword, keyword_ok := converted_ident.(Keyword); keyword_ok {
            #partial switch keyword {
            case .Fn:
                token_next(self) // no nil check, checked when peeked
                return parse_fn_decl(self, ident)
            case .True, .False:
            case:
                elog(self, index, "unexpected token %v", tok)
            }
        }
    }

    // <ident>: <type> ,
    if self.in_func_decl_args {
        return ConstDecl{
            name = ident,
            type = type,
            value = nil,
            cursors_idx = index,
        }
        // TODO: implement default function arguments
    }

    expr := parse_expr(self)
    token_expect(self, TokenSemiColon{})
    // <ident>: <type?>: ;
    if expr == nil {
        elog(self, index, "expected expression after \":\" in variable \"%v\" declaration", ident)
    }
    return ConstDecl{
        name = ident,
        type = type,
        value = expr,
        cursors_idx = index,
    }
}

parse_var_decl :: proc(self: ^Parser, name: string, type: Type = nil, has_equals: bool = true) -> Stmnt {
    index := self.cursors_idx

    // <ident>: <type?> = ;
    if has_equals {
        expr := parse_expr(self)
        token_expect(self, TokenSemiColon{})
        if expr == nil {
            elog(self, index, "expected expression after \"=\" in variable \"%v\" declaration", name)
        }

        return VarDecl{
            name = name,
            type = type,
            value = expr,
            cursors_idx = index,
        }
    }

    // <ident>: <type>;
    return VarDecl{
        name = name,
        type = type,
        value = nil,
        cursors_idx = index,
    }
}

parse_decl :: proc(self: ^Parser, ident: string) -> Stmnt {
    // <ident> :

    token := token_peek(self)
    if token == nil do return nil

    #partial switch tok in token {
    case TokenColon:
        token_next(self) // no nil check, already checked when peeked
        return parse_const_decl(self, ident)
    case TokenEqual:
        token_next(self)
        return parse_var_decl(self, ident)
    case TokenIdent:
        token_next(self)
        converted_ident := convert_ident(tok)

        if type, type_ok := converted_ident.(Type); type_ok {
            token_after_type := token_peek(self)
            if token_after_type == nil do return nil

            #partial switch tat in token_after_type {
            case TokenColon:
                token_next(self)
                return parse_const_decl(self, ident, type)
            case TokenEqual:
                token_next(self)
                return parse_var_decl(self, ident, type)
            case TokenSemiColon:
                token_next(self)
                if type == nil {
                    elog(self, self.cursors_idx, "expected type for variable \"%v\" declaration since it does not have a value", ident)
                }
                return parse_var_decl(self, ident, type, false)
            case TokenComma:
                token_next(self)
                if !self.in_func_decl_args {
                    elog(self, self.cursors_idx, "unexpected comma during declaration")
                }
                return parse_const_decl(self, ident, type)
            case TokenRb:
                if !self.in_func_decl_args {
                    elog(self, self.cursors_idx, "unexpected TokenRb during declaration")
                }
                return parse_const_decl(self, ident, type)
            case:
                elog(self, self.cursors_idx, "unexpected token %v", tok)
            }
        } else {
            elog(self, self.cursors_idx, "expected a type during declaration, got %v", converted_ident)
        }
    case:
        elog(self, self.cursors_idx, "unexpected token %v during declaration", tok)
    }

    return nil
}

parse_var_reassign :: proc(self: ^Parser, name: string) -> Stmnt {
    // <name> = 
    expr := parse_expr(self)
    token_expect(self, TokenSemiColon{})

    return VarReassign{
        name = name,
        type = nil,
        value = expr,
        cursors_idx = self.cursors_idx,
    }
}

parse_ident :: proc(self: ^Parser, ident: string) -> Stmnt {
    ident_index := self.cursors_idx
    
    token := token_peek(self)
    if token == nil do return nil

    #partial switch tok in token {
    case TokenColon:
        token_next(self) // no nil check, already checked when peeked
        return parse_decl(self, ident)
    case TokenPlus:
        token_next(self) // no nil check, already checked when peeked
        token_after := token_next(self)

        if token_tag_equal(token_after, TokenEqual{}) {
            elog(self, self.cursors_idx, "+= operator not yet implemented");
            // return parse_var_plus_equal(self, ident)
        }
    case TokenEqual:
        token_next(self) // no nil check, already checked when peeked
        return parse_var_reassign(self, ident);
    case TokenLb:
        return parse_fn_call(self, Ident{
            literal = ident,
            type = nil,
            cursors_idx = ident_index,
        }).(FnCall)
    case:
        elog(self, self.cursors_idx, "unexpected token %v", tok)
    }

    return nil
}

parse_return :: proc(self: ^Parser) -> Stmnt {
    index := self.cursors_idx
    expr := parse_expr(self)
    token_expect(self, TokenSemiColon{})
    return Return{
        value = expr,
        type = nil,
        cursors_idx = index,
    }
}

parse_if :: proc(self: ^Parser) -> Stmnt {
    index := self.cursors_idx

    _ = token_expect(self, TokenLb{})
    expr := parse_expr(self)
    _ = token_expect(self, TokenRb{})

    body := parse_block(self)

    else_block: [dynamic]Stmnt
    
    if token := token_peek(self); token_tag_equal(token, TokenIdent{}) {
        converted := convert_ident(token.(TokenIdent))
        if keyword, ok := converted.(Keyword); ok {
            if keyword == .Else {
                token_next(self)
                else_block = parse_block(self)
            }
        }
    }

    return If{
        condition = expr,
        body = body,
        els = else_block,
        cursors_idx = index,
    }
}

parse :: proc(self: ^Parser) -> Stmnt {
    token := token_peek(self)
    if token == nil do return nil

    #partial switch tok in token {
    case TokenIdent:
        token_next(self) // no nil check, already checked when peeked
        converted_ident := convert_ident(tok)

        if ident, ident_ok := converted_ident.(string); ident_ok {
            return parse_ident(self, ident)
        } else if keyword, keyword_ok := converted_ident.(Keyword); keyword_ok {
            #partial switch keyword {
            case .Return:
                return parse_return(self)
            case .If:
                return parse_if(self)
            }
        }
    case:
        elog(self, self.cursors_idx, "unexpected token %v", tok)
    }
    return nil
}
