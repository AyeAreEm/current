#+feature dynamic-literals
package main

import "core:fmt"
import "core:strings"
import "core:os"
import "core:mem"

Void :: struct {
    cursors_idx: int,
}
Bool :: struct {
    cursors_idx: int,
}
Char :: struct {
    cursors_idx: int,
}
String :: struct {
    // len: uint,
    cursors_idx: int,
}
Cstring :: struct {
    cursors_idx: int,
}

I8 :: struct {
    cursors_idx: int,
}
I16 :: struct {
    cursors_idx: int,
}
I32 :: struct {
    cursors_idx: int,
}
I64 :: struct {
    cursors_idx: int,
}

U8 :: struct {
    cursors_idx: int,
}
U16 :: struct {
    cursors_idx: int,
}
U32 :: struct {
    cursors_idx: int,
}
U64 :: struct {
    cursors_idx: int,
}

F32 :: struct {
    cursors_idx: int,
}
F64 :: struct {
    cursors_idx: int,
}

Usize :: struct {
    cursors_idx: int,
}
Isize :: struct {
    cursors_idx: int,
}

Array :: struct {
    type: ^Type,
    len: Maybe(^Expr), // if nil, infer len
    cursors_idx: int,
}

Ptr :: struct {
    type: ^Type,
    constant: bool,
}

Option :: struct {
    type: ^Type,
    is_null: bool,
    gen_option: bool,
    cursors_idx: int,
}

Untyped_Int :: struct {}
Untyped_Float :: struct {}
Type :: union {
    Void,
    Bool,

    Char,
    String,
    Cstring,

    I8,
    I16,
    I32,
    I64,

    U8,
    U16,
    U32,
    U64,

    F32,
    F64,

    Usize,
    Isize,

    Untyped_Int,
    Untyped_Float,

    Array,
    Ptr,
    Option,
}
type_map := map[string]Type{
    "void" = Void{},
    "bool" = Bool{},
    "char" = Char{},
    "string" = String{},
    "cstring" = Cstring{},

    "i8" = I8{},
    "i16" = I16{},
    "i32" = I32{},
    "i64" = I64{},

    "u8" = U8{},
    "u16" = U16{},
    "u32" = U32{},
    "u64" = U64{},

    "f32" = F32{},
    "f64" = F64{},

    "usize" = Usize{},
    "isize" = Isize{},
}

type_tag_equal :: proc(lhs, rhs: Type) -> bool {
    switch t in lhs {
    case Option:
        _, ok := rhs.(Option)
        return ok
    case Cstring:
        _, ok := rhs.(Cstring)
        return ok
    case String:
        _, ok := rhs.(String)
        return ok
    case Char:
        _, ok := rhs.(Char)
        return ok
    case Ptr:
        _, ok := rhs.(Ptr)
        return ok
    case Array:
        _, ok := rhs.(Array)
        return ok
    case I8:
        _, ok := rhs.(I8)
        return ok
    case I16:
        _, ok := rhs.(I16)
        return ok
    case I32:
        _, ok := rhs.(I32)
        return ok
    case I64:
        _, ok := rhs.(I64)
        return ok
    case U8:
        _, ok := rhs.(U8)
        return ok
    case U16:
        _, ok := rhs.(U16)
        return ok
    case U32:
        _, ok := rhs.(U32)
        return ok
    case U64:
        _, ok := rhs.(U64)
        return ok
    case F32:
        _, ok := rhs.(F32)
        return ok
    case F64:
        _, ok := rhs.(F64)
        return ok
    case Usize:
        _, ok := rhs.(Usize)
        return ok
    case Isize:
        _, ok := rhs.(Isize)
        return ok
    case Untyped_Int:
        _, ok := rhs.(Untyped_Int)
        return ok
    case Untyped_Float:
        _, ok := rhs.(Untyped_Float)
        return ok
    case Bool:
        _, ok := rhs.(Bool)
        return ok
    case Void:
        _, ok := rhs.(Void)
        return ok
    case nil:
        return rhs == nil
    }

    return false
}

