package main

import "core:fmt"
import "core:os"
import "core:strings"

DEBUG_MODE :: false

args_next :: proc(args: ^[]string, arg: string) -> string {
    if len(args) == 0 {
        elog("expected another argument")
    }

    arg := args[0]
    args^ = args[1:]
    return arg
}

debug :: proc(format: string, args: ..any) {
    fmt.eprint("[DEBUG]: ")
    fmt.eprintfln(format, ..args)
}

usage :: proc() {
    fmt.eprintln("USAGE: ")
    fmt.eprintln("    build [filename.cur] | build executable")
}

current_elog :: proc(format: string, args: ..any) -> ! {
    fmt.eprintf("\x1b[91;1merror\x1b[0m: ")
    fmt.eprintfln(format, ..args)
    usage()

    os.exit(1)
}

elog :: proc{current_elog, parser_elog, analyse_elog}

build :: proc(filename: string) {
    content_bytes, content_bytes_ok := os.read_entire_file(filename)
    if !content_bytes_ok {
        elog("failed to read %v", filename)
    }

    content := transmute(string)content_bytes
    tokens, cursors := lexer(content)
    assert(len(tokens) == len(cursors), "expected the length of tokens and length of cursors to be the same")

    // TODO: add another pass to get definitions
    ast := [dynamic]Stmnt{}
    parser := parser_init(tokens, filename, cursors)
    for stmnt := parse(&parser); stmnt != nil; stmnt = parse(&parser) {
        append(&ast, stmnt)
    }

    symtab := symtab_init()
    analyser := analyser_init(ast, symtab, filename, cursors)
    analyse(&analyser)

    if DEBUG_MODE {
        for stmnt in ast {
            stmnt_print(stmnt)
        }
    }

    codegen := codegen_init(ast, symtab)
    gen(&codegen);

    os.write_entire_file("output.zig", codegen.code.buf[:])
}

main :: proc() {
    args := os.args
    if len(args) == 1 {
        usage()
        os.exit(1)
    }

    arg0 := args_next(&args, "")
    command := args_next(&args, arg0)

    if strings.compare(command, "build") == 0 {
        filename := args_next(&args, command)
        build(filename)
    } else {
        elog("unexpected command %v", command)
    }
}
