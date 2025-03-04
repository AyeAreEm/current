package main

import "core:fmt"
import "core:os"

SymTab :: struct {
    scopes: [dynamic]map[string]Stmnt,
    curr_scope: uint,
}

symtab_find :: proc(using symtab: ^SymTab, key: string) -> Stmnt {
    elem, ok := scopes[curr_scope][key]
    if !ok {
        elog(cursors_idx, "use of undefined \"%v\"", key)
    }

    return elem
}

symtab_push :: proc(using symtab: ^SymTab, key: string, value: Stmnt) {
    _, ok := scopes[curr_scope][key]
    if !ok {
        scopes[curr_scope][key] = value
        return
    }

    elog(cursors_idx, "redeclaration of \"%v\"", key)
}

symtab_new_scope :: proc(using symtab: ^SymTab) {
    append(&scopes, scopes[curr_scope])
    curr_scope += 1
}

symtab_pop_scope :: proc(using symtab: ^SymTab) {
    pop(&scopes)
    curr_scope -= 1
}

Parser :: struct {
    tokens: [dynamic]Token,
    cursors: [dynamic][2]u32,
}

Analyser :: struct {
    ast: [dynamic]Stmnt,
    symtab: SymTab,
    cursors: [dynamic][2]u32,
}

testing_filename :: "./test.x"

cursors: [dynamic][2]u32
cursors_idx := 0

elog :: proc(i: int, format: string, args: ..any) -> ! {
    fmt.eprintf("%v:%v:%v error: ", testing_filename, cursors[i][0], cursors[i][1])
    fmt.eprintfln(format, ..args)

    os.exit(1)
}

main :: proc() {
    content_bytes, content_bytes_ok := os.read_entire_file(testing_filename)
    if !content_bytes_ok {
        fmt.eprintfln("failed to read %v", testing_filename)
        os.exit(1)
    }

    content := transmute(string)content_bytes
    tokens, cursor := lexer(content)
    assert(len(tokens) == len(cursor), "expected the length of tokens and length of cursors to be the same")

    cursors = cursor

    parser := Parser {
        tokens = tokens, // NOTE: does this do a copy? surely not
        cursors = cursors,
    }

    ast := [dynamic]Stmnt{}
    for stmnt := parse(&parser); stmnt != nil; stmnt = parse(&parser) {
        append(&ast, stmnt)
        // stmnt_print(stmnt)
    }

    symtab := SymTab{
        scopes = [dynamic]map[string]Stmnt{},
        curr_scope = 0,
    }
    append(&symtab.scopes, map[string]Stmnt{})

    env := Analyser{
        ast = ast,
        symtab = symtab,
    }

    analyse(&env)
    for stmnt in env.ast {
        stmnt_print(stmnt)
    }
}
