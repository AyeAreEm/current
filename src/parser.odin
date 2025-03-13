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
}
keyword_map := map[string]Keyword{
    "fn" = .Fn,
    "return" = .Return,
    "true" = .True,
    "false" = .False,
    "if" = .If,
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
Var :: struct {
    name: string,
    type: Type,
    cursors_idx: int,
}
Const :: struct {
    name: string,
    type: Type,
    cursors_idx: int,
}
FnCall :: struct {
    name: string,
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
True :: struct {
    type: Type,
    cursors_idx: int,
}
False :: struct {
    type: Type,
    cursors_idx: int,
}
Expr :: union {
    IntLit,
    Var,
    Const,
    FnCall,
    Plus,
    Minus,
    Multiply,
    Divide,
    True,
    False
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
        case FnCall:
            return expr.cursors_idx
        case Var:
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
    case True:
        fmt.printf("True")
    case False:
        fmt.printf("False")
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
    case Var:
        fmt.printf("Var(%v) %v", expr.type, expr.name)
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

parse_elog :: proc(using parser: ^Parser, i: int, format: string, args: ..any) -> ! {
    if DEBUG_MODE {
        debug("elog from parser")
    }

    fmt.eprintf("%v:%v:%v \x1b[91;1merror\x1b[0m: ", filename, cursors[i][0], cursors[i][1])
    fmt.eprintfln(format, ..args)

    os.exit(1)
}

parse_fn_decl :: proc(using parser: ^Parser, name: string) -> Stmnt {
    index := cursors_idx

    in_func_decl_args = true
    args := parse_block(parser, TokenLb{}, TokenRb{})
    in_func_decl_args = false

    type_ident := token_expect(parser, TokenIdent{})
    type := convert_ident(type_ident.(TokenIdent)).(Type)

    body := parse_block(parser)

    return FnDecl{
        name = name,
        type = type,
        args = args,
        body = body,
        cursors_idx = index,
    }
}

parse_block :: proc(using parser: ^Parser, start: Token = TokenLc{}, end: Token = TokenRc{}) -> [dynamic]Stmnt {
    _ = token_expect(parser, start)

    block := [dynamic]Stmnt{}

    // if there's nothing inside the block
    if token := token_peek(parser); token_tag_equal(token, end) {
        token_next(parser)
        return block
    }

    for stmnt := parse(parser); stmnt != nil; stmnt = parse(parser) {
        append(&block, stmnt)

        token := token_peek(parser)
        if token_tag_equal(token, end) {
            token_next(parser)
            break
        }
    }

    if len(block) == 0 {
        _ = token_expect(parser, end)
    }

    return block
}

parse_expr_until :: proc(using parser: ^Parser, until: Token = nil) -> Expr {
    stack := [dynamic]Expr{}
    defer delete(stack)

    // i8 because this really does not need to be more
    // than 127 like cmon
    bracket_count: i8 = 0
    curly_count: i8 = 0

    for token := token_peek(parser); token != nil; token = token_peek(parser) {
        if token_tag_equal(token, until) {
            break
        }

        token_next(parser)

        #partial switch tok in token {
        case TokenPlus, TokenMinus, TokenStar, TokenSlash:
            lhs := pop(&stack)
            rhs := parse_expr_until(parser, until)
            // no token_expect because this scope needs to call next on it

            left, _ := new(Expr); left^ = lhs
            right, _ := new(Expr); right^ = rhs

            #partial switch _ in token {
            case TokenPlus:
                append(&stack, Plus{
                    left = left,
                    right = right,
                    type = nil,
                    cursors_idx = cursors_idx
                })
            case TokenMinus:
                append(&stack, Minus{
                    left = left,
                    right = right,
                    type = nil,
                    cursors_idx = cursors_idx
                })
            case TokenStar:
                append(&stack, Multiply{
                    left = left,
                    right = right,
                    type = nil,
                    cursors_idx = cursors_idx
                })
            case TokenSlash:
                append(&stack, Divide{
                    left = left,
                    right = right,
                    type = nil,
                    cursors_idx = cursors_idx
                })
            }
        case TokenIntLit:
            append(&stack, IntLit{
                literal = tok.literal,
                type = .Untyped_Int,
                cursors_idx = cursors_idx,
            })
        case TokenIdent:
            converted_ident := convert_ident(tok)

            if name, ok := converted_ident.(string); ok {
                token_after_ident := token_peek(parser)
                if lb, lb_ok := token_after_ident.(TokenLb); lb_ok {
                    append(&stack, parse_fn_call(parser, tok.ident))
                } else {
                    append(&stack, Var{
                        name = tok.ident,
                        type = nil,
                        cursors_idx = cursors_idx,
                    })
                }
            } else if keyword, ok := converted_ident.(Keyword); ok {
                val := expr_from_keyword(parser, keyword)
                append(&stack, val)
            } else {
                elog(parser, cursors_idx, "expected identifier, got %v", converted_ident)
            }
        case TokenLb:
            bracket_count += 1
        case TokenRb:
            bracket_count -= 1

            if in_func_call_args && bracket_count == -1 {
                in_func_call_args = false
                return nil if len(stack) == 0 else stack[0]
            } else if bracket_count < 0 {
                elog(parser, cursors_idx, "missing open bracket")
            }
        case TokenLc:
            curly_count += 1
        case TokenRc:
            curly_count -= 1
            if curly_count < 0 {
                elog(parser, cursors_idx, "missing open curly bracket")
            }
        case:
            elog(parser, cursors_idx, "unexpected token %v", tok)
        }
    }

    if bracket_count != 0 {
        elog(parser, cursors_idx, "missing close bracket")
    }

    if curly_count != 0 {
        elog(parser, cursors_idx, "missing close curly bracket")
    }

    if len(stack) == 0 {
        return nil
    }
    return stack[0]
}

parse_const_decl :: proc(using parser: ^Parser, ident: string, type: Type = nil) -> Stmnt {
    // <ident> : <type?> :

    token := token_peek(parser)
    if token == nil do return nil

    index := cursors_idx

    #partial switch tok in token {
    case TokenIdent:
        converted_ident := convert_ident(tok)
        if keyword, keyword_ok := converted_ident.(Keyword); keyword_ok {
            #partial switch keyword {
            case .Fn:
                token_next(parser) // no nil check, checked when peeked
                return parse_fn_decl(parser, ident)
            case:
                elog(parser, index, "unexpected token %v", tok)
            }
        }
    }

    // <ident>: <type> ,
    if in_func_decl_args {
        return ConstDecl{
            name = ident,
            type = type,
            value = nil,
            cursors_idx = index,
        }
        // TODO: implement default function arguments
    }

    expr := parse_expr_until(parser, TokenSemiColon{})
    token_expect(parser, TokenSemiColon{})
    // <ident>: <type?>: ;
    if expr == nil {
        elog(parser, index, "expected expression after \":\" in variable \"%v\" declaration", ident)
    }
    return ConstDecl{
        name = ident,
        type = type,
        value = expr,
        cursors_idx = index,
    }
}

