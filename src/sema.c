#include <stddef.h>
#include <assert.h>
#include <stdint.h>
#include <string.h>
#include "include/eval.h"
#include "include/exprs.h"
#include "include/stb_ds.h"
#include "include/sema.h"
#include "include/stmnts.h"
#include "include/strb.h"
#include "include/types.h"
#include "include/utils.h"
#include "include/typecheck.h"

_Noreturn static void elog(Sema *sema, size_t i, const char *msg, ...) {
    eprintf("%s:%lu:%lu " TERM_RED "error" TERM_END ": ", sema->filename, sema->cursors[i].row, sema->cursors[i].col);

    va_list args;
    va_start(args, msg);

    veprintfln(msg, args);

    va_end(args);
    exit(1);
}

static bool decl_has_name(Stmnt stmnt, const char *key) {
    switch (stmnt.kind) {
        case SkFnDecl:
            return streq(key, stmnt.fndecl.name.ident);
        case SkVarDecl:
            return streq(key, stmnt.vardecl.name.ident);
        case SkConstDecl:
            return streq(key, stmnt.constdecl.name.ident);
        case SkStructDecl:
            return streq(key, stmnt.structdecl.name.ident);
        case SkEnumDecl:
            return streq(key, stmnt.enumdecl.name.ident);
        default:
            return false;
    }
}

// returns SkNone if not found
Stmnt ast_find_decl(Arr(Stmnt) ast, const char *key) {
    for (size_t i = 0; i < arrlenu(ast); i++) {
        switch (ast[i].kind) {
            case SkExtern: {
                if (decl_has_name(*ast[i].externf, key)) {
                    return *ast[i].externf;
                }
            } break;
            default: {
                if (decl_has_name(ast[i], key)) {
                    return ast[i];
                }
            } break;
        }
    }

    return stmnt_none();
}

SymTab symtab_init(void) {
    SymTab symtab = {
        .stmnts = NULL,
        .keys = NULL,
        .cur_scope = 0,
    };
    arrpush(symtab.keys, NULL);
    arrpush(symtab.stmnts, NULL);

    return symtab;
}

Stmnt symtab_find(Sema *sema, const char *key, size_t cursor_idx) {
    size_t index = 0;
    bool found = false;

    for (size_t i = 0; i < arrlenu(sema->symtab.keys[sema->symtab.cur_scope]); i++) {
        if (streq(key, sema->symtab.keys[sema->symtab.cur_scope][i])) {
            index = i;
            found = true;
            break;
        }
    }

    if (found) return sema->symtab.stmnts[sema->symtab.cur_scope][index];

    // if not in symtab, see if it's defined at least
    Stmnt stmnt = ast_find_decl(sema->ast, key);
    if (stmnt.kind != SkNone) return stmnt;

    elog(sema, cursor_idx, "use of undefined \"%s\"", key);
    return stmnt_none();
}

void symtab_push(Sema *sema, const char *key, Stmnt value) {
    for (size_t i = 0; i < arrlenu(sema->symtab.keys[sema->symtab.cur_scope]); i++) {
        if (streq(key, sema->symtab.keys[sema->symtab.cur_scope][i])) {
            size_t index = sema->symtab.stmnts[sema->symtab.cur_scope][i].cursors_idx;
            elog(sema, value.cursors_idx, "redeclaration of \"%s\" from %zu:%zu", key, sema->cursors[index].row, sema->cursors[index].col);
        }
    }

    arrpush(sema->symtab.keys[sema->symtab.cur_scope], key);
    arrpush(sema->symtab.stmnts[sema->symtab.cur_scope], value);
}

void symtab_new_scope(Sema *sema) {
    Arr(const char*) keys = NULL;
    Arr(Stmnt) stmnts = NULL;

    for (size_t i = 0; i < arrlenu(sema->symtab.keys[sema->symtab.cur_scope]); i++) {
        arrpush(keys, sema->symtab.keys[sema->symtab.cur_scope][i]);
        arrpush(stmnts, sema->symtab.stmnts[sema->symtab.cur_scope][i]);
    }

    arrpush(sema->symtab.keys, keys);
    arrpush(sema->symtab.stmnts, stmnts);
    sema->symtab.cur_scope++;
}

void symtab_pop_scope(Sema *sema) {
    // (void) to silence warnings
    (void)arrpop(sema->symtab.keys);
    (void)arrpop(sema->symtab.stmnts);
    sema->symtab.cur_scope--;
}

Dgraph dgraph_init(void) {
    return (Dgraph){
        .names = NULL,
        .children = NULL,
    };
}
void dgraph_push(Dgraph *graph, Dnode node) {
    bool found = false;
    for (size_t i = 0; i < arrlenu(graph->names); i++) {
        if (streq(graph->names[i], node.name)) {
            found = true;
            break;
        }
    }

    if (!found) {
        arrpush(graph->names, node.name);
        arrpush(graph->children, node);
    }
}

Sema sema_init(Arr(Stmnt) ast, const char *filename, Arr(Cursor) cursors) {
    return (Sema){
        .ast = ast,
        .symtab = symtab_init(),
        .envinfo = {
            .fn = stmnt_none(),
            .forl = false,
        },
        .compile_flags = {
            .output = false,
            .optimise = false,
        },
        .dgraph = dgraph_init(),

        .filename = filename,
        .cursors = cursors,
    };
}

static Type *deref_ptr(Type *type) {
    if (type->kind == TkPtr) {
        return type->ptr_to;
    }

    return type;
}

static Type type_of_stmnt(Sema *sema, Stmnt stmnt) {
    switch (stmnt.kind) {
        case SkFnDecl:
            return stmnt.fndecl.type;
        case SkFnCall:
            assert(stmnt.fncall.name->kind == EkIdent);
            Stmnt decl = symtab_find(sema, stmnt.fncall.name->ident, stmnt.cursors_idx);
            assert(decl.kind == SkFnDecl);
            return decl.fndecl.type;
        case SkVarDecl:
            return stmnt.vardecl.type;
        case SkVarReassign:
            return stmnt.varreassign.type;
        case SkConstDecl:
            return stmnt.constdecl.type;
        case SkReturn:
            return stmnt.returnf.type;
        case SkStructDecl:
            elog(sema, stmnt.cursors_idx, "unexpected struct declaration");
        case SkEnumDecl:
            elog(sema, stmnt.cursors_idx, "unexpected enum declaration");
        case SkContinue:
            elog(sema, stmnt.cursors_idx, "unexpected continue statement");
        case SkBreak:
            elog(sema, stmnt.cursors_idx, "unexpected break statement");
        case SkBlock:
            elog(sema, stmnt.cursors_idx, "unexpected scope block");
        case SkIf:
            elog(sema, stmnt.cursors_idx, "unexpected if statement");
        case SkFor:
            elog(sema, stmnt.cursors_idx, "unexpected for loop");
        case SkExtern:
            elog(sema, stmnt.cursors_idx, "unexpected extern statement");
        case SkDirective:
            elog(sema, stmnt.cursors_idx, "unexpected directive");
        default:
            break;
    }

    return type_none();
}

