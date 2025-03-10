package main

import "core:fmt"
import "core:os"


testing_filename :: "./test.x"

cursors: [dynamic][2]u32
cursors_idx := -1

SymTab :: struct {
    scopes: [dynamic]map[string]Stmnt,
    curr_scope: uint,
}

symtab_find :: proc(using symtab: ^SymTab, key: string, location: int) -> Stmnt {
    elem, ok := scopes[curr_scope][key]
    if !ok {
        elog(location, "use of undefined \"%v\"", key)
    }

    return elem
}

symtab_push :: proc(using symtab: ^SymTab, key: string, value: Stmnt) {
    elem, ok := scopes[curr_scope][key]
    if !ok {
        scopes[curr_scope][key] = value
        return
    }
    
    cur_index := get_cursor_index(elem)
    elog(get_cursor_index(value), "redeclaration of \"%v\" from %v:%v", key, cursors[cur_index][0], cursors[cur_index][1])
}

symtab_new_scope :: proc(using symtab: ^SymTab) {
    // maybe im dumb but i fully expected
    // append(&scopes, scopes[curr_scope])
    // to copy `scopes[curr_scope]` and append it but no, it's a reference
    // so any mutation to the newly appended scope also mutates the previous scope
    // idk how i feel about this, on one hand, no implicit copies is good.
    // on the other hand, implicit pointer is bad.

    scope := map[string]Stmnt{}

    for key, value in scopes[curr_scope] {
        scope[key] = value
    }

    append(&scopes, scope)
    curr_scope += 1
}

symtab_pop_scope :: proc(using symtab: ^SymTab) {
    pop(&scopes)
    curr_scope -= 1
}

Parser :: struct {
    tokens: [dynamic]Token,
    cursors: [dynamic][2]u32,
    in_func_decl_args: bool,
    in_func_call_args: bool,
}

Analyser :: struct {
    ast: [dynamic]Stmnt,
    symtab: SymTab,
    cursors: [dynamic][2]u32,
}

debug :: proc(format: string, args: ..any) {
    fmt.eprint("[DEBUG]: ")
    fmt.eprintfln(format, ..args)
}

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
        in_func_decl_args = false,
        in_func_call_args = false,
    }

    ast := [dynamic]Stmnt{}
    for stmnt := parse(&parser); stmnt != nil; stmnt = parse(&parser) {
        append(&ast, stmnt)
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
    debug("AST")
    for stmnt in env.ast {
        stmnt_print(stmnt, 1)
    }
}