parse_var_decl :: proc(using parser: ^Parser, name: string, type: Type = nil, has_equals: bool = true) -> Stmnt {
    index := cursors_idx

    // <ident>: <type?> = ;
    if has_equals {
        expr := parse_expr_until(parser, TokenSemiColon{})
        token_expect(parser, TokenSemiColon{})
        if expr == nil {
            elog(parser, index, "expected expression after \"=\" in variable \"%v\" declaration", name)
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

parse_decl :: proc(using parser: ^Parser, ident: string) -> Stmnt {
    // <ident> :

    token := token_peek(parser)
    if token == nil do return nil

    #partial switch tok in token {
    case TokenColon:
        token_next(parser) // no nil check, already checked when peeked
        return parse_const_decl(parser, ident)
    case TokenEqual:
        token_next(parser)
        return parse_var_decl(parser, ident)
    case TokenIdent:
        token_next(parser)
        converted_ident := convert_ident(tok)

        if type, type_ok := converted_ident.(Type); type_ok {
            token_after_type := token_peek(parser)
            if token_after_type == nil do return nil

            #partial switch tat in token_after_type {
            case TokenColon:
                token_next(parser)
                return parse_const_decl(parser, ident, type)
            case TokenEqual:
                token_next(parser)
                return parse_var_decl(parser, ident, type)
            case TokenSemiColon:
                token_next(parser)
                if type == nil {
                    elog(parser, cursors_idx, "expected type for variable \"%v\" declaration since it does not have a value", ident)
                }
                return parse_var_decl(parser, ident, type, false)
            case TokenComma:
                token_next(parser)
                if !in_func_decl_args {
                    elog(parser, cursors_idx, "unexpected comma during declaration")
                }
                return parse_const_decl(parser, ident, type)
            case TokenRb:
                if !in_func_decl_args {
                    elog(parser, cursors_idx, "unexpected TokenRb during declaration")
                }
                return parse_const_decl(parser, ident, type)
            case:
                elog(parser, cursors_idx, "unexpected token %v", tok)
            }
        } else {
            elog(parser, cursors_idx, "expected a type during declaration, got %v", converted_ident)
        }
    case:
        elog(parser, cursors_idx, "unexpected token %v during declaration", tok)
    }

    return nil
}

parse_fn_call :: proc(using parser: ^Parser, name: string) -> FnCall {
    _ = token_expect(parser, TokenLb{})

    bracket_count: i8 = 0
    args := [dynamic]Expr{}

    in_func_call_args = true
    for token := token_peek(parser); token != nil && in_func_call_args; token = token_peek(parser) {
        #partial switch tok in token {
        case TokenLb:
            bracket_count += 1
        case TokenRb:
            bracket_count -= 1

            if bracket_count == 0 {
                break
            } else if bracket_count < 0 {
                elog(parser, cursors_idx, "missing open bracket")
            }
        }

        arg := parse_expr_until(parser, TokenComma{})
        token_expect(parser, TokenComma{})
        append(&args, arg)
    }
    in_func_call_args = false
    
    return FnCall {
        name = name,
        type = nil,
        args = args,
        cursors_idx = cursors_idx,
    }
}