bool stmnt_is_constant(Stmnt stmnt) {
    if (stmnt.kind == SkVarDecl) {
        return false;
    } else if (stmnt.kind == SkConstDecl) {
        return true;
    } else {
        assert(false && "stmnt should be var or const, it wasn't");
    }
}

Type *resolve_expr_type(Sema *sema, Expr *expr) {
    assert(expr->kind != EkNone);

    switch (expr->kind) {
        case EkNull:
        case EkTrue:
        case EkFalse:
        case EkCstrLit:
        case EkStrLit:
        case EkCharLit:
        case EkUnop:
        case EkLiteral:
        case EkGrouping:
        case EkIntLit:
        case EkFloatLit:
        case EkArrayIndex:
        case EkBinop:
            return &expr->type;
        case EkFieldAccess:
            if (expr->fieldacc.deref) {
                return deref_ptr(&expr->type);
            }
            return &expr->type;
        case EkIdent:
            if (expr->type.kind != TkNone) {
                return &expr->type;
            }

            Stmnt decl = symtab_find(sema, expr->ident, expr->cursors_idx);
            if (decl.kind == SkVarDecl) {
                expr->type = decl.vardecl.type;
            } else if (decl.kind == SkConstDecl) {
                expr->type = decl.constdecl.type;
            } else {
                elog(sema, expr->cursors_idx, "expected ident to be a variable or constant");
            }
            return &expr->type;
        case EkFnCall:
            if (expr->type.kind != TkNone) {
                return &expr->type;
            }

            Stmnt call = symtab_find(sema, expr->fncall.name->ident, expr->cursors_idx);
            expr->type = call.fndecl.type;
            return &expr->type;
        case EkType:
            // TODO: supprt this, returing TypeId or something
            elog(sema, expr->cursors_idx, "type of type not implemented yet");
            return NULL;
        default:
            return NULL;
    }
}

void sema_directive(Sema *sema, Stmnt *stmnt) {
    assert(stmnt->kind == SkDirective);

    switch (stmnt->directive.kind) {
        case DkLink:
        case DkSyslink:
            return;
        case DkOutput:
            if (!sema->compile_flags.output) {
                sema->compile_flags.output = true;
            } else {
                elog(sema, stmnt->cursors_idx, "output already set, cannot have more than one output directive");
            }
            break;
        case DkO0:
        case DkO1:
        case DkO2:
        case DkO3:
        case DkOdebug:
        case DkOfast:
        case DkOsmall:
            if (!sema->compile_flags.optimise) {
                sema->compile_flags.optimise = true;
            } else {
                elog(sema, stmnt->cursors_idx, "optimisation already set, cannot have more than one optimisation directive");
            }
            break;
        default: break;
    }
}

static Expr get_field(Sema *sema, Type type, const char *fieldname, size_t cursor_idx) {
    switch (type.kind) {
        case TkPtr:
            return get_field(sema, *type.ptr_to, fieldname, cursor_idx);
        case TkString: {
            enum { StringFieldsLen = 2 };
            Expr StringFields[StringFieldsLen] = {
                expr_ident("len", type_integer(TkUsize, TYPECONST, cursor_idx), cursor_idx),
                expr_ident("ptr", type_cstring(TYPECONST, cursor_idx), cursor_idx),
            };

            for (size_t i = 0; i < StringFieldsLen; i++) {
                if (streq(fieldname, StringFields[i].ident)) {
                    return StringFields[i];
                }
            }
            elog(sema, cursor_idx, "string does not have field \"%s\"", fieldname);
        } break;
        case TkArray: {
            enum { ArrayFieldsLen = 2 };
            Expr ArrayFields[ArrayFieldsLen] = {
                expr_ident("len", type_integer(TkUsize, TYPECONST, cursor_idx), cursor_idx),
                expr_ident("ptr", type_cstring(TYPECONST, cursor_idx), cursor_idx),
            };

            for (size_t i = 0; i < ArrayFieldsLen; i++) {
                if (streq(fieldname, ArrayFields[i].ident)) {
                    return ArrayFields[i];
                }
            }
            elog(sema, cursor_idx, "string does not have field \"%s\"", fieldname);
        } break;
        case TkTypeDef: {
            Stmnt typedeff = symtab_find(sema, type.typedeff, cursor_idx);

            if (typedeff.kind == SkStructDecl) {
                for (size_t i = 0; i < arrlenu(typedeff.structdecl.fields); i++) {
                    Stmnt decl = typedeff.structdecl.fields[i];
                    assert(decl.kind == SkVarDecl);
                    if (decl_has_name(decl, fieldname)) {
                        return expr_ident(fieldname, decl.vardecl.type, cursor_idx);
                    }
                }
                strb t = string_from_type(type);
                elog(sema, cursor_idx, "%s does not have field \"%s\" ", t, fieldname);
                // TODO: later when providing more than one error message, uncomment the line below
                // strbfree(t);
            } else if (typedeff.kind == SkEnumDecl) {
                for (size_t i = 0; i < arrlenu(typedeff.enumdecl.fields); i++) {
                    Stmnt decl = typedeff.enumdecl.fields[i];
                    assert(decl.kind == SkConstDecl);
                    if (decl_has_name(decl, fieldname)) {
                        return expr_ident(fieldname, type, cursor_idx);
                    }
                }
                strb t = string_from_type(type);
                elog(sema, cursor_idx, "%s does not have field \"%s\" ", t, fieldname);
            } else {
                strb t = string_from_type(type);
                comp_elog("get_field unreachable type: %s", t);
                // TODO: later when providing more than one error message, uncomment the line below
                // strbfree(t);
            }
        } break;
        default:
            elog(sema, cursor_idx, "primitive type does not have field \"%s\"", fieldname);
            break;
    }

    return expr_none();
}

