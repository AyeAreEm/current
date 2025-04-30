package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:os/os2"

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

get_filename :: proc(path: string) -> string {
    filename: string
    path_parts: []string
    defer delete(path_parts)

    if strings.contains(path[0:2], "./") {
        path_parts = strings.split(path[2:], ".")
    } else if strings.contains(path[0:2], ".\\") {
        path_parts = strings.split(path[3:], ".")
    } else {
        path_parts = strings.split(path, ".")
    }

    filename = strings.clone(path_parts[0])
    return filename
}

compile :: proc(filepath: string, linking: [dynamic]string, run := false) {
    filename := get_filename(filepath)

    compile_com := make([dynamic]string)
    append(&compile_com, "zig")
    append(&compile_com, "build-exe" if !run else "run")
    append(&compile_com, "--name")
    append(&compile_com, filename)
    append(&compile_com, "output.zig")

    for link in linking {
        append(&compile_com, link)
    }

    if DEBUG_MODE {
        for com in compile_com {
            fmt.printf("%v ", com)
        }
        fmt.println("")
    }

    state, stdout, stderr, process_err := os2.process_exec(os2.Process_Desc{
        command = compile_com[:],
    }, context.temp_allocator)
    defer if process_err != nil {
        delete(stdout)
        delete(stderr)
    }

    fmt.print(cast(string)stdout)
    fmt.print(cast(string)stderr)

    if !DEBUG_MODE {
        os2.remove("output.zig")
    }
}

build :: proc(filename: string) -> [dynamic]string {
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
    return codegen.linking
}

main :: proc() {
    args := os.args
    if len(args) == 1 {
        usage()
        os.exit(1)
    }

    arg0 := args_next(&args, "")
    command := args_next(&args, arg0)
    filename := args_next(&args, command)

    if strings.compare(command, "build") == 0 {
        linking := build(filename)
        compile(filename, linking)
    } else if strings.compare(command, "run") == 0 {
        linking := build(filename)
        compile(filename, linking, true)
    } else {
        elog("unexpected command %v", command)
    }
}
