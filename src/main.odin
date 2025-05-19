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

// warning: this frees sb and returns a newly allocated string
@(require_results)
sbinsert :: proc(sb: ^strings.Builder, str: string, index: int) -> strings.Builder {
    code := strings.builder_make()

    first_half := sb.buf[:index]
    strings.write_bytes(&code, first_half)
    strings.write_string(&code, str)

    second_half := sb.buf[index:]
    strings.write_bytes(&code, second_half)

    delete(sb.buf)

    return code
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
    append(&compile_com, "gcc")
    append(&compile_com, "-o")
    append(&compile_com, filename)
    append(&compile_com, "output.c")

    for link in linking {
        if strings.compare(link, "libc") == 0 {
            append(&compile_com, "-lc")
        } else {
            l := fmt.aprintf("-L", link)
            // NOTE: ^ this leaks memory but the process will free it
            append(&compile_com, l)
        }
    }

    if DEBUG_MODE {
        for com in compile_com {
            fmt.printf("%v ", com)
        }
        fmt.println("")
    }

    _, compile_stdout, compile_stderr, compile_process_err := os2.process_exec(os2.Process_Desc{
        command = compile_com[:],
    }, context.temp_allocator)
    defer if compile_process_err != nil {
        delete(compile_stdout)
        delete(compile_stderr)
    }

    fmt.print(cast(string)compile_stdout)
    fmt.print(cast(string)compile_stderr)

    if run {
        run_com := make([dynamic]string)
        exe := fmt.aprintf("./%v", filename) if ODIN_OS == .Linux else fmt.aprintf("./%v.exe", filename)
        defer delete(exe)

        append(&run_com, exe)
        _, run_stdout, run_stderr, run_process_err := os2.process_exec(os2.Process_Desc{
            command = run_com[:],
        }, context.temp_allocator)

        defer if run_process_err != nil {
            delete(run_stdout)
            delete(run_stderr)
        }

        fmt.print(cast(string)run_stdout)
        fmt.print(cast(string)run_stderr)
    }

    if !DEBUG_MODE {
        os2.remove("output.c")
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
            fmt.println(stmnt)
        }
    }

    codegen := codegen_init(ast, symtab)
    gen(&codegen);

    os.write_entire_file("output.c", codegen.code.buf[:])
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
