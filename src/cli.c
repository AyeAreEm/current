#include <stdarg.h>
#include <stdlib.h>
#include "include/cli.h"
#include "include/utils.h"

const char *cli_commands[CommandCOUNT] = { "build", "run" };

static Cli cli_init(void) {
    return (Cli){
        .help = false,
        .command = CommandNone,
        .keepc = false,
        .filename = "",
    };
}

static char *cli_args_peek(char ***argv, int *argc) {
    if (*argc == 0) {
        comp_elog("expected another argument");
    }

    return (*argv)[0];
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
    char *arg = cli_args_peek(argv, argc);
    if (cli_is_command(arg)) {
        comp_elog("unexpected %s, expected filename or help", arg);
    }

    cli->filename = arg;
}

static void cli_parse_run(Cli *cli, char ***argv, int *argc) {
    if (cli->command != CommandNone) {
        comp_elog("unexpected run, %s option already set", cli_commands[cli->command]);
    }

    cli->command = CommandRun;
    char *arg = cli_args_peek(argv, argc);
    if (cli_is_command(arg)) {
        comp_elog("unexpected %s, expected filename or help", arg);
    }

    cli->filename = arg;
}

void cli_usage(Cli cli, bool force) {
    if (!cli.help && !force) {
        return;
    }

    switch (cli.command) {
        case CommandBuild:
        {
            printfln("USAGE:");
            printfln("    build [filename]");
            printfln("    generate executable with entry point file");
            exit(0);
        } break;
        case CommandRun:
        {
            printfln("USAGE:");
            printfln("    run [filename]");
            printfln("    generate executable with entry point file and immediately run it");
            exit(0);
        } break;
        default:
        {
            printfln("USAGE:");
            printfln("    build [filename.cur] | build executable");
            printfln("    run [filename.cur] | build and run executable");
            printfln("    help | print this usage message (can be used after a command for specific usage)");
            exit(force);
        } break;
    }
}

Cli cli_parse(char **argv, int argc) {
    Cli cli = cli_init();
    cli_args_next(&argv, &argc);

    while (argc != 0) {
        char *arg = cli_args_next(&argv, &argc);

        if (streq(arg, "build")) {
            cli_parse_build(&cli, &argv, &argc);
        } else if (streq(arg, "run")) {
            cli_parse_run(&cli, &argv, &argc);
        } else if (streq(arg, "help")) {
            debug("here");
            cli_parse_help(&cli, &argv, &argc);
        } else if (streq(arg, "-keepc")) {
            cli.keepc = true;
        }
    }

    return cli;
}
