#ifndef GEN_H
#define GEN_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include "exprs.h"
#include "sema.h"
#include "stmnts.h"
#include "stb_ds.h"
#include "strb.h"

typedef enum OptLevel {
    OlZero,
    OlOne,
    OlTwo,
    OlThree,
    OlDebug,
    OlFast,
    OlSmall,
} OptLevel;

typedef struct CompileFlags {
    bool keepc;
    OptLevel optimisation;
    Arr(const char*) links;
    const char *output;
} CompileFlags;

typedef struct Defer {
    Stmnt *stmnt;
    uint8_t indent;
} Defer;

typedef struct Gen {
    Arr(Stmnt) ast;

    strb code;
    strb defs;

    uint8_t indent;
    Arr(Defer) defers;

    bool in_defs;
    Dgraph dgraph;
    size_t def_loc;

    size_t code_loc;


    Arr(const char*) generated_typedefs;
    CompileFlags compile_flags;
} Gen;

typedef struct MaybeAllocStr {
    char *str;
    bool alloced;
} MaybeAllocStr;

void gen_extern(Gen *gen, Stmnt stmnt);
void gen_fn_decl(Gen *gen, Stmnt stmnt, bool is_extern);
void gen_decl_generic(Gen *gen, Type type);
void gen_generate(Gen *gen);
MaybeAllocStr gen_expr(Gen *gen, Expr expr);
MaybeAllocStr gen_type(Gen *gen, Type type);
void gen_typename(Gen *gen, Type *types, size_t types_len, strb *);
void gen_stmnt(Gen *gen, Stmnt *stmnt);
void gen_block(Gen *gen, Arr(Stmnt) stmnt);
Gen gen_init(Arr(Stmnt) ast, Dgraph dgraph);

#endif // GEN_H