Keyword :: enum {
    Fn,
    Return,
    True,
    False,
    Null,
    If,
    Else,
    Extern,
    For,
}
keyword_map := map[string]Keyword{
    "fn" = .Fn,
    "return" = .Return,
    "true" = .True,
    "false" = .False,
    "null" = .Null,
    "if" = .If,
    "else" = .Else,
    "extern" = .Extern,
    "for" = .For,
}
expr_from_keyword :: proc(using parser: ^Parser, k: Keyword) -> Expr {
    #partial switch k {
    case .True:
        return True{type = Bool{}, cursors_idx = cursors_idx}
    case .False:
        return False{type = Bool{}, cursors_idx = cursors_idx}
    case .Null:
        return Null{
            type = Option{
                type = new(Type),
                is_null = true,
            }
        }
    case:
        elog(parser, cursors_idx, "expected an expression, got keyword %v", k)
    }
}

DirectiveLink :: struct {
    link: string,
    cursors_idx: int,
}
Directive :: union {
    DirectiveLink,
}
directive_map := map[string]Directive{
    "link" = DirectiveLink{}
}

parser_get_directive :: proc(self: ^Parser, word: string) -> Directive {
    d, ok := directive_map[word]
    if !ok {
        elog(self, self.cursors_idx, "\"#%v\" is not a directive", word)
    }

    return d
}

