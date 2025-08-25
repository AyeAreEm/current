#include <stdint.h>
#include <stdio.h>
#include <assert.h>
#include "include/stmnts.h"
#include "include/exprs.h"
#include "include/lexer.h"
#include "include/stb_ds.h"
#include "include/strb.h"
#include "include/types.h"
#include "include/utils.h"

Stmnt stmnt_none(void) {
    return (Stmnt){
        .kind = SkNone,
    };
}

Stmnt stmnt_fndecl(FnDecl v, size_t index) {
    return (Stmnt){
        .kind = SkFnDecl,
        .cursors_idx = index,
        .fndecl = v,
    };
}

Stmnt stmnt_structdecl(StructDecl v, size_t index) {
    return (Stmnt){
        .kind = SkStructDecl,
        .cursors_idx = index,
        .structdecl = v,
    };
}

Stmnt stmnt_enumdecl(EnumDecl v, size_t index) {
    return (Stmnt){
        .kind = SkEnumDecl,
        .cursors_idx = index,
        .enumdecl = v,
    };
}

Stmnt stmnt_vardecl(VarDecl v, size_t index) {
    return (Stmnt){
        .kind = SkVarDecl,
        .cursors_idx = index,
        .vardecl = v,
    };
}

Stmnt stmnt_varreassign(VarReassign v, size_t index) {
    return (Stmnt){
        .kind = SkVarReassign,
        .cursors_idx = index,
        .varreassign = v,
    };
}

Stmnt stmnt_constdecl(ConstDecl v, size_t index) {
    return (Stmnt){
        .kind = SkConstDecl,
        .cursors_idx = index,
        .constdecl = v,
    };
}

Stmnt stmnt_return(Return v, size_t index) {
    return (Stmnt){
        .kind = SkReturn,
        .cursors_idx = index,
        .returnf = v,
    };
}

Stmnt stmnt_continue(size_t index) {
    return (Stmnt){
        .kind = SkContinue,
        .cursors_idx = index,
    };
}

Stmnt stmnt_break(size_t index) {
    return (Stmnt){
        .kind = SkBreak,
        .cursors_idx = index,
    };
}

Stmnt stmnt_fncall(FnCall v, size_t index) {
    return (Stmnt){
        .kind = SkFnCall,
        .cursors_idx = index,
        .fncall = v,
    };
}

Stmnt stmnt_if(If v, size_t index) {
    return (Stmnt){
        .kind = SkIf,
        .cursors_idx = index,
        .iff = v,
    };
}

Stmnt stmnt_for(For v, size_t index) {
    return (Stmnt){
        .kind = SkFor,
        .cursors_idx = index,
        .forf = v,
    };
}

Stmnt stmnt_block(Arr(Stmnt) v, size_t index) {
    return (Stmnt){
        .kind = SkBlock,
        .cursors_idx = index,
        .block = v,
    };
}

Stmnt stmnt_extern(Stmnt *v, size_t index) {
    return (Stmnt){
        .kind = SkExtern,
        .cursors_idx = index,
        .externf = v,
    };
}

Stmnt stmnt_directive(Directive v, size_t index) {
    return (Stmnt){
        .kind = SkDirective,
        .cursors_idx = index,
        .directive = v,
    };
}

void print_indent(int indent) {
    for (int i = 0; i < indent; i++) {
        printf("    ");
    }
}

void print_fndecl(Stmnt stmnt, Arr(Cursor) cursors, int indent) {
    assert(stmnt.kind == SkFnDecl);

    strb args = NULL;
    for (size_t i = 0; i < arrlenu(stmnt.fndecl.args); i++) {
        Stmnt arg = stmnt.fndecl.args[i];
        assert(arg.kind == SkConstDecl);

        strb type = string_from_type(arg.constdecl.type);
        if (i == 0) {
            strbprintf(&args, "%s %s", type, arg.constdecl.name.ident);
        } else {
            strbprintf(&args, ", %s %s", type, arg.constdecl.name.ident);
        }
        strbfree(type);
    }

    strb fndecltype = string_from_type(stmnt.fndecl.type);
    printfln(
        "Fn %s(%s) %s (%u:%u)",
        stmnt.fndecl.name.ident,
        args,
        fndecltype,
        cursors[stmnt.cursors_idx].row,
        cursors[stmnt.cursors_idx].col
    );
    strbfree(fndecltype);

    strbfree(args);

    if (stmnt.fndecl.has_body) {
        indent++;
        for (size_t i = 0; i < arrlenu(stmnt.fndecl.body); i++) {
            print_stmnt(stmnt.fndecl.body[i], cursors, indent);
        }
    }
}

