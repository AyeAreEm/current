#+feature dynamic-literals
package main

import "core:fmt"
import "core:strings"
import "core:os"

Type :: enum {
    Void,
    I32,
    I64,
    Untyped_Int,
}
type_map := map[string]Type{
    "void" = .Void,
    "i32" = .I32,
    "i64" = .I64,
}

Keyword :: enum {
    Fn,
    Return,
}
keyword_map := map[string]Keyword{
    "fn" = .Fn,
    "return" = .Return,
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
Expr :: union {
    IntLit,
    Var,
    Const,
    FnCall,
}

type_of_expr :: proc(expr: Expr) -> Type {
    switch ex in expr {
    case IntLit:
        return ex.type
    case Var:
        return ex.type
    case Const:
        return ex.type
    case FnCall:
        return ex.type
    }

    if expr == nil {
        return .Void
    }

    return nil
}

FnDecl :: struct {
    name: string, // allocated
    type: Type,
    args: [dynamic]Stmnt,
    body: [dynamic]Stmnt,
    cursors_idx: int,
}
VarDecl :: struct {
    name: string,
    type: Type,
    value: Expr,
    cursors_idx: int,
}
ConstDecl :: struct {
    name: string,
    type: Type,
    value: Expr,
    cursors_idx: int,
}
Return :: struct {
    type: Type,
    value: Expr,
    cursors_idx: int,
}
Stmnt :: union {
    FnDecl,
    VarDecl,
    Return,
    FnCall,
    ConstDecl,
}

type_of_stmnt :: proc(statement: Stmnt) -> Type {
    switch stmnt in statement {
    case FnDecl:
        return stmnt.type
    case FnCall:
        return stmnt.type
    case VarDecl:
        return stmnt.type
    case ConstDecl:
        return stmnt.type
    case Return:
        return stmnt.type
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
        }
    case Stmnt:
        switch stmnt in it {
        case VarDecl:
            return stmnt.cursors_idx
        case Return:
            return stmnt.cursors_idx
        case FnDecl:
            return stmnt.cursors_idx
        case FnCall:
            return stmnt.cursors_idx
        case ConstDecl:
            return stmnt.cursors_idx
        }
    }

    unreachable()
}

expr_print :: proc(expression: Expr) {
    switch expr in expression {
    case IntLit:
        fmt.printf("IntLit %v %v", expr.type, expr.literal)
    case FnCall:
        fmt.printf("FnCall %v %v(", expr.type, expr.name)
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
        fmt.printf("Var %v %v", expr.type, expr.name)
    case Const:
        fmt.printf("Const %v %v", expr.type, expr.name)
    case:
        fmt.printf("")
    }
}