parse_var_reassign :: proc(using parser: ^Parser, name: string) -> Stmnt {
    // <name> = 
    expr := parse_expr_until(parser, TokenSemiColon{})
    token_expect(parser, TokenSemiColon{})

    return VarReassign{
        name = name,
        type = nil,
        value = expr,
        cursors_idx = cursors_idx,
    }
}

parse_ident :: proc(using parser: ^Parser, ident: string) -> Stmnt {
    token := token_peek(parser)
    if token == nil do return nil

    #partial switch tok in token {
    case TokenColon:
        token_next(parser) // no nil check, already checked when peeked
        return parse_decl(parser, ident)
    case TokenEqual:
        token_next(parser) // no nil check, already checked when peeked
        return parse_var_reassign(parser, ident);
    case TokenLb:
        return parse_fn_call(parser, ident)
    case:
        elog(parser, cursors_idx, "unexpected token %v", tok)
    }

    return nil
}

parse_return :: proc(using parser: ^Parser) -> Stmnt {
    index := cursors_idx
    expr := parse_expr_until(parser, TokenSemiColon{})
    token_expect(parser, TokenSemiColon{})
    return Return{
        value = expr,
        type = nil,
        cursors_idx = index,
    }
}

parse_if :: proc(using parser: ^Parser) -> Stmnt {
    index := cursors_idx

    _ = token_expect(parser, TokenLb{})
    expr := parse_expr_until(parser, TokenRb{})
    _ = token_expect(parser, TokenRb{})

    body := parse_block(parser)

    return If{
        condition = expr,
        body = body,
        cursors_idx = index,
    }
}

parse :: proc(using parser: ^Parser) -> Stmnt {
    token := token_peek(parser)
    if token == nil do return nil

    #partial switch tok in token {
    case TokenIdent:
        token_next(parser) // no nil check, already checked when peeked
        converted_ident := convert_ident(tok)

        if ident, ident_ok := converted_ident.(string); ident_ok {
            return parse_ident(parser, ident)
        } else if keyword, keyword_ok := converted_ident.(Keyword); keyword_ok {
            #partial switch keyword {
            case .Return:
                return parse_return(parser)
            case .If:
                return parse_if(parser)
            }
        }
    case:
        elog(parser, cursors_idx, "unexpected token %v", tok)
    }
    return nil
}