void sema_field_access(Sema *sema, Expr *expr) {
    assert(expr->kind == EkFieldAccess);

    sema_expr(sema, expr->fieldacc.accessing);
    Type *type = resolve_expr_type(sema, expr->fieldacc.accessing);
    if (!expr->fieldacc.deref) {
        assert(expr->fieldacc.field->kind == EkIdent);
        Expr field = get_field(sema, *type, expr->fieldacc.field->ident, expr->cursors_idx);
        *expr->fieldacc.field = field;
        expr->type = field.type;
        sema_expr(sema, expr->fieldacc.field);
        return;
    }

    // deref
    if (expr->fieldacc.accessing->type.kind == TkPtr) {
        expr->type = *deref_ptr(type);
    } else {
        strb t = string_from_type(expr->fieldacc.accessing->type);
        elog(sema, expr->cursors_idx, "cannot derefernce %s, not a pointer", t);
        // TODO: later when providing more than one error message, uncomment the line below
        // strbfree(t);
    }
}

void sema_array_index(Sema *sema, Expr *expr) {
    assert(expr->kind == EkArrayIndex);

    sema_expr(sema, expr->arrayidx.accessing);
    Type *arrtype = &expr->arrayidx.accessing->type;

    if (arrtype->kind == TkArray) {
        expr->type = *arrtype->array.of;
    } else {
        strb t = string_from_type(*arrtype);
        elog(sema, expr->cursors_idx, "cannot index into %s, not an array", t);
        // TODO: later when providing more than one error message, uncomment the line below
        // strbfree(t);
    }

    sema_expr(sema, expr->arrayidx.index);
}

void sema_array_literal(Sema *sema, Expr *expr) {
    assert(expr->kind == EkLiteral);

    if (expr->literal.kind == LitkVars) {
        elog(sema, expr->cursors_idx, "array literal cannot have named fields");
    }

    Type *type = &expr->type;
    assert(type->kind == TkArray);
    Array *array = &type->array;

    if (array->len->kind != EkNone) {
        uint64_t len = eval_expr(sema, array->len);
        if (arrlenu(expr->literal.exprs) != (size_t)len) {
            elog(sema, expr->cursors_idx, "array length %zu, literal length %zu", (size_t)len, arrlenu(expr->literal.exprs));
        }
    } else {
        *array->len = expr_intlit(
            (uint64_t)arrlenu(expr->literal.exprs),
            type_integer(TkUsize, TYPECONST, expr->cursors_idx),
            expr->cursors_idx
        );
    }

    for (size_t i = 0; i < arrlenu(expr->literal.exprs); i++) {
        Type *valtype = resolve_expr_type(sema, &expr->literal.exprs[i]);
        if (!tc_equals(sema, *array->of, valtype)) {
            strb t1 = string_from_type(*valtype);
            strb t2 = string_from_type(*array->of);
            elog(sema, expr->cursors_idx, "array element %zu type is %s, but expected %s", i + 1, t1, t2);
            // TODO: later when providing more than one error message, uncomment the line below
            // strbfree(t1); strbfree(t2);
        }

        tc_number_within_bounds(sema, *array->of, expr->literal.exprs[i]);
    }
}

void sema_typedef_literal(Sema *sema, Expr *expr) {
    assert(expr->kind == EkLiteral);
    Stmnt typedeff = symtab_find(sema, expr->type.typedeff, expr->cursors_idx);
    if (typedeff.kind != SkStructDecl) {
        return;
    }

    if (expr->literal.kind == LitkExprs) {
        if (arrlenu(expr->literal.exprs) != arrlenu(typedeff.structdecl.fields)) {
            elog(sema, expr->cursors_idx, "expected %zu elements, got %zu", arrlenu(typedeff.structdecl.fields), arrlenu(expr->literal.exprs));
        }

        for (size_t i = 0; i < arrlenu(expr->literal.exprs); i++) {
            Type *valtype = resolve_expr_type(sema, &expr->literal.exprs[i]);
            Type fieldtype = type_of_stmnt(sema, typedeff.structdecl.fields[i]);

            if (!tc_equals(sema, fieldtype, valtype)) {
                strb t1 = string_from_type(*valtype);
                strb t2 = string_from_type(fieldtype);
                elog(sema, expr->literal.exprs[i].cursors_idx, "field %zu type is %s, but expected %s", i + 1, t1, t2);
                // TODO: later when providing more than one error message, uncomment the line below
                // strbfree(t1); strbfree(t2);
            }
        }
    } else if (expr->literal.kind == LitkVars) {
        if (arrlenu(expr->literal.vars) != arrlenu(typedeff.structdecl.fields)) {
            elog(sema, expr->cursors_idx, "expected %zu elements, got %zu", arrlenu(typedeff.structdecl.fields), arrlenu(expr->literal.vars));
        }

        for (size_t i = 0; i < arrlenu(expr->literal.vars); i++) {
            Type *valtype = resolve_expr_type(sema, &expr->literal.vars[i].varreassign.value);
            Expr field = get_field(sema, expr->type, expr->literal.vars[i].varreassign.name.ident, expr->literal.vars[i].cursors_idx);

            if (valtype->kind == TkNone) {
                *valtype = field.type;
                sema_expr(sema, &expr->literal.vars[i].varreassign.value);
                continue;
            }

            if (!tc_equals(sema, field.type, valtype)) {
                strb t1 = string_from_type(*valtype);
                strb t2 = string_from_type(field.type);
                elog(sema, expr->literal.vars[i].cursors_idx, "field %s type is %s, but expected %s", field.ident, t1, t2);
                // TODO: later when providing more than one error message, uncomment the line below
                // strbfree(t1); strbfree(t2);
            }
        }
    }
}

void sema_literal(Sema *sema, Expr *expr) {
    assert(expr->kind == EkLiteral);

    if (expr->literal.kind == LitkExprs) {
        for (size_t i = 0; i < arrlenu(expr->literal.exprs); i++) {
            sema_expr(sema, &expr->literal.exprs[i]);
        }
    } else {
        for (size_t i = 0; i < arrlenu(expr->literal.vars); i++) {
            sema_expr(sema, &expr->literal.vars[i].varreassign.value);
        }
    }

    if (expr->type.kind == TkArray) {
        sema_array_literal(sema, expr);
    } else if (expr->type.kind == TkTypeDef) {
        sema_typedef_literal(sema, expr);
    }
}

