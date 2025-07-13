#ifndef CLI_H
#define CLI_H

#include <stdbool.h>

typedef enum Command {
    CommandBuild = 0,
    CommandRun,
    CommandCOUNT,
} Command;

typedef struct Cli {
    Command command;
    bool help;
    char *filename;
} Cli;

void cli_usage(Cli cli);
Cli cli_parse(char **argv, int argc);

#endif // CLI_H