IntLit :: struct {
    literal: string,
    type: Type,
    cursors_idx: int,
}
FloatLit :: struct {
    literal: string,
    type: Type,
    cursors_idx: int,
}
CharLit :: struct {
    literal: string,
    type: Type,
    cursors_idx: int,
}
StrLit :: struct {
    literal: string,
    type: Type,
    len: uint,
    cursors_idx: int,
}
CstrLit :: struct {
    literal: string,
    type: Type,
    len: uint,
    cursors_idx: int,
}
Literal :: struct {
    values: [dynamic]Expr,
    type: Type,
    cursors_idx: int,
}
Ident :: struct {
    literal: string,
    type: Type,
    cursors_idx: int,
}
FieldAccess :: struct {
    expr: ^Expr,
    field: ^Expr,
    type: Type,
    constant: bool,
    cursors_idx: int,
}
ArrayIndex :: struct {
    ident: ^Expr, // maybe should be Ident?
    index: ^Expr,
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
    type: Type,
    cursors_idx: int,
}
LessOrEqual :: struct {
    left: ^Expr, // these have to be pointers
    right: ^Expr,
    type: Type,
    cursors_idx: int,
}
GreaterThan :: struct {
    left: ^Expr, // these have to be pointers
    right: ^Expr,
    type: Type,
    cursors_idx: int,
}
GreaterOrEqual :: struct {
    left: ^Expr, // these have to be pointers
    right: ^Expr,
    type: Type,
    cursors_idx: int,
}
Equality :: struct {
    left: ^Expr, // these have to be pointers
    right: ^Expr,
    type: Type,
    cursors_idx: int,
}
Inequality :: struct {
    left: ^Expr, // these have to be pointers
    right: ^Expr,
    type: Type,
    cursors_idx: int,
}
Not :: struct {
    condition: ^Expr,
    type: Type,
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
Address :: struct {
    value: ^Expr,
    type: Type,
    to_constant: bool,
    cursors_idx: int,
}
Deref :: struct {
    cursors_idx: int,
}
Null :: struct {
    type: Type,
    cursors_idx: int,
}
Expr :: union {
    // types are also expressions
    Bool,
    Char,
    String,
    Cstring,

    I8,
    I16,
    I32,
    I64,

    U8,
    U16,
    U32,
    U64,

    F32,
    F64,

    Usize,
    Isize,

    IntLit,
    FloatLit,
    CharLit,
    StrLit,
    CstrLit,
    Literal,

    Ident,
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

    Address,
    FieldAccess,
    ArrayIndex,
    Deref,

    Null,
}

FnDecl :: struct {
    name: Ident,
    type: Type,
    args: [dynamic]Stmnt,
    body: [dynamic]Stmnt,
    has_body: bool,
    cursors_idx: int,
}
VarDecl :: struct {
    name: Ident,
    type: Type,
    value: Expr,
    cursors_idx: int,
}
VarReassign :: struct {
    name: Expr,
    type: Type,
    value: Expr,
    cursors_idx: int,
}
ConstDecl :: struct {
    name: Ident,
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
    capture: Maybe(union{Ident, ConstDecl}),
    body: [dynamic]Stmnt,
    els: [dynamic]Stmnt,
    cursors_idx: int,
}
For :: struct {
    decl: VarDecl,
    condition: Expr,
    reassign: VarReassign,
    body: [dynamic]Stmnt,
    cursors_idx: int,
}
Block :: struct {
    body: [dynamic]Stmnt,
    cursors_idx: int,
}
Extern :: struct {
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
    For,
    Block,
    Extern,
    Directive,
}

get_directive_cursor_index :: proc(item: Directive) -> int {
    switch it in item {
    case DirectiveLink:
        return it.cursors_idx
    }

    debug("unreachable in get_directive_cursor_index")
    unreachable()
}

get_cursor_index :: proc(item: union {Stmnt, Expr}) -> int {
    switch it in item {
    case Expr:
        switch expr in it {
        case Null:
            return expr.cursors_idx
        case CstrLit:
            return expr.cursors_idx
        case StrLit:
            return expr.cursors_idx
        case CharLit:
            return expr.cursors_idx
        case Deref:
            return expr.cursors_idx
        case FieldAccess:
            return expr.cursors_idx
        case ArrayIndex:
            return expr.cursors_idx
        case Address:
            return expr.cursors_idx
        case Bool:
            return expr.cursors_idx
        case Char:
            return expr.cursors_idx
        case String:
            return expr.cursors_idx
        case Cstring:
            return expr.cursors_idx
        case I8:
            return expr.cursors_idx
        case I16:
            return expr.cursors_idx
        case I32:
            return expr.cursors_idx
        case I64:
            return expr.cursors_idx
        case U8:
            return expr.cursors_idx
        case U16:
            return expr.cursors_idx
        case U32:
            return expr.cursors_idx
        case U64:
            return expr.cursors_idx
        case F32:
            return expr.cursors_idx
        case F64:
            return expr.cursors_idx
        case Usize:
            return expr.cursors_idx
        case Isize:
            return expr.cursors_idx
        case Literal:
            return expr.cursors_idx
        case Grouping:
            return expr.cursors_idx
        case FnCall:
            return expr.cursors_idx
        case Ident:
            return expr.cursors_idx
        case IntLit:
            return expr.cursors_idx
        case FloatLit:
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
        case For:
            return stmnt.cursors_idx
        case Directive:
            return get_directive_cursor_index(stmnt)
        case Extern:
            return stmnt.cursors_idx
        case Block:
            return stmnt.cursors_idx
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

    debug("unreachable in get_cursor_index, %v", item)
    unreachable()
}

convert_ident :: proc(self: ^Parser, using token: TokenIdent) -> union {Type, Keyword, Ident} {
    if ident in keyword_map {
        return keyword_map[ident]
    } else if ident in type_map {
        return type_map[ident]
    } else {
        return Ident{
            literal = ident,
            cursors_idx = self.cursors_idx
        }
    }
}
Parser :: struct {
    tokens: [dynamic]Token,
    in_func_decl_args: bool,

    // debug
    filename: string,
    cursors: [dynamic][2]u32,
    cursors_idx: int,
}

parser_init :: proc(tokens: [dynamic]Token, filename: string, cursors: [dynamic][2]u32) -> Parser {
    return {
        tokens = tokens, // NOTE: does this do a copy? surely not
        in_func_decl_args = false,

        filename = filename,
        cursors = cursors,
        cursors_idx = -1,
    }
}

parser_elog :: proc(self: ^Parser, i: int, format: string, args: ..any) -> ! {
    if DEBUG_MODE {
        debug("elog from parser")
    }

    fmt.eprintf("%v:%v:%v \x1b[91;1merror\x1b[0m: ", self.filename, self.cursors[i][0], self.cursors[i][1])
    fmt.eprintfln(format, ..args)

    os.exit(1)
}

parse_fn_decl :: proc(self: ^Parser, name: Ident) -> Stmnt {
    index := self.cursors_idx

    self.in_func_decl_args = true
    args := parse_block(self, TokenLb{}, TokenRb{})
    self.in_func_decl_args = false

    type := parse_type(self)

    token := token_peek(self)
    if token_tag_equal(token, TokenLc{}) {
        body := parse_block(self)

        return FnDecl{
            name = name,
            type = type,
            args = args,
            body = body,
            has_body = true,
            cursors_idx = index,
        }
    } else if token_tag_equal(token, TokenSemiColon{}) {
        token_next(self)
        return FnDecl{
            name = name,
            type = type,
            args = args,
            body = [dynamic]Stmnt{},
            has_body = false,
            cursors_idx = index,
        }
    } else {
        elog(self, self.cursors_idx, "expected ';' or '{', got %v", token)
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
                    type = Bool{},
                    cursors_idx = index,
                }
            } else {
                expr = GreaterOrEqual{
                    left = left,
                    right = right,
                    type = Bool{},
                    cursors_idx = index,
                }
            }
        } else {
            if token_tag_equal(token, TokenLa{}) {
                expr = LessThan{
                    left = left,
                    right = right,
                    type = Bool{},
                    cursors_idx = index,
                }
            } else {
                expr = GreaterThan{
                    left = left,
                    right = right,
                    type = Bool{},
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
                type = Bool{},
                cursors_idx = index,
            }
        } else {
            expr = Equality{
                left = left,
                right = right,
                type = Bool{},
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
    token := token_peek(self)

    #partial switch tok in token {
    case TokenLc:
        token_next(self)
        return parse_end_literal(self, nil)
    case TokenLs:
        type := parse_type(self)
        token = token_peek(self)
        if token_tag_equal(token, TokenLc{}) {
            token_next(self)
            return parse_end_literal(self, type)
        } else {
            elog(self, self.cursors_idx, "unexpected type %v", type)
        }
    case TokenIdent:
        token_next(self)
        converted_ident := convert_ident(self, tok)
        if name, ok := converted_ident.(Ident); ok {
            token = token_peek(self)

            if token_tag_equal(token, TokenDot{}) {
                // <ident>.
                token_next(self)
                return parse_field_access(self, name)
            } else if token_tag_equal(token, TokenLs{}) {
                token_next(self)
                return parse_array_index(self, name)
            } else if strings.compare(name.literal, "c") == 0 {
                // c""
                if token_tag_equal(token, TokenStrLit{}) {
                    token_next(self)
                    return CstrLit{
                        literal = token.(TokenStrLit).literal,
                        type = Cstring{},
                        cursors_idx = self.cursors_idx
                    }
                }
            }

            // <ident>
            return name
        } else if keyword, ok := converted_ident.(Keyword); ok {
            return expr_from_keyword(self, keyword)
        } else {
            elog(self, self.cursors_idx, "expected identifier, got %v", converted_ident)
        }
    case TokenIntLit:
        token_next(self)
        return IntLit{
            literal = tok.literal,
            type = Untyped_Int{},
            cursors_idx = self.cursors_idx
        }
    case TokenFloatLit:
        token_next(self)
        return FloatLit{
            literal = tok.literal,
            type = Untyped_Float{},
            cursors_idx = self.cursors_idx
        }
    case TokenCharLit:
        token_next(self)
        return CharLit{
            literal = tok.literal,
            type = Char{},
            cursors_idx = self.cursors_idx
        }
    case TokenStrLit:
        token_next(self)
        return StrLit{
            literal = tok.literal,
            type = String{},
            cursors_idx = self.cursors_idx
        }
    case TokenLb:
        token_next(self)
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

parse_end_fn_call :: proc(self: ^Parser, callee: Ident) -> FnCall {
    index := self.cursors_idx
    args := [dynamic]Expr{}

    token := token_peek(self)
    if !token_tag_equal(token, TokenRb{}) {
        append(&args, parse_expr(self))
        for after := token_peek(self); token_tag_equal(after, TokenComma{}); after = token_peek(self) {
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

parse_end_literal :: proc(self: ^Parser, type: Type) -> Expr {
    index := self.cursors_idx
    values := [dynamic]Expr{}

    token := token_peek(self)
    if !token_tag_equal(token, TokenRc{}) {
        append(&values, parse_expr(self))
        for after := token_peek(self); token_tag_equal(after, TokenComma{}); after = token_peek(self) {
            token_next(self)
            append(&values, parse_expr(self))
        }
    }

    token_expect(self, TokenRc{})
    return Literal{
        type = type,
        values = values,
        cursors_idx = index,
    }
}

parse_fn_call :: proc(self: ^Parser, ident: Maybe(Ident) = nil) -> Expr {
    expr: Expr = ident.? if ident != nil else parse_primary(self)

    for {
        token := token_peek(self)
        if token_tag_equal(token, TokenLb{}) {
            token_next(self)
            expr = parse_end_fn_call(self, expr.(Ident))
        } else {
            break
        }
    }

    return expr
}

parse_unary :: proc(self: ^Parser) -> Expr {
    op := token_peek(self)
    index := self.cursors_idx
    if !token_tag_equal(op, TokenExclaim{}) &&
       !token_tag_equal(op, TokenMinus{}) &&
       !token_tag_equal(op, TokenAmpersand{})
    {
        return parse_fn_call(self)
    }

    token_next(self)

    right := new(Expr); right^ = parse_unary(self)
    if token_tag_equal(op, TokenExclaim{}) {
        return Not{
            condition = right,
            cursors_idx = index,
            type = Bool{},
        }
    } else if token_tag_equal(op, TokenMinus{}) {
        return Negative{
            value = right,
            type = nil,
            cursors_idx = index,
        }
    } else {
        return Address{
            value = right,
            type = nil,
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

parse_const_decl :: proc(self: ^Parser, ident: Ident, type: Type = nil) -> Stmnt {
    // <ident> : <type?> :

    token := token_peek(self)
    if token == nil do return nil

    index := self.cursors_idx

    #partial switch tok in token {
    case TokenIdent:
        converted_ident := convert_ident(self, tok)
        if keyword, keyword_ok := converted_ident.(Keyword); keyword_ok {
            #partial switch keyword {
            case .Fn:
                token_next(self) // no nil check, checked when peeked
                return parse_fn_decl(self, ident)
            case .True, .False, .Null:
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

parse_var_decl :: proc(self: ^Parser, ident: Ident, type: Type = nil, has_equals: bool = true) -> Stmnt {
    index := self.cursors_idx

    // <ident>: <type?> = ;
    if has_equals {
        expr := parse_expr(self)
        token_expect(self, TokenSemiColon{})
        if expr == nil {
            elog(self, index, "expected expression after \"=\" in variable \"%v\" declaration", ident.literal)
        }

        return VarDecl{
            name = ident,
            type = type,
            value = expr,
            cursors_idx = index,
        }
    }

    // <ident>: <type>;
    return VarDecl{
        name = ident,
        type = type,
        value = nil,
        cursors_idx = index,
    }
}

parse_set_array_type :: proc(self: ^Parser, arr: ^Type, type: Type) {
    #partial switch &subtype in arr {
    case Array:
        if subtype.type^ == nil {
            subtype.type^ = type
        } else {
            parse_set_array_type(self, subtype.type, type)
        }
    } 
}

parse_set_ptr_type :: proc(self: ^Parser, ptr: ^Type, type: Type) {
    #partial switch &subtype in ptr {
    case Ptr:
        if subtype.type^ == nil {
            subtype.type^ = type
        } else {
            parse_set_ptr_type(self, subtype.type, type)
        }
    }
}

parse_type :: proc(self: ^Parser) -> Type {
    type: Type = nil
    token := token_peek(self)

    #partial switch tok in token {
    case TokenQm:
        index := self.cursors_idx

        token_next(self)
        subtype := new(Type); subtype^ = parse_type(self)

        type = Option{
            type = subtype,
            cursors_idx = index
        }
    case TokenCaret:
        type = Ptr{
            type = new(Type),
            constant = true,
        }
        token_next(self)

        for token = token_peek(self); token != nil; token = token_peek(self) {
            if token_tag_equal(token, TokenStar{}) {
                type = Ptr{
                    type = &type,
                    constant = false,
                }
            } else if token_tag_equal(token, TokenCaret{}) {
                type = Ptr{
                    type = &type,
                    constant = true,
                }
            } else {
                break
            }
        }

        subtype := parse_type(self)
        parse_set_ptr_type(self, &type, subtype)
    case TokenStar:
        type = Ptr{
            type = new(Type),
            constant = false,
        }
        token_next(self)

        for token = token_peek(self); token != nil; token = token_peek(self) {
            if token_tag_equal(token, TokenStar{}) {
                type = Ptr{
                    type = &type,
                    constant = false,
                }
            } else if token_tag_equal(token, TokenCaret{}) {
                type = Ptr{
                    type = &type,
                    constant = true,
                }
            } else {
                break
            }
        }

        subtype := parse_type(self)
        parse_set_ptr_type(self, &type, subtype)
    case TokenLs:
        for leftsquare := token_peek(self); leftsquare != nil; leftsquare = token_peek(self) {
            if !token_tag_equal(leftsquare, TokenLs{}) {
                break
            }
            token_next(self)

            after := token_peek(self)
            if token_tag_equal(after, TokenIntLit{}) {
                len := new(Expr); len^ = parse_expr(self)
                token_expect(self, TokenRs{})

                array_type := Array{
                    type = new(Type),
                    len = len,
                    cursors_idx = self.cursors_idx,
                }

                #partial switch &t in type {
                case nil:
                    type = array_type
                case Array:
                    subtype := new(Type); subtype^ = array_type
                    t.type = subtype
               }
            } else if token_tag_equal(after, TokenUnderscore{}) {
                token_next(self)
                token_expect(self, TokenRs{})

                array_type := Array{
                    type = new(Type),
                    len = nil,
                    cursors_idx = self.cursors_idx,
                }

                #partial switch &t in type {
                case nil:
                    type = array_type
                case Array:
                    subtype := new(Type); subtype^ = array_type
                    t.type = subtype
               }
            } else {
                elog(self, self.cursors_idx, "expected an integer or underscore, got %v", after)
            }
        }

        subtype := parse_type(self)
        parse_set_array_type(self, &type, subtype)
    case TokenIdent:
        token_next(self)
        converted_ident := convert_ident(self, tok)

        if subtype, ok := converted_ident.(Type); ok {
            type = subtype
        } else {
            elog(self, self.cursors_idx, "expected a type, got %v", tok.ident)
        }
    }

    return type
}

parse_decl :: proc(self: ^Parser, ident: Ident) -> Stmnt {
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
    case:
        type := parse_type(self)

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
    }

    return nil
}

parse_var_reassign :: proc(self: ^Parser, ident: Expr, expect_semicolon := true) -> VarReassign {
    // <name> = 
    expr := parse_expr(self)
    if expect_semicolon do token_expect(self, TokenSemiColon{})

    return VarReassign{
        name = ident,
        type = nil,
        value = expr,
        cursors_idx = self.cursors_idx,
    }
}

parse_var_operator_equal :: proc(self: ^Parser, ident: Expr, operator: Token, expect_semicolon := true) -> VarReassign {
    // <name> [+-*/]= 
    operator_index := self.cursors_idx
    var := new(Expr); var^ = ident
    expr := new(Expr); expr^ = parse_expr(self)
    group := new(Expr); group^ = Grouping{
        value = expr,
        type = nil,
        cursors_idx = self.cursors_idx
    }
    if expect_semicolon do token_expect(self, TokenSemiColon{})

    reassign := VarReassign{
        name = ident,
        type = nil,
        cursors_idx = self.cursors_idx
    }

    #partial switch _ in operator {
    case TokenPlus:
        reassign.value = Plus{
            left = var,
            right = group,
            type = nil,
            cursors_idx = operator_index,
        }
    case TokenMinus:
        reassign.value = Minus{
            left = var,
            right = group,
            type = nil,
            cursors_idx = operator_index,
        }
    case TokenStar:
        reassign.value = Multiply{
            left = var,
            right = group,
            type = nil,
            cursors_idx = operator_index,
        }
    case TokenSlash:
        reassign.value = Divide{
            left = var,
            right = group,
            type = nil,
            cursors_idx = operator_index,
        }
    }

    return reassign
}

// expects "." already nexted
parse_field_access :: proc(self: ^Parser, ident: Expr) -> Expr {
    // <ident>.

    index := self.cursors_idx
    front := new(Expr); front^ = ident

    // <ident>.&
    token := token_next(self)
    if token_tag_equal(token, TokenAmpersand{}) {
        field := new(Expr); field^ = Deref{
            cursors_idx = self.cursors_idx
        }

        return FieldAccess{
            expr = front,
            field = field,
            type = nil,
            constant = false,
            cursors_idx = index,
        }
    }

    //<ident>.<ident>
    if !token_tag_equal(token, TokenIdent{}) {
        elog(self, self.cursors_idx, "unexpected token %v after field access", token)
    }

    converted_ident := convert_ident(self, token.(TokenIdent))
    if id, ok := converted_ident.(Ident); ok {
        field := new(Expr); field^ = id

        fieldaccess := FieldAccess{
            expr = front,
            field = field,
            type = nil,
            constant = false,
            cursors_idx = index,
        }

        token = token_peek(self)
        if token_tag_equal(token, TokenDot{}) {
            token_next(self)
            return parse_field_access(self, fieldaccess)
        } else if token_tag_equal(token, TokenLs{}) {
            token_next(self)
            return parse_array_index(self, fieldaccess)
        }

        return fieldaccess
    } else {
        elog(self, self.cursors_idx, "unexpected token %v after field access", token)
    }
}

// expects [ already nexted
parse_array_index :: proc(self: ^Parser, ident: Expr) -> Expr {
    // <ident>[

    intlit_cursor_index := self.cursors_idx
    index := new(Expr); index^ = parse_expr(self)
    token_expect(self, TokenRs{})
    // <ident>[<index>]
    
    i := new(Expr); i^ = ident
    arrindex := ArrayIndex{
        ident = i,
        index = index,
        type = nil,
        cursors_idx = self.cursors_idx
    }

    // check for field access
    token := token_peek(self)
    if token_tag_equal(token, TokenDot{}) {
        token_next(self)
        return parse_field_access(self, arrindex)
    } else if token_tag_equal(token, TokenLs{}) {
        token_next(self)
        return parse_array_index(self, arrindex)
    }

    return arrindex
}

parse_ident :: proc(self: ^Parser, ident: Ident) -> Stmnt {
    ident_index := self.cursors_idx
    
    token := token_peek(self)
    if token == nil do return nil

    // <ident>. OR <ident>[
    #partial switch tok in token {
    case TokenDot:
        token_next(self)
        reassigned := parse_field_access(self, ident)

        token = token_peek(self)
        if token == nil do return nil

        #partial switch after in token {
        case TokenPlus, TokenMinus, TokenStar, TokenSlash:
            token_next(self) // no nil check, already checked when peeked
            token_after := token_next(self)

            if token_tag_equal(token_after, TokenEqual{}) {
                return parse_var_operator_equal(self, reassigned, after)
            } else {
                elog(self, self.cursors_idx, "unexpected token %v", after)
            }
        case TokenEqual:
            token_next(self) // no nil check, already checked when peeked
            return parse_var_reassign(self, reassigned);
        }
    case TokenLs:
        token_next(self)
        arr_index := parse_array_index(self, ident)

        token = token_peek(self)
        if token == nil do return nil

        #partial switch after in token {
        case TokenPlus, TokenMinus, TokenStar, TokenSlash:
            token_next(self) // no nil check, already checked when peeked
            token_after := token_next(self)

            if token_tag_equal(token_after, TokenEqual{}) {
                return parse_var_operator_equal(self, arr_index, after)
            } else {
                elog(self, self.cursors_idx, "unexpected token %v", tok)
            }
        case TokenEqual:
            token_next(self) // no nil check, already checked when peeked
            return parse_var_reassign(self, arr_index);
        }
    }

    #partial switch tok in token {
    case TokenColon:
        token_next(self) // no nil check, already checked when peeked
        return parse_decl(self, ident)
    case TokenPlus, TokenMinus, TokenStar, TokenSlash:
        token_next(self) // no nil check, already checked when peeked
        token_after := token_next(self)

        if token_tag_equal(token_after, TokenEqual{}) {
            return parse_var_operator_equal(self, ident, tok)
        } else {
            elog(self, self.cursors_idx, "unexpected token %v", tok)
        }
    case TokenEqual:
        token_next(self) // no nil check, already checked when peeked
        return parse_var_reassign(self, ident);
    case TokenLb:
        stmnt := parse_fn_call(self, ident).(FnCall)
        token_expect(self, TokenSemiColon{})
        return stmnt
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

    capture_tok := token_peek(self)
    capture: Maybe(union{Ident, ConstDecl}) = nil
    // if (<condition>) <[capture]>
    if token_tag_equal(capture_tok, TokenLs{}) {
        token_next(self)

        capture_tok = token_expect(self, TokenIdent{})
        converted := convert_ident(self, capture_tok.(TokenIdent))
        if _, ok := converted.(Ident); ok {
            capture = converted.(Ident)
        } else {
            elog(self, self.cursors_idx, "capture must be a unique identifier")
        }
        token_expect(self, TokenRs{})
    }

    body := parse_block(self)

    else_block: [dynamic]Stmnt
    
    if token := token_peek(self); token_tag_equal(token, TokenIdent{}) {
        converted := convert_ident(self, token.(TokenIdent))
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
        capture = capture,
        els = else_block,
        cursors_idx = index,
    }
}

parse_extern :: proc(self: ^Parser) -> Stmnt {
    index := self.cursors_idx
    stmnt := parse(self)
    return Extern{
        body = [dynamic]Stmnt{stmnt},
        cursors_idx = index,
    }
}

parse_for :: proc(self: ^Parser) -> Stmnt {
    index := self.cursors_idx

    token_expect(self, TokenLb{})
    token_ident := token_expect(self, TokenIdent{})
    converted := convert_ident(self, token_ident.(TokenIdent))
    ident: Ident
    if id, ok := converted.(Ident); ok {
        ident = id
    } else {
        elog(self, self.cursors_idx, "expected identifer, got %v", converted)
    }

    // for (i: 
    token := token_peek(self)
    if token_tag_equal(token, TokenColon{}) {
        token_next(self)
        token = token_peek(self)

        vardecl: VarDecl
        if token_tag_equal(token, TokenEqual{}) {
            // for (i :=
            token_next(self)
            vardecl = parse_var_decl(self, ident).(VarDecl)
        } else if token_tag_equal(token, TokenIdent{}) {
            // for (i: <type>
            type := parse_type(self)
            token_expect(self, TokenEqual{})
            vardecl = parse_var_decl(self, ident, type).(VarDecl)
        } else {
            elog(self, self.cursors_idx, "unexpected token %v in for loop", token)
        }

        // for (i: <type> = <expr>; <condition>)
        condition := parse_expr(self)
        token_expect(self, TokenSemiColon{})

        reassign: VarReassign
        token = token_peek(self)
        if token_ident, ok := token.(TokenIdent); ok {
            token_next(self)
            token = token_peek(self)

            #partial switch tok in token {
            case TokenPlus, TokenMinus, TokenStar, TokenSlash:
                token_next(self)
                token_after := token_next(self)

                // for (i: <type> = <expr>; <condition>; i [+-*/]=)
                if token_tag_equal(token_after, TokenEqual{}) {
                    reassign = parse_var_operator_equal(self, ident, tok, false)
                } else {
                    elog(self, self.cursors_idx, "unexpected token %v", tok)
                }
            case TokenEqual:
                // for (i: <type> = <expr>; <condition>; i =)
                token_next(self)
                reassign = parse_var_reassign(self, ident, false);
            }
        }
        token_expect(self, TokenRb{})

        body := parse_block(self)

        return For{
            decl = vardecl,
            condition = condition,
            reassign = reassign,
            body = body,
            cursors_idx = index,
        }
    } else {
        // TODO: support `for (values) [value]`
        elog(self, self.cursors_idx, "expected ':', got %v", token)
    }
}

parse_directive :: proc(self: ^Parser) -> Stmnt {
    token := token_next(self)
    directive := parser_get_directive(self, token.(TokenDirective).literal)

    switch &d in directive {
    case DirectiveLink:
        d.cursors_idx = self.cursors_idx

        token = token_expect(self, TokenStrLit{})
        token_expect(self, TokenSemiColon{});

        d.link = token.(TokenStrLit).literal
    }

    return directive
}

parse :: proc(self: ^Parser) -> Stmnt {
    token := token_peek(self)
    if token == nil do return nil

    #partial switch tok in token {
    case TokenIdent:
        token_next(self) // no nil check, already checked when peeked
        converted_ident := convert_ident(self, tok)

        if ident, ident_ok := converted_ident.(Ident); ident_ok {
            return parse_ident(self, ident)
        } else if keyword, keyword_ok := converted_ident.(Keyword); keyword_ok {
            #partial switch keyword {
            case .Return:
                return parse_return(self)
            case .If:
                return parse_if(self)
            case .Extern:
                return parse_extern(self)
            case .For:
                return parse_for(self)
            }
        }
    case TokenLc:
        index := self.cursors_idx
        return Block{
            body = parse_block(self),
            cursors_idx = index,
        }
    case TokenDirective:
        return parse_directive(self)
    case:
        token_next(self)
        elog(self, self.cursors_idx, "unexpected token %v", tok)
    }
    return nil
}