void sema_fn_call(Sema *sema, Expr *expr) {
    assert(expr->kind == EkFnCall);

    Stmnt stmnt = symtab_find(sema, expr->fncall.name->ident, expr->cursors_idx);
    if (stmnt.kind != SkFnDecl) {
        elog(sema, expr->cursors_idx, "expected \"%s\" to be a function", expr->fncall.name->ident);
    }

    if (expr->type.kind == TkNone) {
        expr->type = stmnt.fndecl.type;
    }

    size_t decl_args_len = arrlenu(stmnt.fndecl.args);
    size_t fncall_args_len = arrlenu(expr->fncall.args);
    if (decl_args_len != fncall_args_len) {
        elog(sema, expr->cursors_idx, "expected %zu argument(s) in function call \"%s\", got %zu", decl_args_len, expr->fncall.name->ident, fncall_args_len);
    }

    for (size_t i = 0; i < arrlenu(stmnt.fndecl.args); i++) {
        Type darg_type = type_of_stmnt(sema, stmnt.fndecl.args[i]);

        sema_expr(sema, &expr->fncall.args[i]);
        Type *carg_type = resolve_expr_type(sema, &expr->fncall.args[i]);

        if (!tc_equals(sema, darg_type, carg_type)) {
            strb t1 = string_from_type(darg_type);
            strb t2 = string_from_type(*carg_type);
            elog(sema, expr->cursors_idx, "mismatch types, argument %zu is expected to be of type %s, got %s", i + 1, t1, t2);
            // TODO: later when providing more than one error message, uncomment the line below
            // strbfree(t1); strbfree(t2);
        }
    }
}

void sema_fn_call_stmnt(Sema *sema, Stmnt *stmnt) {
    assert(stmnt->kind == SkFnCall);
    Expr expr = expr_fncall(stmnt->fncall, type_none(), stmnt->cursors_idx);
    sema_fn_call(sema, &expr);
    stmnt->fncall = expr.fncall;
}

void sema_unop(Sema *sema, Expr *expr) {
    assert(expr->kind == EkUnop);

    sema_expr(sema, expr->unop.val);

    if (expr->unop.kind == UkAddress && expr->unop.val->kind == EkIdent) {
        Stmnt stmnt = symtab_find(sema, expr->unop.val->ident, expr->unop.val->cursors_idx);
        Type *type = ealloc(sizeof(Type)); *type = type_of_stmnt(sema, stmnt);
        expr->type = type_ptr(type, stmnt_is_constant(stmnt), stmnt.cursors_idx);
    } else if (expr->unop.kind == UkNegate) {

        if (tc_is_unsigned(sema, *expr->unop.val)) {
            elog(sema, expr->cursors_idx, "cannot negate unsigned integers");
        }

        Type *valtype = resolve_expr_type(sema, expr->unop.val);
        expr->type = *valtype;
    } else if (expr->unop.kind == UkNot) {
        Type *type = resolve_expr_type(sema, expr->unop.val);

        if (!tc_equals(sema, type_bool(TYPEVAR, 0), type)) {
            strb t = string_from_type(*type);
            elog(sema, expr->cursors_idx, "expected a boolean after '!' operator, got %s", t);
            // TODO: later when providing more than one error message, uncomment the line below
            // strbfree(t);
        }
        expr->type = *type;
    } else if (expr->unop.kind == UkBitNot) {
        Type *type = resolve_expr_type(sema, expr->unop.val);

        if (!tc_can_bitwise(*type, *type)) {
            strb t = string_from_type(*type);
            elog(sema, expr->cursors_idx, "cannot do bitwise not (~) on %s", t);
            // TODO: later when providing more than one error message, uncomment the line below
            // strbfree(t);
        }
        expr->type = *type;
    } else {
        strb exprstr = expr_stringify(*expr, sema->cursors);
        elog(sema, expr->cursors_idx, "can't take address of %s", exprstr);
        // TODO: later when providing more than one error message, uncomment the line below
        // strbfree(exprstr);
    }
}

