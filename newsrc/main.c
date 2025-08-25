#include <time.h>
#include <stdbool.h>
#include "include/exprs.h"
#include "include/lexer.h"
#include "include/stmnts.h"
#include "include/utils.h"
#include "include/cli.h"
#include "include/parser.h"
#include "include/sema.h"
#include "include/gen.h"

#define STB_DS_IMPLEMENTATION
#include "include/stb_ds.h"

const bool DEBUG_MODE = true;

void print_ast(Stmnt *ast, Cursor *cursors) {
    for (size_t i = 0; i < arrlenu(ast); i++) {
        print_stmnt(ast[i], cursors, 0);
    }
}

void build(char *filepath) {
    char *content;
    bool content_ok = read_entire_file(filepath, &content);
    if (!content_ok) {
        comp_elog("failed to read %s", filepath);
    }

    Lexer lex = lexer(content);
    if (arrlen(lex.tokens) != arrlen(lex.cursors)) comp_elog("expected length of tokens and length of cursors to be the same");

    if (DEBUG_MODE) {
        print_tokens(lex.tokens);
        printfln("");
    }

    Arr(Stmnt) ast = NULL;
    Parser parser = parser_init(lex, filepath);
    for (Stmnt stmnt = parser_parse(&parser); stmnt.kind != SkNone; stmnt = parser_parse(&parser)) {
        arrpush(ast, stmnt);
    }

    Sema sema = sema_init(ast, filepath, lex.cursors);
    sema_analyse(&sema);

    if (DEBUG_MODE) {
        print_ast(ast, parser.cursors);
    }

    Gen gen = gen_init(ast, sema.dgraph);
    gen_generate(&gen);

    write_entire_file("output.h", gen.defs);
    write_entire_file("output.c", gen.code);

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