void print_struct_decl(Stmnt stmnt, Arr(Cursor) cursors, int indent) {
    assert(stmnt.kind == SkStructDecl);
    printfln("Struct %s (%u:%u)", stmnt.structdecl.name.ident, cursors[stmnt.cursors_idx].row, cursors[stmnt.cursors_idx].col);

    indent++;
    for (size_t i = 0; i < arrlenu(stmnt.structdecl.fields); i++) {
        print_stmnt(stmnt.structdecl.fields[i], cursors, indent);
    }
}

void print_enum_decl(Stmnt stmnt, Arr(Cursor) cursors, int indent) {
    assert(stmnt.kind == SkEnumDecl);
    printfln("Enum %s (%u:%u)", stmnt.enumdecl.name.ident, cursors[stmnt.cursors_idx].row, cursors[stmnt.cursors_idx].col);
    
    indent++;
    for (size_t i = 0; i < arrlenu(stmnt.enumdecl.fields); i++) {
        print_stmnt(stmnt.enumdecl.fields[i], cursors, indent);
    }
}

void print_directive(Stmnt stmnt, Arr(Cursor) cursors, int indent) {
    assert(stmnt.kind == SkDirective);
    print_indent(indent);

    uint32_t c1 = cursors[stmnt.cursors_idx].row;
    uint32_t c2 = cursors[stmnt.cursors_idx].col;
    switch (stmnt.directive.kind) {
        case DkOutput:
            printfln("#output '%s' (%u:%u)", stmnt.directive.str, c1, c2);
            break;
        case DkLink:
            printfln("#link '%s' (%u:%u)", stmnt.directive.str, c1, c2);
            break;
        case DkSyslink:
            printfln("#syslink '%s' (%u:%u)", stmnt.directive.str, c1, c2);
            break;
        case DkOdebug:
            printfln("#Odebug (%u:%u)", c1, c2);
            break;
        case DkO0:
            printfln("#O0 (%u:%u)", c1, c2);
            break;
        case DkO1:
            printfln("#O1 (%u:%u)", c1, c2);
            break;
        case DkO2:
            printfln("#O2 (%u:%u)", c1, c2);
            break;
        case DkO3:
            printfln("#O3 (%u:%u)", c1, c2);
            break;
        case DkOfast:
            printfln("#Ofast (%u:%u)", c1, c2);
            break;
        case DkOsmall:
            printfln("#Osmall (%u:%u)", c1, c2);
            break;
        default: break;
    }
}

void print_varreassign(Stmnt stmnt, Arr(Cursor) cursors, int indent) {
    assert(stmnt.kind = SkVarReassign);

    strb name = expr_stringify(stmnt.varreassign.name, cursors);
    strb value = expr_stringify(stmnt.varreassign.value, cursors);

    print_indent(indent);
    printfln("%s = %s; (%u:%u)", name, value, cursors[stmnt.cursors_idx].row, cursors[stmnt.cursors_idx].col);

    strbfree(name);
    strbfree(value);
}

void print_constdecl(Stmnt stmnt, Arr(Cursor) cursors, int indent) {
    assert(stmnt.kind = SkConstDecl);

    strb type = string_from_type(stmnt.constdecl.type);
    strb value = expr_stringify(stmnt.constdecl.value, cursors);

    print_indent(indent);
    printfln("Const %s %s = %s; (%u:%u)", type, stmnt.constdecl.name.ident, value, cursors[stmnt.cursors_idx].row, cursors[stmnt.cursors_idx].col);
    
    strbfree(value);
    strbfree(type);
}

void print_vardecl(Stmnt stmnt, Arr(Cursor) cursors, int indent) {
    assert(stmnt.kind = SkVarDecl);

    strb type = string_from_type(stmnt.vardecl.type);
    strb value = expr_stringify(stmnt.vardecl.value, cursors);

    print_indent(indent);
    printfln("Var %s %s = %s; (%u:%u)", type, stmnt.vardecl.name.ident, value, cursors[stmnt.cursors_idx].row, cursors[stmnt.cursors_idx].col);
    
    strbfree(value);
    strbfree(type);
}