void sema_binop(Sema *sema, Expr *expr) {
    assert(expr->kind == EkBinop);
    sema_expr(sema, expr->binop.left);
    sema_expr(sema, expr->binop.right);

    Type *lt = resolve_expr_type(sema, expr->binop.left);
    Type *rt = resolve_expr_type(sema, expr->binop.right);

    const char *binopstr = "";
    switch (expr->binop.kind) {
        case BkPlus:
            binopstr = "+";
            break;
        case BkMinus:
            binopstr = "-";
            break;
        case BkMultiply:
            binopstr = "*";
            break;
        case BkDivide:
            binopstr = "/";
            break;
        case BkMod:
            binopstr = "%";
            break;
        case BkLess:
            binopstr = "<";
            break;
        case BkLessEqual:
            binopstr = "<=";
            break;
        case BkGreater:
            binopstr = ">";
            break;
        case BkGreaterEqual:
            binopstr = ">=";
            break;
        case BkEquals:
            binopstr = "==";
            break;
        case BkInequals:
            binopstr = "!=";
            break;
        case BkLeftShift:
            binopstr = "<<";
            break;
        case BkRightShift:
            binopstr = ">>";
            break;
        case BkBitAnd:
            binopstr = "&";
            break;
        case BkBitOr:
            binopstr = "|";
            break;
        case BkBitXor:
            binopstr = "^";
            break;
        case BkAnd:
            binopstr = "and";
            break;
        case BkOr:
            binopstr = "or";
            break;
    }

    if (!tc_equals(sema, *lt, rt)) {
        strb t1 = string_from_type(*lt);
        strb t2 = string_from_type(*rt);
        elog(sema, expr->cursors_idx, "mismatch types, %s %s %s", t1, binopstr, t2);
        // TODO: later when providing more than one error message, uncomment the line below
        // strbfree(t1); strbfree(t2);
    }

    if (expr->binop.kind == BkEquals || expr->binop.kind == BkInequals) {
        if (!tc_can_compare_equality(*lt, *rt)) {
            strb t1 = string_from_type(*lt);
            strb t2 = string_from_type(*rt);
            elog(sema, expr->cursors_idx, "cannot compare equality of %s and %s", t1, t2);
            // TODO: later when providing more than one error message, uncomment the line below
            // strbfree(t1); strbfree(t2);
        }
    } else if (expr->binop.kind == BkLess || expr->binop.kind == BkLessEqual || expr->binop.kind == BkGreater || expr->binop.kind == BkGreaterEqual) {
        if (!tc_can_compare_order(*lt, *rt)) {
            strb t1 = string_from_type(*lt);
            strb t2 = string_from_type(*rt);
            elog(sema, expr->cursors_idx, "cannot compare order of %s and %s", t1, t2);
            // TODO: later when providing more than one error message, uncomment the line below
            // strbfree(t1); strbfree(t2);
        }
    } else if (expr->binop.kind == BkPlus || expr->binop.kind == BkMinus || expr->binop.kind == BkMultiply || expr->binop.kind == BkDivide) {
        if (!tc_can_arithmetic(*lt, *rt, false)) {
            strb t1 = string_from_type(*lt);
            strb t2 = string_from_type(*rt);
            elog(sema, expr->cursors_idx, "cannot perform arithmetic operations on %s and %s", t1, t2);
        }

        if (lt->kind == TkUntypedInt && rt->kind == TkUntypedInt) {
            expr->type = *lt;
        } else if (rt->kind == TkUntypedInt) {
            expr->type = *lt;
        } else {
            expr->type = *rt;
        }
    }  else if (expr->binop.kind == BkMod) {
        if (!tc_can_arithmetic(*lt, *rt, true)) {
            strb t1 = string_from_type(*lt);
            strb t2 = string_from_type(*rt);
            elog(sema, expr->cursors_idx, "cannot perform modulo on %s and %s", t1, t2);
        }

        if (lt->kind == TkUntypedInt && rt->kind == TkUntypedInt) {
            expr->type = *lt;
        } else if (rt->kind == TkUntypedInt) {
            expr->type = *lt;
        } else {
            expr->type = *rt;
        }
    } else if (expr->binop.kind == BkAnd || expr->binop.kind == BkOr) {
        if (lt->kind != TkBool && rt->kind != TkBool) {
            strb t1 = string_from_type(*lt);
            strb t2 = string_from_type(*rt);
            elog(sema, expr->cursors_idx, "cannot use logical operations (and | or) on %s and %s", t1, t2);
            // TODO: later when providing more than one error message, uncomment the line below
            // strbfree(t1); strbfree(t2);
        }
    } else if (expr->binop.kind == BkBitAnd || expr->binop.kind == BkBitOr || expr->binop.kind == BkBitXor || expr->binop.kind == BkLeftShift || expr->binop.kind == BkRightShift) {
        if (!tc_can_bitwise(*lt, *rt)) {
            strb t1 = string_from_type(*lt);
            strb t2 = string_from_type(*rt);
            elog(sema, expr->cursors_idx, "cannot use bitwise operations on %s and %s", t1, t2);
            // TODO: later when providing more than one error message, uncomment the line below
            // strbfree(t1); strbfree(t2);
        }
        expr->type = expr->binop.left->type;
    }
}

void sema_expr(Sema *sema, Expr *expr) {
    switch (expr->kind) {
        case EkNone:
            return;
        case EkFieldAccess:
            sema_field_access(sema, expr);
            return;
        case EkArrayIndex:
            sema_array_index(sema, expr);
            return;
        case EkType:
            return;
        case EkUnop:
            sema_unop(sema, expr);
            return;
        case EkBinop:
            sema_binop(sema, expr);
            return;
        case EkLiteral:
            sema_literal(sema, expr);
            return;
        case EkFnCall:
            sema_fn_call(sema, expr);
            return;
        case EkIdent:
            if (expr->type.kind != TkNone) {
                return;
            }

            Stmnt stmnt = symtab_find(sema, expr->ident, expr->cursors_idx);
            if (stmnt.kind == SkVarDecl) {
                expr->type = stmnt.vardecl.type;
                break;
            } else if (stmnt.kind == SkConstDecl) {
                expr->type = stmnt.constdecl.type;
                break;
            } else if (stmnt.kind == SkEnumDecl) {
                expr->type = type_typedef(stmnt.enumdecl.name.ident, TYPEVAR, stmnt.cursors_idx);
                break;
            } else {
                elog(sema, expr->cursors_idx, "expected \"%s\" to be a variable", expr->ident);
            }
        case EkGrouping:
            sema_expr(sema, expr->group);
            Type *valtype = resolve_expr_type(sema, expr->group);
            expr->type = *valtype;
            return;
        case EkIntLit:
        case EkFloatLit:
        case EkCharLit:
        case EkStrLit:
        case EkCstrLit:
        case EkTrue:
        case EkFalse:
        case EkNull:
            return;
    }
}

void sema_return(Sema *sema, Stmnt *stmnt) {
    assert(stmnt->kind == SkReturn);

    sema_expr(sema, &stmnt->returnf.value);
    tc_return(sema, stmnt);
}

void sema_var_decl(Sema *sema, Stmnt *stmnt) {
    assert(stmnt->kind == SkVarDecl);
    VarDecl *vardecl = &stmnt->vardecl;

    if (vardecl->value.kind == EkLiteral) {
        if (vardecl->value.type.kind == TkNone) {
            if (vardecl->type.kind == TkNone) {
                // <name> := {...}; can't do that
                elog(sema, stmnt->cursors_idx, "missing type for literal");
            } else {
                // <name>: <type> = {...};
                vardecl->value.type = vardecl->type;
            }
        } else if (vardecl->type.kind != TkNone) {
            // <name>: <type> = <type>{...};
            if (!tc_equals(sema, vardecl->type, &vardecl->value.type)) {
                strb t1 = string_from_type(vardecl->type);
                strb t2 = string_from_type(vardecl->value.type);
                elog(sema, stmnt->cursors_idx, "mismatch types, variable \"%s\" type %s, expression type %s", vardecl->name.ident, t1, t2);
                // TODO: later when providing more than one error message, uncomment the line below
                // strbfree(t1); strbfree(t2);
            }
        } else {
            // <name> := <type>{...};
            vardecl->type = vardecl->value.type;
        }
    }

    sema_expr(sema, &vardecl->value);
    tc_var_decl(sema, stmnt);
    symtab_push(sema, vardecl->name.ident, *stmnt);
}