stmnt_print :: proc(statement: Stmnt, indent: uint = 0) {
    for _ in 0..<indent {
        fmt.print("    ")
    }

    switch stmnt in statement {
    case FnDecl:
        fmt.printf("Fn %v %v(", stmnt.type, stmnt.name)
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
            fmt.printf("Var %v %v", stmnt.type, stmnt.name)
            return
        }

        fmt.printf("Var %v %v = ", stmnt.type, stmnt.name)
        expr_print(stmnt.value)
        fmt.println("")
    case ConstDecl:
        if stmnt.value == nil {
            fmt.printf("Const %v %v", stmnt.type, stmnt.name)
            return
        }

        fmt.printf("Const %v %v = ", stmnt.type, stmnt.name)
        expr_print(stmnt.value)
        fmt.println("")
    case Return:

        fmt.printf("Return %v ", stmnt.type)
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

parse_fn_decl :: proc(using parser: ^Parser, name: string) -> Stmnt {
    index := cursors_idx

    in_func_decl_args = true
    args := parse_block(parser, TokenLb{}, TokenRb{})
    in_func_decl_args = false

    type_ident := token_expect(&tokens, TokenIdent{})
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
    _ = token_expect(&tokens, start)

    block := [dynamic]Stmnt{}

    // if there's nothing inside the block
    if token := token_peek(&tokens); token_tag_equal(token, end) {
        token_next(&tokens)
        return block
    }

    for stmnt := parse(parser); stmnt != nil; stmnt = parse(parser) {
        append(&block, stmnt)

        token := token_peek(&tokens)
        if token_tag_equal(token, end) {
            token_next(&tokens)
            break
        }
    }

    if len(block) == 0 {
        _ = token_expect(&tokens, end)
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

    for token := token_next(&tokens); token != nil; token = token_next(&tokens) {
        if token_tag_equal(token, until) {
            break
        }

        #partial switch tok in token {
        case TokenIntLit:
            append(&stack, IntLit{
                literal = tok.literal,
                type = .Untyped_Int,
                cursors_idx = cursors_idx,
            })
        case TokenIdent:
            converted_ident := convert_ident(tok)

            if name, ok := converted_ident.(string); ok {
                token_after_ident := token_peek(&tokens)
                if lb, lb_ok := token_after_ident.(TokenLb); lb_ok {
                    append(&stack, parse_fn_call(parser, tok.ident))
                } else {
                    append(&stack, Var{
                        name = tok.ident,
                        type = nil,
                        cursors_idx = cursors_idx,
                    })
                }
            } else {
                elog(cursors_idx, "expected identifier, got %v", converted_ident)
            }
        case TokenLb:
            bracket_count += 1
        case TokenRb:
            bracket_count -= 1

            if in_func_call_args && bracket_count == -1 {
                in_func_call_args = false
                return nil if len(stack) == 0 else stack[0]
            } else if bracket_count < 0 {
                elog(cursors_idx, "missing open bracket")
            }
        case TokenLc:
            curly_count += 1
        case TokenRc:
            curly_count -= 1
            if curly_count < 0 {
                elog(cursors_idx, "missing open curly bracket")
            }
        case:
            elog(cursors_idx, "unexpected token %v", tok)
        }
    }

    if bracket_count != 0 {
        elog(cursors_idx, "missing close bracket")
    }

    if curly_count != 0 {
        elog(cursors_idx, "missing close curly bracket")
    }

    if len(stack) == 0 {
        return nil
    }
    return stack[0]
}

parse_const_decl :: proc(using parser: ^Parser, ident: string, type: Type = nil) -> Stmnt {
    // <ident> : <type?> :

    token := token_peek(&tokens)
    if token == nil do return nil

    index := cursors_idx

    #partial switch tok in token {
    case TokenIdent:
        converted_ident := convert_ident(tok)
        if keyword, keyword_ok := converted_ident.(Keyword); keyword_ok {
            #partial switch keyword {
            case .Fn:
                token_next(&tokens) // no nil check, checked when peeked
                return parse_fn_decl(parser, ident)
            case:
                elog(index, "unexpected token %v", tok)
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
    // <ident>: <type?>: ;
    if expr == nil {
        elog(index, "expected expression after \":\" in variable \"%v\" declaration", ident)
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
        if expr == nil {
            elog(index, "expected expression after \"=\" in variable \"%v\" declaration", name)
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

    token := token_peek(&tokens)
    if token == nil do return nil

    #partial switch tok in token {
    case TokenColon:
        token_next(&tokens) // no nil check, already checked when peeked
        return parse_const_decl(parser, ident)
    case TokenEqual:
        token_next(&tokens)
        return parse_var_decl(parser, ident)
    case TokenIdent:
        token_next(&tokens)
        converted_ident := convert_ident(tok)

        if type, type_ok := converted_ident.(Type); type_ok {
            token_after_type := token_peek(&tokens)
            if token_after_type == nil do return nil

            #partial switch tat in token_after_type {
            case TokenColon:
                token_next(&tokens)
                return parse_const_decl(parser, ident, type)
            case TokenEqual:
                token_next(&tokens)
                return parse_var_decl(parser, ident, type)
            case TokenSemiColon:
                token_next(&tokens)
                if type == nil {
                    elog(cursors_idx, "expected type for variable \"%v\" declaration since it does not have a value", ident)
                }
                return parse_var_decl(parser, ident, type, false)
            case TokenComma:
                token_next(&tokens)
                if !in_func_decl_args {
                    elog(cursors_idx, "unexpected comma during declaration")
                }
                return parse_const_decl(parser, ident, type)
            case TokenRb:
                if !in_func_decl_args {
                    elog(cursors_idx, "unexpected TokenRb during declaration")
                }
                return parse_const_decl(parser, ident, type)
            case:
                elog(cursors_idx, "unexpected token %v", tok)
            }
        }
    case:
        elog(cursors_idx, "unexpected token %v during declaration", tok)
    }

    return nil
}

parse_fn_call :: proc(using parser: ^Parser, name: string) -> FnCall {
    _ = token_expect(&tokens, TokenLb{})

    bracket_count: i8 = 0
    args := [dynamic]Expr{}

    in_func_call_args = true
    for token := token_peek(&tokens); token != nil && in_func_call_args; token = token_peek(&tokens) {
        #partial switch tok in token {
        case TokenLb:
            bracket_count += 1
        case TokenRb:
            bracket_count -= 1

            if bracket_count == 0 {
                break
            } else if bracket_count < 0 {
                elog(cursors_idx, "missing open bracket")
            }
        }

        append(&args, parse_expr_until(parser, TokenComma{}))
    }
    in_func_call_args = false
    
    return FnCall {
        name = name,
        type = nil,
        args = args,
        cursors_idx = cursors_idx,
    }
}

parse_ident :: proc(using parser: ^Parser, ident: string) -> Stmnt {
    token := token_peek(&tokens)
    if token == nil do return nil

    #partial switch tok in token {
    case TokenColon:
        token_next(&tokens) // no nil check, already checked when peeked
        return parse_decl(parser, ident)
    case TokenLb:
        return parse_fn_call(parser, ident)
    case:
        elog(cursors_idx, "unexpected token %v", tok)
    }

    return nil
}

parse_return :: proc(using parser: ^Parser) -> Stmnt {
    index := cursors_idx
    expr := parse_expr_until(parser, TokenSemiColon{})
    return Return{
        value = expr,
        type = nil,
        cursors_idx = index,
    }
}

parse :: proc(using parser: ^Parser) -> Stmnt {
    token := token_peek(&tokens)
    if token == nil do return nil

    #partial switch tok in token {
    case TokenIdent:
        token_next(&tokens) // no nil check, already checked when peeked
        converted_ident := convert_ident(tok)

        if ident, ident_ok := converted_ident.(string); ident_ok {
            return parse_ident(parser, ident)
        } else if keyword, keyword_ok := converted_ident.(Keyword); keyword_ok {
            return parse_return(parser)
        }
    case:
        elog(cursors_idx, "unexpected token %v", tok)
    }
    return nil
}
