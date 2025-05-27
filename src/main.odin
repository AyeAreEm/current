package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:os/os2"
import "cli"

DEBUG_MODE :: false

compile :: proc(filepath: string, linking: [dynamic]string, run: bool) {
    cc: string
    gcc_state, _, _, _ := os2.process_exec(os2.Process_Desc{
        command = { "gcc", "-v" },
    }, context.temp_allocator)
    if gcc_state.exit_code != 0 {
        clang_state, _, _, _ := os2.process_exec(os2.Process_Desc{
            command = { "gcc", "-v" },
        }, context.temp_allocator)

        if clang_state.exit_code != 0 {
            elog("gcc or clang not detected, please ensure you have one of these compilers")
        } else {
            cc = "clang"
        }
    } else {
        cc = "gcc"
    }

    // allocated but near the end of the proces
    // no need to clean up
    filename := get_filename(filepath)

    compile_com := make([dynamic]string)
    append(&compile_com, cc)
    append(&compile_com, "-o")
    append(&compile_com, filename)
    append(&compile_com, "output.c")

    for link in linking {
        append(&compile_com, link);
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
        exe := fmt.aprintf("./%v.exe", filename) if ODIN_OS == .Windows else fmt.aprintf("./%v", filename)
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

build :: proc(filename: string, run := false) {
    content_bytes, content_bytes_ok := os.read_entire_file(filename)
    if !content_bytes_ok {
        elog("failed to read %v", filename)
    }
    defer delete(content_bytes)

    content := transmute(string)content_bytes
    tokens, cursors := lexer(content)
    assert(len(tokens) == len(cursors), "expected the length of tokens and length of cursors to be the same")

    // TODO: add another pass to get definitions
    ast := [dynamic]Stmnt{}
    parser := parser_init(tokens, filename, cursors)
    for stmnt := parse(&parser); stmnt != nil; stmnt = parse(&parser) {
        append(&ast, stmnt)
    }

    analyser := analyser_init(ast, filename, cursors)
    analyse(&analyser)

    if DEBUG_MODE {
        for stmnt in ast {
            fmt.println(stmnt)
        }
    }

    codegen := codegen_init(ast)
    gen(&codegen);

    os.write_entire_file("output.c", codegen.code.buf[:])
    compile(filename, codegen.linking, run)
}

main :: proc() {
    args := cli.parse()

    switch args.command {
    case .Build:
        if args.help {
            cli.usage(args)
        }

        build(args.filename)
    case .Run:
        if args.help {
            cli.usage(args)
        }

        build(args.filename, true)
    case:
        if args.help {
            cli.usage(args)
        }
    }
}