void sema_var_reassign(Sema *sema, Stmnt *stmnt) {
    assert(stmnt->kind == SkVarReassign);

    sema_expr(sema, &stmnt->varreassign.name);
    sema_expr(sema, &stmnt->varreassign.value);
    if (stmnt->varreassign.name.type.constant) {
        elog(sema, stmnt->cursors_idx, "cannot mutate constant variable");
    }

    if (stmnt->varreassign.name.kind == EkFieldAccess || stmnt->varreassign.name.kind == EkArrayIndex) {
        stmnt->varreassign.type = stmnt->varreassign.name.type;
        if (!tc_equals(sema, stmnt->varreassign.type, &stmnt->varreassign.value.type)) {
            strb t1 = string_from_type(stmnt->varreassign.type);
            strb t2 = string_from_type(stmnt->varreassign.value.type);
            elog(sema, stmnt->cursors_idx, "mismatch types, variable type %s, expression type %s", t1, t2);
            // TODO: later when providing more than one error message, uncomment the line below
            // strbfree(t1); strbfree(t2);
        }
        return;
    }

    assert(stmnt->varreassign.name.kind == EkIdent);
    Stmnt decl = symtab_find(sema, stmnt->varreassign.name.ident, stmnt->cursors_idx);
    if (decl.kind == SkVarDecl) {
        stmnt->varreassign.type = decl.vardecl.type;
    } else if (decl.kind == SkConstDecl) {
        elog(sema, stmnt->cursors_idx, "cannot mutate constant variable \"%s\"", stmnt->varreassign.name.ident);
    } else {
        elog(sema, stmnt->cursors_idx, "expected \"%s\" to be a variable", stmnt->varreassign.name.ident);
    }

    if (!tc_equals(sema, stmnt->varreassign.type, &stmnt->varreassign.value.type)) {
        strb t1 = string_from_type(stmnt->varreassign.type);
        strb t2 = string_from_type(stmnt->varreassign.value.type);
        elog(sema, stmnt->cursors_idx, "mismatch types, variable \"%s\" type %s, expression type %s", stmnt->varreassign.name.ident, t1, t2);
        // TODO: later when providing more than one error message, uncomment the line below
        // strbfree(t1); strbfree(t2);
    }
}

void sema_const_decl(Sema *sema, Stmnt *stmnt) {
    assert(stmnt->kind == SkConstDecl);
    ConstDecl *constdecl = &stmnt->constdecl;

    if (constdecl->value.kind == EkLiteral) {
        if (constdecl->value.type.kind == TkNone) {
            if (constdecl->type.kind == TkNone) {
                // <name> := {...}; can't do that
                elog(sema, stmnt->cursors_idx, "missing type for literal");
            } else {
                // <name>: <type> = {...};
                constdecl->value.type = constdecl->type;
            }
        } else if (constdecl->type.kind != TkNone) {
            // <name>: <type> = <type>{...};
            if (!tc_equals(sema, constdecl->type, &constdecl->value.type)) {
                strb t1 = string_from_type(constdecl->type);
                strb t2 = string_from_type(constdecl->value.type);
                elog(sema, stmnt->cursors_idx, "mismatch types, variable \"%s\" type %s, expression type %s", constdecl->name.ident, t1, t2);
                // TODO: later when providing more than one error message, uncomment the line below
                // strbfree(t1); strbfree(t2);
            }
        } else {
            // <name> := <type>{...};
            constdecl->type = constdecl->value.type;
        }
    }

    sema_expr(sema, &constdecl->value);
    tc_const_decl(sema, stmnt);

    assert(constdecl->name.kind == EkIdent);
    symtab_push(sema, constdecl->name.ident, *stmnt);
}

void sema_if(Sema *sema, Stmnt *stmnt) {
    assert(stmnt->kind == SkIf);
    If *iff = &stmnt->iff;

    sema_expr(sema, &iff->condition);
    if (
        !tc_equals(sema, type_bool(TYPEVAR, 0), &iff->condition.type) &&
        iff->condition.type.kind != TkOption
    ) {
        strb t = string_from_type(iff->condition.type);
        elog(sema, stmnt->cursors_idx, "condition must be bool or option, got %s", t);
        // TODO: later when providing more than one error message, uncomment the line below
        // strbfree(t); 
    }

    Stmnt *captured = ealloc(sizeof(Stmnt)); *captured = stmnt_none();
    if (iff->capturekind != CkNone) {
        assert(iff->condition.type.kind == TkOption);
        Type subtype = *iff->condition.type.option.subtype;
        *captured = stmnt_constdecl((ConstDecl){
            .name = iff->capture.ident,
            .type = subtype,
            .value = expr_null(type_none(), iff->capture.ident.cursors_idx),
        }, iff->capture.ident.cursors_idx);
        iff->capture.constdecl = captured;
        iff->capturekind = CkConstDecl;
    }

    symtab_new_scope(sema);
    if (captured->kind != SkNone) {
        symtab_push(sema, captured->constdecl.name.ident, *captured);
    }

    sema_block(sema, iff->body);
    symtab_pop_scope(sema);

    symtab_new_scope(sema);
    sema_block(sema, iff->els);
    symtab_pop_scope(sema);
}

void sema_for(Sema *sema, Stmnt *stmnt) {
    assert(stmnt->kind == SkFor);
    For *forf = &stmnt->forf;

    symtab_new_scope(sema);
    sema_var_decl(sema, forf->decl);
    sema_expr(sema, &forf->condition);

    if (!tc_equals(sema, type_bool(TYPEVAR, 0), &forf->condition.type)) {
        strb t = string_from_type(forf->condition.type);
        elog(sema,forf->condition.cursors_idx, "condition must be bool, got %s", t);
        // TODO: later when providing more than one error message, uncomment the line below
        // strbfree(t); 
    }
    sema_var_reassign(sema, forf->reassign);

    symtab_new_scope(sema);

    sema->envinfo.forl = true;
    sema_block(sema, forf->body);
    sema->envinfo.forl = false;

    symtab_pop_scope(sema);

    symtab_pop_scope(sema);
}

