package cli

import "core:fmt"
import "core:strings"
import "core:os"

Command :: enum {
    Build = 1,
    Run,
}
commands := [?]string{
    "build",
    "run",
}

Cli :: struct {
    command: Command,
    help: bool,
    filename: string,
}

elog :: proc(format: string, args: ..any) -> ! {
    fmt.eprintf("\x1b[91;1merror\x1b[0m: ")
    fmt.eprintfln(format, ..args)

    os.exit(1)
}

args_next :: proc(args: ^[]string) -> string {
    if len(args) == 0 {
        elog("expected another argument")
    }

    arg := args[0]
    args^ = args[1:]
    return arg
}

is_command :: proc(arg: string) -> bool {
    for com in commands {
        if strings.compare(arg, com) == 0 {
            return true
        }
    }
    return false
}

parse_help :: proc(cli: ^Cli, args: ^[]string) {
    if cli.help {
        elog("unexpected help, help option already set")
    }
    cli.help = true

    if len(args^) != 0 {
        arg := args_next(args)
        elog("unexpected %v option after help", arg)
    }
}

parse_build :: proc(cli: ^Cli, args: ^[]string) {
    if cast(int)cli.command != 0 {
        elog("unexpected build, %v option already set", commands[cast(int)cli.command - 1])
    }

    cli.command = .Build
    arg := args_next(args)
    if is_command(arg) {
        elog("unexpected %v, expected filename or help", arg)
    }

    if strings.compare(arg, "help") == 0 {
        parse_help(cli, args)
        return
    }

    cli.filename = arg
}

parse_run :: proc(cli: ^Cli, args: ^[]string) {
    if cast(int)cli.command != 0 {
        elog("unexpected run, %v option already set", commands[cast(int)cli.command - 1])
    }

    cli.command = .Run
    arg := args_next(args)
    if is_command(arg) {
        elog("unexpected %v, expected filename or help", arg)
    }

    if strings.compare(arg, "help") == 0 {
        parse_help(cli, args)
        return
    }

    cli.filename = arg
}

parse :: proc() -> (cli: Cli) {
    args := os.args
    args = args[1:]

    for i := 0; i < len(args); i += 1 {
        arg := args_next(&args)

        if strings.compare(arg, "build") == 0 {
            parse_build(&cli, &args)
        } else if strings.compare(arg, "run") == 0 {
            parse_run(&cli, &args)
        } else if strings.compare(arg, "help") == 0 {
            parse_help(&cli, &args)
        }
    }

    return
}

usage :: proc(cli: Cli) -> ! {
    switch cli.command {
    case .Build:
        fmt.println("USAGE:")
        fmt.println("    build [filename]")
        fmt.println("    generate executable with a given file")
        fmt.println()
        os.exit(0)
    case .Run:
        fmt.println("USAGE:")
        fmt.println("    run [filename]")
        fmt.println("    generate executable with a given file and run it")
        fmt.println()
        os.exit(0)
    case:
        if cli.help {
            fmt.println("USAGE:")
            fmt.println("    build [filename.cur] | build executable")
            fmt.println("    run [filename.cur] | build and run executable")
            fmt.println()
            os.exit(0)
        }

        fmt.eprintln("USAGE:")
        fmt.eprintln("    build [filename.cur] | build executable")
        fmt.eprintln("    run [filename.cur] | build and run executable")
        fmt.eprintln()
        os.exit(1)
    }
}