void print_return(Stmnt stmnt, Arr(Cursor) cursors, int indent) {
    assert(stmnt.kind = SkReturn);

    strb type = string_from_type(stmnt.returnf.type);
    strb value = expr_stringify(stmnt.returnf.value, cursors);

    print_indent(indent);
    printfln("Return %s %s; (%u:%u)", type, value, cursors[stmnt.cursors_idx].row, cursors[stmnt.cursors_idx].col);

    strbfree(value);
    strbfree(type);
}

void print_continue(Stmnt stmnt, Arr(Cursor) cursors, int indent) {
    assert(stmnt.kind = SkContinue);

    print_indent(indent);
    printfln("Continue; (%u:%u)", cursors[stmnt.cursors_idx].row, cursors[stmnt.cursors_idx].col);
}

void print_break(Stmnt stmnt, Arr(Cursor) cursors, int indent) {
    assert(stmnt.kind = SkBreak);

    print_indent(indent);
    printfln("Break; (%u:%u)", cursors[stmnt.cursors_idx].row, cursors[stmnt.cursors_idx].col);
}

void print_fncall(Stmnt stmnt, Arr(Cursor) cursors, int indent) {
    assert(stmnt.kind = SkFnCall);

    Expr expr = (Expr){
        .kind = EkFnCall,
        .cursors_idx = stmnt.cursors_idx,
        .type = type_none(),
        .fncall = stmnt.fncall
    };
    strb fncall = expr_stringify(expr, cursors);

    print_indent(indent);
    printfln("%s; (%u:%u)", fncall, cursors[stmnt.cursors_idx].row, cursors[stmnt.cursors_idx].col);
    strbfree(fncall);
}

void print_if(Stmnt stmnt, Arr(Cursor) cursors, int indent) {
    assert(stmnt.kind = SkIf);

    strb cond = expr_stringify(stmnt.iff.condition, cursors);
    print_indent(indent);
    printfln("If (%s) [CAPTURE DEBUG NOT IMPL]; (%u:%u)", cond, cursors[stmnt.cursors_idx].row, cursors[stmnt.cursors_idx].col);

    strbfree(cond);
}

void print_for(Stmnt stmnt, Arr(Cursor) cursors, int indent) {
    assert(stmnt.kind = SkFor);

    strb cond = expr_stringify(stmnt.forf.condition, cursors);
    print_indent(indent);
    printfln("For (no; %s; no); (%u:%u)", cond, cursors[stmnt.cursors_idx].row, cursors[stmnt.cursors_idx].col);
    strbfree(cond);
}

void print_block(Stmnt stmnt, Arr(Cursor) cursors, int indent) {
    assert(stmnt.kind = SkBlock);

    printfln("{");
    indent++;
    for (size_t i = 0; i < arrlenu(stmnt.block); i++) {
        print_stmnt(stmnt.block[i], cursors, indent);
    }
    printfln("}");
}

void print_extern(Stmnt stmnt, Arr(Cursor) cursors, int indent) {
    assert(stmnt.kind = SkExtern);

    printf("Extern ");
    print_stmnt(*stmnt.externf, cursors, indent);
}

void print_stmnt(Stmnt stmnt, Arr(Cursor) cursors, int indent) {
    switch (stmnt.kind) {
        case SkFnDecl:
            print_fndecl(stmnt, cursors, indent);
            break;
        case SkStructDecl:
            print_struct_decl(stmnt, cursors, indent);
            break;
        case SkEnumDecl:
            print_enum_decl(stmnt, cursors, indent);
            break;
        case SkDirective:
            print_directive(stmnt, cursors, indent);
            break;
        case SkVarReassign:
            print_varreassign(stmnt, cursors, indent);
            break;
        case SkConstDecl:
            print_constdecl(stmnt, cursors, indent);
            break;
        case SkVarDecl:
            print_vardecl(stmnt, cursors, indent);
            break;
        case SkReturn:
            print_return(stmnt, cursors, indent);
            break;
        case SkContinue:
            print_continue(stmnt, cursors, indent);
            break;
        case SkBreak:
            print_break(stmnt, cursors, indent);
            break;
        case SkFnCall:
            print_fncall(stmnt, cursors, indent);
            break;
        case SkIf:
            print_if(stmnt, cursors, indent);
            break;
        case SkFor:
            print_for(stmnt, cursors, indent);
            break;
        case SkBlock:
            print_block(stmnt, cursors, indent);
            break;
        case SkExtern:
            print_extern(stmnt, cursors, indent);
            break;
        default: break;
    }
}