void sema_block(Sema *sema, Arr(Stmnt) body) {
    for (size_t i = 0; i < arrlenu(body); i++) {
        Stmnt *stmnt = &body[i];
        switch (stmnt->kind) {
            case SkNone:
                break;
            case SkDirective:
                sema_directive(sema, stmnt);
                break;
            case SkExtern:
                sema_extern(sema, stmnt);
                break;
            case SkBlock:
                symtab_new_scope(sema);
                sema_block(sema, stmnt->block);
                symtab_pop_scope(sema);
                break;
            case SkDefer:
                sema_defer(sema, stmnt);
                break;
            case SkReturn:
                if (sema->envinfo.fn.kind != SkNone) {
                    sema_return(sema, stmnt);
                } else {
                    elog(sema, stmnt->cursors_idx, "illegal use of return, not inside a function");
                }
                break;
            case SkContinue:
                if (!sema->envinfo.forl) {
                    elog(sema, stmnt->cursors_idx, "illegal use of continue, not inside a loop");
                }
                break;
            case SkBreak:
                if (!sema->envinfo.forl) {
                    elog(sema, stmnt->cursors_idx, "illegal use of continue, not inside a loop");
                }
                break;
            case SkVarDecl:
                sema_var_decl(sema, stmnt);
                break;
            case SkVarReassign:
                sema_var_reassign(sema, stmnt);
                break;
            case SkConstDecl:
                sema_const_decl(sema, stmnt);
                break;
            case SkFnCall:
                sema_fn_call_stmnt(sema, stmnt);
                break;
            case SkIf:
                sema_if(sema, stmnt);
                break;
            case SkFor:
                sema_for(sema, stmnt);
                break;
            case SkFnDecl:
                elog(sema, stmnt->cursors_idx, "illegal function declaration inside another function");
                break;
            case SkStructDecl:
                elog(sema, stmnt->cursors_idx, "illegal struct declaration inside a function");
                break;
            case SkEnumDecl:
                elog(sema, stmnt->cursors_idx, "illegal enum declaration inside a function");
                break;
        }
    }
}

void sema_fn_decl(Sema *sema, Stmnt *stmnt) {
    assert(stmnt->kind == SkFnDecl);

    symtab_push(sema, stmnt->fndecl.name.ident, *stmnt);
    symtab_new_scope(sema);

    for (size_t i = 0; i < arrlenu(stmnt->fndecl.args); i++) {
        Stmnt *arg = &stmnt->fndecl.args[i];
        assert(arg->kind == SkConstDecl);

        if (arg->constdecl.type.kind == TkTypeDef) {
            symtab_find(sema, arg->constdecl.type.typedeff, arg->constdecl.type.cursors_idx);
        }
        symtab_push(sema, arg->constdecl.name.ident, *arg);
    }

    if (streq("main", stmnt->fndecl.name.ident) && stmnt->fndecl.type.kind != TkVoid) {
        strb t = string_from_type(stmnt->fndecl.type);
        elog(sema, stmnt->cursors_idx, "illegal main function, expected return type to be void, got %s", t);
        // TODO: later when providing more than one error message, uncomment the line below
        // strbfree(t); 
    }
    sema->envinfo.fn = *stmnt;
    sema_block(sema, stmnt->fndecl.body);

    symtab_pop_scope(sema);
}

void sema_defer(Sema *sema, Stmnt *stmnt) {
    assert(stmnt->kind == SkDefer);

    switch (stmnt->defer->kind) {
        case SkNone:
            break;
        case SkVarReassign:
            sema_var_reassign(sema, stmnt->defer);
            break;
        case SkFnCall:
            sema_fn_call_stmnt(sema, stmnt->defer);
            break;
        case SkIf:
            sema_if(sema, stmnt->defer);
            break;
        case SkFor:
            sema_for(sema, stmnt->defer);
            break;
        case SkBlock:
            sema_block(sema, stmnt->defer->block);
            break;
        case SkReturn:
            elog(sema, stmnt->externf->cursors_idx, "cannot defer a return statement");
            break;
        case SkContinue:
            elog(sema, stmnt->externf->cursors_idx, "cannot defer a continue statement");
            break;
        case SkBreak:
            elog(sema, stmnt->externf->cursors_idx, "cannot defer a break statement");
            break;
        case SkVarDecl:
        case SkConstDecl:
        case SkEnumDecl:
        case SkStructDecl:
        case SkFnDecl:
        case SkExtern:
            elog(sema, stmnt->externf->cursors_idx, "cannot defer a declaration");
            break;
        case SkDirective:
            elog(sema, stmnt->externf->cursors_idx, "cannot defer a directive");
            break;
        case SkDefer:
            elog(sema, stmnt->externf->cursors_idx, "cannot defer a defer");
            break;
    }
}

void sema_extern(Sema *sema, Stmnt *stmnt) {
    assert(stmnt->kind == SkExtern);

    switch (stmnt->externf->kind) {
        case SkNone:
            break;
        case SkFnDecl:
            sema_fn_decl(sema, stmnt->externf);
            break;
        case SkVarDecl:
            sema_var_decl(sema, stmnt->externf);
            break;
        case SkVarReassign:
            sema_var_reassign(sema, stmnt->externf);
            break;
        case SkConstDecl:
            sema_const_decl(sema, stmnt->externf);
            break;
        case SkStructDecl:
            elog(sema, stmnt->externf->cursors_idx, "illegal struct declaration, cannot be external");
            break;
        case SkEnumDecl:
            elog(sema, stmnt->externf->cursors_idx, "illegal enum declaration, cannot be external");
            break;
        case SkBlock:
            elog(sema, stmnt->externf->cursors_idx, "illegal use of scope block, not inside a function");
            break;
        case SkReturn:
            elog(sema, stmnt->externf->cursors_idx, "illegal use of return, not inside a function");
            break;
        case SkDefer:
            elog(sema, stmnt->externf->cursors_idx, "illegal use of defer, not inside a function");
            break;
        case SkContinue:
            elog(sema, stmnt->externf->cursors_idx, "illegal use of continue, not inside a loop");
            break;
        case SkBreak:
            elog(sema, stmnt->externf->cursors_idx, "illegal use of break, not inside a loop");
            break;
        case SkFnCall:
            elog(sema, stmnt->externf->cursors_idx, "illegal use of function call, not inside a function");
            break;
        case SkIf:
            elog(sema, stmnt->externf->cursors_idx, "illegal use of if statement, not inside a function");
            break;
        case SkFor:
            elog(sema, stmnt->externf->cursors_idx, "illegal use of for loop, not inside a function");
            break;
        case SkExtern:
            elog(sema, stmnt->externf->cursors_idx, "illegal use of extern, already inside extern");
        case SkDirective:
            elog(sema, stmnt->externf->cursors_idx, "illegal use of directive, can't be inside extern");
            break;
    }
}

