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

ExprIntLit :: struct {
    literal: string,
    type: Type,
    cursors_idx: int,
}
ExprVar :: struct {
    name: string,
    type: Type,
    cursors_idx: int,
}
Expr :: union {
    ExprIntLit,
    ExprVar,
}

type_of_expr :: proc(expr: Expr) -> Type {
    switch ex in expr {
    case ExprIntLit:
        return ex.type
    case ExprVar:
        return ex.type
    }

    if expr == nil {
        return .Void
    }

    return nil
}

StmntFnDecl :: struct {
    name: string, // allocated
    type: Type,
    // args: [dynamic]Expr,
    body: [dynamic]Stmnt,
    cursors_idx: int,
}

StmntVarDecl :: struct {
    name: string,
    type: Type,
    value: Expr,
    cursors_idx: int,
}

StmntReturn :: struct {
    type: Type,
    value: Expr,
    cursors_idx: int,
}

Stmnt :: union {
    StmntFnDecl,
    StmntVarDecl,
    StmntReturn,
}

get_cursor_index :: proc(item: union {Stmnt, Expr}) -> int {
    switch it in item {
    case Expr:
        switch expr in it {
        case ExprVar:
            return expr.cursors_idx
        case ExprIntLit:
            return expr.cursors_idx
        }
    case Stmnt:
        switch stmnt in it {
        case StmntVarDecl:
            return stmnt.cursors_idx
        case StmntReturn:
            return stmnt.cursors_idx
        case StmntFnDecl:
            return stmnt.cursors_idx
        }
    }

    unreachable()
}

stmnt_print :: proc(statement: Stmnt, indent: uint = 0) {
    for _ in 0..<indent {
        fmt.print("    ")
    }

    switch stmnt in statement {
    case StmntFnDecl:
        fmt.printfln("fn %v() %v", stmnt.name, stmnt.type)
        for s in stmnt.body {
            stmnt_print(s, indent+1)
        }
    case StmntVarDecl:
        fmt.printfln("%v %v = %v", stmnt.type, stmnt.name, stmnt.value)
    case StmntReturn:
        fmt.printfln("return %v of type %v", stmnt.value, stmnt.type)
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
    _ = token_expect(&tokens, TokenLb{})

    _ = token_expect(&tokens, TokenRb{})
    type_ident := token_expect(&tokens, TokenIdent{})
    type := convert_ident(type_ident.(TokenIdent)).(Type)

    body := parse_block(parser)

    return StmntFnDecl{
        name = name,
        type = type,
        body = body,
        cursors_idx = index,
    }
}

parse_block :: proc(using parser: ^Parser) -> [dynamic]Stmnt {
    _ = token_expect(&tokens, TokenLc{})

    block := [dynamic]Stmnt{}

    for stmnt := parse(parser); stmnt != nil; stmnt = parse(parser) {
        append(&block, stmnt)

        token := token_peek(&tokens)
        if token_tag_equal(token, TokenRc{}) {
            token_next(&tokens)
            break
        }
    }

    if len(block) == 0 {
        _ = token_expect(&tokens, TokenRc{})
    }

    return block
}

parse_expr_until :: proc(using parser: ^Parser, until: Maybe(Token) = nil) -> Expr {
    stack := [dynamic]Expr{}
    defer delete(stack)

    // i8 because this really does not need to be more
    // than 127 like cmon
    curl_count: i8 = 0

    for token := token_next(&tokens); token != nil && token != until; token = token_next(&tokens) {
        #partial switch tok in token {
        case TokenIntLit:
            append(&stack, ExprIntLit{
                literal = tok.literal,
                type = .Untyped_Int,
                cursors_idx = cursors_idx,
            })
        case TokenIdent:
            converted_ident := convert_ident(tok)

            if name, ok := converted_ident.(string); ok {
                // TODO: change this to accept function calls
                append(&stack, ExprVar{
                    name = tok.ident,
                    type = nil,
                    cursors_idx = cursors_idx,
                })
            } else {
                elog(cursors_idx, "expected identifier, got %v", converted_ident)
            }
        case TokenLc:
            curl_count += 1
        case TokenRc:
            curl_count -= 1
            if curl_count < 0 {
                elog(cursors_idx, "missing open curly bracket")
            }
        }
    }

    if len(stack) == 0 {
        return nil
    }
    return stack[0]
}

parse_const_decl :: proc(using parser: ^Parser, ident: string, type: Maybe(Type) = nil) -> Stmnt {
    token := token_peek(&tokens)
    if token == nil do return nil

    #partial switch tok in token {
    case TokenIdent:
        token_next(&tokens) // no nil check, already checked when peeked

        converted_ident := convert_ident(tok)
        if keyword, keyword_ok := converted_ident.(Keyword); keyword_ok {
            #partial switch keyword {
            case .Fn:
                return parse_fn_decl(parser, ident)
            }
        }
    }

    return nil
}

parse_var_decl :: proc(using parser: ^Parser, name: string, type: Type = nil) -> Stmnt {
    index := cursors_idx
    expr := parse_expr_until(parser, TokenSemiColon{})
    return StmntVarDecl{
        name = name,
        type = type,
        value = expr,
        cursors_idx = index,
    }
}

parse_decl :: proc(using parser: ^Parser, ident: string) -> Stmnt {
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
            token_after_type := token_next(&tokens)
            if token_after_type == nil do return nil

            #partial switch tat in token_after_type {
            case TokenColon:
                return parse_const_decl(parser, ident, type)
            case TokenEqual:
                return parse_var_decl(parser, ident, type)
            }
        }
    }

    return nil
}

parse_ident :: proc(using parser: ^Parser, ident: string) -> Stmnt {
    token := token_peek(&tokens)
    if token == nil do return nil

    #partial switch tok in token {
    case TokenColon:
        token_next(&tokens) // no nil check, already checked when peeked
        return parse_decl(parser, ident)
    }

    return nil
}

parse_return :: proc(using parser: ^Parser) -> Stmnt {
    index := cursors_idx
    expr := parse_expr_until(parser, TokenSemiColon{})
    return StmntReturn{
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
    }
    return nil
}
