#define STB_DS_IMPLEMENTATION
#include <stdbool.h>
#include "include/stb_ds.h"
#include "include/lexer.h"
#include "include/stmnts.h"
#include "include/utils.h"
#include "include/cli.h"
#include "include/parser.h"

const bool DEBUG_MODE = false;

void print_ast(Stmnt *ast, Cursor *cursors) {
    for (size_t i = 0; i < arrlenu(ast); i++) {
        print_stmnt(ast[i], cursors, 0);
    }
}

void build(char *filepath) {
    char *content;
    bool content_ok = read_file(filepath, &content);
    if (!content_ok) {
        comp_elog("failed to read %s", filepath);
    }

    Lexer lex = lexer(content);
    if (arrlen(lex.tokens) != arrlen(lex.cursors)) comp_elog("expected length of tokens and length of cursors to be the same");

    if (DEBUG_MODE) {
        print_tokens(lex.tokens);
        printfln("");
    }

    Stmnt *ast = NULL;
    Parser parser = parser_init(lex, filepath);
    for (Stmnt stmnt = parse(&parser); stmnt.kind != SkNone; stmnt = parse(&parser)) {
        arrpush(ast, stmnt);
    }

    if (DEBUG_MODE) {
        print_ast(ast, parser.cursors);
    }

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
