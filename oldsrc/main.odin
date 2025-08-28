package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:os/os2"
import "cli"

DEBUG_MODE :: false

compile :: proc(compile_flags: CompileFlags, run: bool) {
    using compile_flags

    cc := get_c_compiler()

    compile_com := make([dynamic]string)
    append(&compile_com, cc)
    append(&compile_com, "-o")
    append(&compile_com, output)
    append(&compile_com, "output.c")

    switch optimisation {
    case .Zero:
        append(&compile_com, "-O0")
    case .One:
        append(&compile_com, "-O1")
    case .Two:
        append(&compile_com, "-O2")
    case .Three:
        append(&compile_com, "-O3")
    case .Debug:
        append(&compile_com, "-Og")
        append(&compile_com, "-g")
    case .Fast:
        append(&compile_com, "-O3")
    case .Small:
        append(&compile_com, "-Os")
    }

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
        exe := fmt.aprintf("./%v.exe", output) if ODIN_OS == .Windows else fmt.aprintf("./%v", output)
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
        os2.remove("output.h")
    }
}

build :: proc(filepath: string, run := false) {
    content_bytes, content_bytes_ok := os.read_entire_file(filepath)
    if !content_bytes_ok {
        elog("failed to read %v", filepath)
    }
    defer delete(content_bytes)

    content := transmute(string)content_bytes
    tokens, cursors := lexer(content)
    assert(len(tokens) == len(cursors), "expected the length of tokens and length of cursors to be the same")

    ast := [dynamic]Stmnt{}
    parser := parser_init(tokens, filepath, cursors)
    for stmnt := parse(&parser); stmnt != nil; stmnt = parse(&parser) {
        append(&ast, stmnt)
    }

    analyser := analyser_init(ast, filepath, cursors)
    analyse(&analyser)

    if DEBUG_MODE {
        for stmnt in ast {
            fmt.println(stmnt)
        }
    }

    codegen := codegen_init(ast, analyser.def_deps)
    gen(&codegen);

    os.write_entire_file("output.h", codegen.defs.buf[:])
    os.write_entire_file("output.c", codegen.code.buf[:])

    // maybe allocated but near the end of the process
    // will let the os clean it up
    if len(codegen.compile_flags.output) == 0 {
        codegen.compile_flags.output = get_filename(filepath)
    }
    compile(codegen.compile_flags, run)
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
