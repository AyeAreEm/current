package main

import "core:fmt"
import "core:strings"
import "core:os"
import "core:os/os2"

current_elog :: proc(format: string, args: ..any) -> ! {
    fmt.eprintf("\x1b[91;1merror\x1b[0m: ")
    fmt.eprintfln(format, ..args)

    os.exit(1)
}

elog :: proc{current_elog, parser_elog, analyse_elog}

debug :: proc(format: string, args: ..any) {
    fmt.eprint("\x1b[93;1m[DEBUG]\x1b[0m: ")
    fmt.eprintfln(format, ..args)
}

// returns allocated string, needs to be freed
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

get_c_compiler :: proc() -> string {
    gcc_state, _, _, _ := os2.process_exec(os2.Process_Desc{
        command = { "gcc", "-v" },
    }, context.temp_allocator)

    if gcc_state.exit_code == 0 {
        return "gcc"
    }

    clang_state, _, _, _ := os2.process_exec(os2.Process_Desc{
        command = { "clang", "-v" },
    }, context.temp_allocator)

    if clang_state.exit_code == 0 {
        return "clang"
    }

    elog("gcc or clang not detected, please ensure you have one of these compilers")
}
