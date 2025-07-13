#include "include/lexer.h"
#include "include/utils.h"
#include "include/cli.h"

#define STB_DS_IMPLEMENTATION
#include "include/stb_ds.h"

void build(char *filepath) {
    char *content;
    bool content_ok = read_file(filepath, &content);
    if (!content_ok) {
        elog("failed to read %s", filepath);
    }

    Lexer lex = lexer(content);
    if (arrlen(lex.tokens) != arrlen(lex.cursors)) elog("expected length of tokens and length of cursors to be the same");

    print_tokens(lex.tokens);

    free(content);
}

int main(int argc, char **argv) {
    Cli args = cli_parse(argv, argc);

    switch (args.command) {
        case CommandBuild:
        {
            build(args.filename);
        } break;
        case CommandRun:
        {
            build(args.filename);
        } break;
        default: break;
    }

    return 0;
}