// catching cyclic dependencies and finding all children
// remember to free visited
void sema_struct_decl_deps(Sema *sema, Stmnt *stmnt, Arr(const char*) visited) {
    assert(stmnt->kind == SkStructDecl);

    arrpush(visited, stmnt->structdecl.name.ident);
    Arr(const char *) children = NULL;

    for (size_t i = 0; i < arrlenu(stmnt->structdecl.fields); i++) {
        Stmnt *f = &stmnt->structdecl.fields[i];

        if (f->vardecl.type.kind == TkTypeDef) {
            Stmnt decl = ast_find_decl(sema->ast, f->vardecl.type.typedeff);
            if (decl.kind == SkNone) continue;

            Arr(const char*) new_visited = NULL;

            for (size_t j = 0; j < arrlenu(visited); j++) {
                arrpush(new_visited, visited[j]);
            }

            Expr name = expr_none();
            if (decl.kind == SkStructDecl) {
                name = decl.structdecl.name;

                for (size_t j = 0; j < arrlenu(visited); j++) {
                    if (streq(visited[j], name.ident)) {
                        elog(sema, stmnt->cursors_idx, "cyclic dependency between struct \"%s\" and field \"%s\" of type \"%v\"", stmnt->structdecl.name.ident, f->vardecl.name.ident, name.ident);
                    }
                }
                sema_struct_decl_deps(sema, &decl, new_visited);
            } else if (decl.kind == SkEnumDecl) {
                name = decl.enumdecl.name;

                dgraph_push(&sema->dgraph, (Dnode){
                    .name = name.ident,
                    .us = decl,
                    .children = NULL,
                });
            }

            arrpush(children, name.ident);
            arrfree(new_visited);
        } else if (f->vardecl.type.kind == TkOption) {
            // we need to explicitly check if it's an option between we need to generate the underlying type
            if (f->vardecl.type.option.subtype->kind == TkTypeDef) {
                Stmnt decl = ast_find_decl(sema->ast, f->vardecl.type.option.subtype->typedeff);
                if (decl.kind != SkNone) {
                    sema_struct_decl_deps(sema, &decl, visited);
                    arrpush(children, decl.structdecl.name.ident);
                }
            }
        }
    }

    dgraph_push(&sema->dgraph, (Dnode){
        .name = stmnt->structdecl.name.ident,
        .us = *stmnt,
        .children = children,
    });
}

void sema_struct_decl(Sema *sema, Stmnt *stmnt) {
    assert(stmnt->kind == SkStructDecl);
    StructDecl *structd = &stmnt->structdecl;

    symtab_push(sema, structd->name.ident, *stmnt);
    symtab_new_scope(sema);

    for (size_t i = 0; i < arrlenu(structd->fields); i++) {
        switch (structd->fields[i].kind) {
            case SkVarDecl:
                if (structd->fields[i].vardecl.value.kind != EkNone) {
                    elog(sema, structd->fields[i].cursors_idx, "cannot have default values in structs, got one for field %s", structd->fields[i].vardecl.name.ident);
                }
                break;
            case SkConstDecl:
                elog(sema, structd->fields[i].cursors_idx, "cannot have constant fields, got constant field %s", structd->fields[i].constdecl.name.ident);
                break;
            default:
                break;
        }
    }
    sema_block(sema, structd->fields);
    Arr(const char*) visited = NULL;

    sema_struct_decl_deps(sema, stmnt, visited);

    arrfree(visited);
    symtab_pop_scope(sema);
}

void sema_enum_decl(Sema *sema, Stmnt *stmnt) {
    assert(stmnt->kind == SkEnumDecl);

    symtab_push(sema, stmnt->enumdecl.name.ident, *stmnt);
    symtab_new_scope(sema);

    size_t counter = 0;
    for (size_t i = 0; i < arrlenu(stmnt->enumdecl.fields); i++) {
        assert(stmnt->enumdecl.fields[i].kind == SkConstDecl);
        Stmnt *f = &stmnt->enumdecl.fields[i];

        if (f->constdecl.value.kind == EkNone) {
            f->constdecl.value = expr_intlit(counter, type_integer(TkUntypedInt, TYPECONST, f->cursors_idx), f->cursors_idx);
            counter++;
        } else {
            f->constdecl.type.kind = TkI32;
            counter = eval_expr(sema, &f->constdecl.value);
            counter++;
        }
    }

    dgraph_push(&sema->dgraph, (Dnode){
        .name = stmnt->enumdecl.name.ident,
        .us = *stmnt,
        .children = NULL,
    });

    symtab_pop_scope(sema);
}

void sema_analyse(Sema *sema) {
    for (size_t i = 0; i < arrlenu(sema->ast); i++) {
        Stmnt *stmnt = &sema->ast[i];
        switch (stmnt->kind) {
            case SkNone:
                break;
            case SkDirective:
                sema_directive(sema, stmnt);
                break;
            case SkExtern:
                sema_extern(sema, stmnt);
                break;
            case SkFnDecl:
                sema_fn_decl(sema, stmnt);
                break;
            case SkStructDecl:
                sema_struct_decl(sema, stmnt);
                break;
            case SkEnumDecl:
                sema_enum_decl(sema, stmnt);
                break;
            case SkVarDecl:
                sema_var_decl(sema, stmnt);
                break;
            case SkVarReassign:
                sema_var_reassign(sema, stmnt);
                break;
            case SkConstDecl:
                sema_const_decl(sema, stmnt);
                break;
            case SkBlock:
                elog(sema, stmnt->cursors_idx, "illegal use of scope block, not inside a function");
                break;
            case SkReturn:
                elog(sema, stmnt->cursors_idx, "illegal use of return, not inside a function");
                break;
            case SkDefer:
                elog(sema, stmnt->cursors_idx, "illegal use of defer, not inside a function");
                break;
            case SkContinue:
                elog(sema, stmnt->cursors_idx, "illegal use of continue, not inside a loop");
                break;
            case SkBreak:
                elog(sema, stmnt->cursors_idx, "illegal use of break, not inside a loop");
                break;
            case SkFnCall:
                elog(sema, stmnt->cursors_idx, "illegal use of function call, not inside a function");
                break;
            case SkIf:
                elog(sema, stmnt->cursors_idx, "illegal use of if statement, not inside a function");
                break;
            case SkFor:
                elog(sema, stmnt->cursors_idx, "illegal use of for loop, not inside a function");
                break;
        }
    }
}
