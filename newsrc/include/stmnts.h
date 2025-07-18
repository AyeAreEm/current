#ifndef STMNTS_H
#define STMNTS_H

#include <stddef.h>
#include "exprs.h"
#include "lexer.h"

typedef struct Stmnt Stmnt;

typedef enum StmntKind {
    SkNone,
    SkFnDecl,
    SkStructDecl,
    SkEnumDecl,
    SkVarDecl,
    SkVarReassign,
    SkReturn,
    SkContinue,
    SkBreak,
    SkFnCall,
    SkConstDecl,
    SkIf,
    SkFor,
    SkBlock,
    SkExtern,
    SkDirective,
} StmntKind;

typedef struct FnDecl {
    Expr name;
    Type type;
    Arr(Stmnt) args;
    Arr(Stmnt) body;
    bool has_body;
} FnDecl;

typedef struct StructDecl {
    Expr name;
    Arr(Stmnt) fields;
} StructDecl;

typedef StructDecl EnumDecl;

typedef struct VarDecl {
    Expr name;
    Type type;
    Expr value;
} VarDecl;

typedef VarDecl VarReassign;
typedef VarDecl ConstDecl;

typedef struct Return {
    Type type;
    Expr value;
} Return;

typedef enum CaptureKind {
    CkNone,
    CkIdent,
    CkConstDecl,
} CaptureKind;

typedef struct If {
    Expr condition;

    CaptureKind capturekind;
    union {
        Expr ident;
        Stmnt *constdecl;
    } capture;

    Arr(Stmnt) body;
    Arr(Stmnt) els;
} If;

typedef struct For {
    Stmnt *decl;
    Expr condition;
    Stmnt *reassign;
    Arr(Stmnt) body;
} For;

typedef enum DirectiveKind {
    DkNone,
    DkLink,
    DkSyslink,
    DkOutput,
    DkO0,
    DkO1,
    DkO2,
    DkO3,
    DkOdebug,
    DkOfast,
    DkOsmall,
} DirectiveKind;

typedef struct Directive {
    DirectiveKind kind;

    const char *str; // link, syslink, output
} Directive;

typedef struct Stmnt {
    StmntKind kind;
    size_t cursors_idx;

    union {
        FnDecl fndecl;
        FnCall fncall;
        StructDecl structdecl;
        EnumDecl enumdecl;
        VarDecl vardecl;
        VarReassign varreassign;
        ConstDecl constdecl;

        Return returnf;
        If iff;
        For forf;
        Stmnt *externf;

        Arr(Stmnt) block;
        Directive directive;
    };
} Stmnt;

Stmnt stmnt_none();
Stmnt stmnt_fndecl(FnDecl v, size_t index);
Stmnt stmnt_structdecl(StructDecl v, size_t index);
Stmnt stmnt_enumdecl(EnumDecl v, size_t index);
Stmnt stmnt_vardecl(VarDecl v, size_t index);
Stmnt stmnt_varreassign(VarReassign v, size_t index);
Stmnt stmnt_constdecl(ConstDecl v, size_t index);
Stmnt stmnt_return(Return v, size_t index);
Stmnt stmnt_continue(size_t index);
Stmnt stmnt_break(size_t index);
Stmnt stmnt_fncall(FnCall v, size_t index);
Stmnt stmnt_if(If v, size_t index);
Stmnt stmnt_for(For v, size_t index);
Stmnt stmnt_block(Arr(Stmnt) v, size_t index);
Stmnt stmnt_extern(Stmnt *v, size_t index);
Stmnt stmnt_directive(Directive v, size_t index);
void print_stmnt(Stmnt stmnt, Arr(Cursor) cursors, int indent);

#endif // STMNTS_H
