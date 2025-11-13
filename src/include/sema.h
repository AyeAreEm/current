#ifndef SEMA_H
#define SEMA_H

#include <stddef.h>
#include <stdbool.h>
#include "lexer.h"
#include "stb_ds.h"
#include "exprs.h"
#include "stmnts.h"

typedef struct Sema Sema;

typedef struct SymTab {
    Arr(Arr(Stmnt)) stmnts;
    Arr(Arr(const char*)) keys;
    size_t cur_scope;
} SymTab;

SymTab symtab_init(void);
Stmnt symtab_find(Sema *sema, const char *key, size_t cursor_idx);
void symtab_push(Sema *sema, const char *key, Stmnt value);
void symtab_new_scope(Sema *sema);
void symtab_pop_scope(Sema *sema);

typedef struct Dnode {
    const char *name;
    Stmnt us;
    Arr(const char*) children;
} Dnode;

typedef struct Dgraph {
    Arr(const char*) names;
    Arr(Dnode) children;
} Dgraph;

Dgraph dgraph_init(void);
void dgraph_push(Dgraph *graph, Dnode node);

typedef struct Sema {
    Stmnt *ast;
    SymTab symtab;

    struct {
        Stmnt fn; // can be SkNone
        bool forl;
    } envinfo;

    struct {
        bool output;
        bool optimise;
    } compile_flags;

    Dgraph dgraph;

    const char *filename;
    Arr(Cursor) cursors;
    int error_count;
} Sema;

Sema sema_init(Arr(Stmnt) ast, const char *filename, Arr(Cursor) cursors, int error_count);
Type *resolve_expr_type(Sema *sema, Expr *expr);
void sema_analyse(Sema *sema);
void sema_extern(Sema *sema, Stmnt *stmnt);
void sema_defer(Sema *sema, Stmnt *stmnt);
void sema_fn_decl(Sema *sema, Stmnt *stmnt);
void sema_block(Sema *sema, Arr(Stmnt) body);
void sema_directive(Sema *sema, Stmnt *stmnt);
void sema_expr(Sema *sema, Expr *expr);

// returns SkNone if not found
Stmnt ast_find_decl(Arr(Stmnt) ast, const char *key);

#endif // SEMA_H
