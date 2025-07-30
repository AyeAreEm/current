#include <stdarg.h>
#include <stdlib.h>
#include "include/cli.h"
#include "include/utils.h"

const char *cli_commands[CommandCOUNT] = { "build", "run" };

static Cli cli_init(void) {
    return (Cli){
        .help = false,
        .command = CommandNone,
        .filename = "",
    };
}

static char *cli_args_next(char ***argv, int *argc) {
    if (*argc == 0) {
        comp_elog("expected another argument");
    }

    char *arg = (*argv)[0];
    *argv += 1;
    *argc -= 1;
    return arg;
}

static bool cli_is_command(const char *arg) {
    for (int i = 0; i < CommandCOUNT; i++) {
        if (streq(arg, cli_commands[i])) return true;
    }
    return false;
}

static void cli_parse_help(Cli *cli, char ***argv, int *argc) {
    if (cli->help) {
        comp_elog("unexpected help, help option already set");
    }
    cli->help = true;

    if (*argc != 0) {
        char *arg = cli_args_next(argv, argc);
        comp_elog("unexpected %s option after help", arg);
    }
}

static void cli_parse_build(Cli *cli, char ***argv, int *argc) {
    if (cli->command != CommandNone) {
        comp_elog("unexpected build, %s option already set", cli_commands[cli->command]);
    }

    cli->command = CommandBuild;
    char *arg = cli_args_next(argv, argc);
    if (cli_is_command(arg)) {
        comp_elog("unexpected %s, expected filename or help", arg);
    }

    if (streq(arg, "help")) {
        cli_parse_help(cli, argv, argc);
        return;
    }

    cli->filename = arg;
}

static void cli_parse_run(Cli *cli, char ***argv, int *argc) {
    if (cli->command != CommandNone) {
        comp_elog("unexpected run, %s option already set", cli_commands[cli->command]);
    }

    cli->command = CommandRun;
    char *arg = cli_args_next(argv,argc);
    if (cli_is_command(arg)) {
        comp_elog("unexpected %s, expected filename or help", arg);
    }

    if (streq(arg, "help")) {
        cli_parse_help(cli, argv, argc);
        return;
    }

    cli->filename = arg;
}

void cli_usage(Cli cli) {
    switch (cli.command) {
        case CommandBuild:
        {
            printfln("USAGE:");
            printfln("    build [filename]");
            printfln("    generate executable with a given file");
            printfln("");
            exit(0);
        } break;
        case CommandRun:
        {
            printfln("USAGE:");
            printfln("    run [filename]");
            printfln("    generate executable with a given file and run it");
            printfln("");
            exit(0);
        } break;
        default:
        {
            printfln("USAGE:");
            printfln("    build [filename.cur] | build executable");
            printfln("    run [filename.cur] | build and run executable");
            printfln("");
            exit(0);
        } break;
    }
}

Cli cli_parse(char **argv, int argc) {
    Cli cli = cli_init();
    cli_args_next(&argv, &argc);

    for (int i = 0; i < argc; i++) {
        char *arg = cli_args_next(&argv, &argc);

        if (streq(arg, "build")) {
            cli_parse_build(&cli, &argv, &argc);
        } else if (streq(arg, "run")) {
            cli_parse_run(&cli, &argv, &argc);
        } else if (streq(arg, "help")) {
            cli_parse_help(&cli, &argv, &argc);
        }
    }

    if (cli.help) {
        cli_usage(cli);
    }

    return cli;
}
