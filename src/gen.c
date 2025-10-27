#include <assert.h>
#include <ctype.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdbool.h>
#include <inttypes.h>
#include "include/gen.h"
#include "include/exprs.h"
#include "include/sema.h"
#include "include/stb_ds.h"
#include "include/stmnts.h"
#include "include/strb.h"
#include "include/types.h"
#include "include/eval.h"
#include "include/utils.h"

char *builtin_defs = 
    "#ifndef CURRENT_DEFS_H\n"
    "#define CURRENT_DEFS_H\n"
    "#include <stdint.h>\n"
    "#include <stddef.h>\n"
    "#include <string.h>\n"
    "#include <stdbool.h>\n"
    "#if defined(__linux__) || defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__) || defined(__sun) || defined(__CYGWIN__)\n"
    "#include <sys/types.h>\n"
    "#elif defined(_WIN32) || defined(__MINGW32__)\n"
    "#include <BaseTsd.h>\n"
    "typedef SSIZE_T ssize_t;\n"
    "#endif\n"
    "typedef int8_t i8;\n"
    "typedef int16_t i16;\n"
    "typedef int32_t i32;\n"
    "typedef int64_t i64;\n"
    "typedef ssize_t isize;\n"
    "typedef uint8_t u8;\n"
    "typedef uint16_t u16;\n"
    "typedef uint32_t u32;\n"
    "typedef uint64_t u64;\n"
    "typedef size_t usize;\n"
    "typedef float f32;\n"
    "typedef double f64;\n"
    "typedef struct CurString {\n"
    "    const char *ptr;\n"
    "    usize len;\n"
    "} CurString;\n"
    "#define curstr(s) ((CurString){.ptr = s, strlen(s)})\n"
    "#define CurArray1dDef(T, Tname, A)\\\n"
    "typedef struct CurArray1d_##Tname##A {\\\n"
    "    T *ptr;\\\n"
    "    const usize len;\\\n"
    "} CurArray1d_##Tname##A;\\\n"
    "CurArray1d_##Tname##A curarray1d_##Tname##A(T *ptr, usize len);\\\n\n"
    "#define CurArray1dImp(T, Tname, A)\\\n"
    "CurArray1d_##Tname##A curarray1d_##Tname##A(T *ptr, usize len) {\\\n"
    "    CurArray1d_##Tname##A ret = (CurArray1d_##Tname##A){.len = len};\\\n"
    "    ret.ptr = ptr;\\\n"
    "    return ret;\\\n"
    "}\n"
    "#define CurArray2dDef(T, Tname, A, B)\\\n"
    "typedef struct CurArray2d_##Tname##B##A {\\\n"
    "    CurArray1d_##Tname##A* ptr;\\\n"
    "    const usize len;\\\n"
    "} CurArray2d_##Tname##B##A;\\\n"
    "CurArray2d_##Tname##B##A curarray2d_##Tname##B##A(CurArray1d_##Tname##A *ptr, usize len);\\\n\n"
    "#define CurArray2dImp(T, Tname, A, B)\\\n"
    "CurArray2d_##Tname##B##A curarray2d_##Tname##B##A(CurArray1d_##Tname##A *ptr, usize len) {\\\n"
    "    CurArray2d_##Tname##B##A ret = (CurArray2d_##Tname##B##A){.len = len};\\\n"
    "    ret.ptr = ptr;\\\n"
    "    return ret;\\\n"
    "}\n"
    "#define CurSliceDef(T, Tname)\\\n"
    "typedef struct CurSlice_##Tname {\\\n"
    "    T *ptr;\\\n"
    "    usize len;\\\n"
    "} CurSlice_##Tname;\\\n"
    "CurSlice_##Tname curslice_##Tname(T *ptr, usize len);\n"
    "#define CurSliceImp(T, Tname)\\\n"
    "CurSlice_##Tname curslice_##Tname(T *ptr, usize len) {\\\n"
    "    CurSlice_##Tname ret = (CurSlice_##Tname){.len = len};\\\n"
    "    ret.ptr = ptr;\\\n"
    "    return ret;\\\n"
    "}\n"
    "#define CurOptionDef(T, Tname)\\\n"
    "typedef struct CurOption_##Tname {\\\n"
    "    T some;\\\n"
    "    bool ok;\\\n"
    "} CurOption_##Tname;\\\n"
    "CurOption_##Tname curoption_##Tname(T some);\\\n"
    "CurOption_##Tname curoptionnull_##Tname();\\\n\n"
    "#define CurOptionImp(T, Tname)\\\n"
    "CurOption_##Tname curoption_##Tname(T some) {\\\n"
    "    CurOption_##Tname ret;\\\n"
    "    ret.some = some;\\\n"
    "    ret.ok = true;\\\n"
    "    return ret;\\\n"
    "}\\\n"
    "CurOption_##Tname curoptionnull_##Tname() {\\\n"
    "    CurOption_##Tname ret;\\\n"
    "    ret.ok = false;\\\n"
    "    return ret;\\\n"
    "}\n"
;

char *builtin_args =
    "    CurString _CUR_ARGS_[argc];\n"
    "    for (int i = 0; i < argc; i++) {\n"
    "        _CUR_ARGS_[i] = curstr(argv[i]);\n"
    "    }\n"
    "    CurSlice_CurString args = curslice_CurString(_CUR_ARGS_, argc);\n"
;

Gen gen_init(Arr(Stmnt) ast, Dgraph dgraph) {
    return (Gen){
        .ast = ast,
        .code = NULL,
        .defs = NULL,

        .indent = 0,
        .defers = NULL,
        
        .in_defs = false,
        .dgraph = dgraph,
        .def_loc = 0,

        .code_loc = 0,
        .generated_typedefs = NULL,

        .compile_flags = {
            .links = NULL,
            .optimisation = OlDebug,
            .output = "",
        },
    };
}

void gen_push_defer(Gen *gen, Stmnt *stmnt) {
    Defer defer = {
        .stmnt = stmnt,
        .indent = gen->indent,
    };
    arrpush(gen->defers, defer);
}

void gen_pop_defers(Gen *gen) {
    for (ptrdiff_t i = arrlen(gen->defers) - 1; i >= 0; i--) {
        if (gen->defers[i].indent == gen->indent) {
            arrdel(gen->defers, i);
        }
    }
}

void gen_directive(Gen *gen, Stmnt stmnt) {
    assert(stmnt.kind == SkDirective);
    switch (stmnt.directive.kind) {
        case DkLink:
            arrpush(gen->compile_flags.links, stmnt.directive.str);
            break;
        case DkSyslink: {
            strb l = NULL;
            strbprintf(&l, "-l%s", stmnt.directive.str);
            arrpush(gen->compile_flags.links, l);
        } break;
        case DkOutput:
            gen->compile_flags.output = stmnt.directive.str;
            break;
        case DkO0:
            gen->compile_flags.optimisation = OlZero;
            break;
        case DkO1:
            gen->compile_flags.optimisation = OlOne;
            break;
        case DkO2:
            gen->compile_flags.optimisation = OlTwo;
            break;
        case DkO3:
            gen->compile_flags.optimisation = OlThree;
            break;
        case DkOdebug:
            gen->compile_flags.optimisation = OlDebug;
            break;
        case DkOfast:
            gen->compile_flags.optimisation = OlFast;
            break;
        case DkOsmall:
            gen->compile_flags.optimisation = OlSmall;
            break;
        default: break;
    }
}

void gen_write(Gen *gen, const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);

    if (gen->in_defs) {
        vstrbprintf(&gen->defs, fmt, args);
    } else {
        vstrbprintf(&gen->code, fmt, args);
    }
    
    va_end(args);
}

void gen_writeln(Gen *gen, const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);

    if (gen->in_defs) {
        vstrbprintf(&gen->defs, fmt, args);
        strbpush(&gen->defs, '\n');
    } else {
        vstrbprintf(&gen->code, fmt, args);
        strbpush(&gen->code, '\n');
    }

    va_end(args);
}

void gen_indent(Gen *gen) {
    for (uint8_t i = 0; i < gen->indent; i++) {
        gen_write(gen, "    ");
    }
}

void gen_slice_type(Gen *gen, Type type, strb *str) {
    if (type.kind == TkSlice) {
        gen_slice_type(gen, *type.slice.of, str);
        strbprintf(str, "[]"); 
    } else {
        MaybeAllocStr t = gen_type(gen, type);
        strbprintf(str, "%s", t.str);

        if (t.alloced) strbfree(t.str);
    }
}

void gen_array_type(Gen *gen, Type type, strb *str) {
    if (type.kind == TkArray) {
        MaybeAllocStr length = gen_expr(gen, *type.array.len);
        gen_array_type(gen, *type.array.of, str);
        strbprintf(str, "[%s]", length.str); 

        if (length.alloced) strbfree(length.str);
    } else {
        MaybeAllocStr t = gen_type(gen, type);
        strbprintf(str, "%s", t.str);

        if (t.alloced) strbfree(t.str);
    }
}

strb gen_ptr_type(Gen *gen, Type type) {
    if (type.kind == TkPtr) {
        strb rest = gen_ptr_type(gen, *type.ptr_to);

        strb ret = NULL;
        strbprintf(&ret, "%s*", rest);

        strbfree(rest);
        return ret;
    } else {
        MaybeAllocStr t = gen_type(gen, type);
        return t.str;
    }
}

MaybeAllocStr gen_type(Gen *gen, Type type) {
    assert(type.kind != TkUntypedInt && type.kind != TkUntypedFloat && "should not be codegening untyped types");
    gen_decl_generic(gen, type);

    switch (type.kind) {
        case TkSlice: {
            strb ret = NULL;
            gen_slice_type(gen, type, &ret);

            return (MaybeAllocStr){
                .str = ret,
                .alloced = true,
            };
        }
        case TkArray: {
            strb ret = NULL;
            gen_array_type(gen, type, &ret);

            return (MaybeAllocStr){
                .str = ret,
                .alloced = true,
            };
        }
        case TkOption: {
            strb ret = NULL;
            MaybeAllocStr option = gen_type(gen, *type.option.subtype);
            strbprintf(&ret, "CurOption_%s", option.str);
            if (option.alloced) strbfree(option.str);

            return (MaybeAllocStr){
                .str = ret,
                .alloced = true,
            };
        }
        case TkPtr:
            return (MaybeAllocStr){
                .str = gen_ptr_type(gen, type),
                .alloced = true,
            };
        case TkCstring:
            return (MaybeAllocStr){
                .str = "const char*",
                .alloced = false,
            };
        case TkString:
            return (MaybeAllocStr){
                .str = "CurString",
                .alloced = false,
            };
        case TkChar:
            // TODO: make this be a type that supports utf8
            return (MaybeAllocStr){
                .str = "u8",
                .alloced = false,
            };
        default:
            return (MaybeAllocStr){
                .str = string_from_type(type),
                .alloced = true,
            };
    }
}

strb gen_typename_slice(Gen *gen, Type type) {
    strb typename = NULL;
    gen_typename(gen, type.slice.of, 1, &typename);

    strb slice = NULL;
    strbprintf(&slice, "CurSlice_%s", typename);

    strbfree(typename);
    return slice;
}

strb gen_typename_array(Gen *gen, Type type, int dimension) {
    switch (type.kind) {
        case TkArray:
            if (type.array.of->kind == TkArray) {
                Type subtype = *type.array.of;

                strb array = gen_typename_array(gen, *subtype.array.of, dimension + 1);
                MaybeAllocStr length = gen_expr(gen, *subtype.array.len);
                strbprintf(&array, "%s", length.str); 

                if (dimension == 1) {
                    MaybeAllocStr parent_length = gen_expr(gen, *type.array.len);
                    strbprintf(&array, "%s", parent_length.str);

                    // this is why we need differs, or maybe i should just use gotos
                    if (parent_length.alloced) strbfree(parent_length.str);
                    if (length.alloced) strbfree(length.str);
                    return array;
                }
                if (length.alloced) strbfree(length.str);
                return array;
            } else {
                strb typename = NULL;
                gen_typename(gen, type.array.of, 1, &typename);

                MaybeAllocStr length = gen_expr(gen, *type.array.len);
                strb array = NULL;
                strbprintf(&array, "CurArray%dd_%s%s", dimension, typename, length.str);

                if (length.alloced) strbfree(length.str);
                strbfree(typename);
                return array;
            }
        default: {
            strb typename = NULL;
            gen_typename(gen, &type, 1, &typename);

            strb array = NULL;
            strbprintf(&array, "CurArray%dd_%s", dimension, typename);

            strbfree(typename);
            return array;
        } 
    }
}

// remember to free typename after
void gen_typename(Gen *gen, Type *types, size_t types_len, strb *typename) {
    for (size_t i = 0; i < types_len; i++) {
        Type type = types[i];

        switch (type.kind) {
            case TkUntypedInt:
            case TkUntypedFloat:
                assert(false && "unexpected untyped type in gen_typename");
                break;
            case TkCstring:
                strbprintf(typename, "constcharptr");
                break;
            case TkPtr:
                gen_typename(gen, type.ptr_to, 1, typename);
                strbprintf(typename, "ptr");
                break;
            case TkSlice: {
                strb slice = gen_typename_slice(gen, type);
                strbprintf(typename, "%s", slice);
                strbfree(slice);
            } break;
            case TkArray: {
                strb array = gen_typename_array(gen, type, 1);
                strbprintf(typename, "%s", array);
                strbfree(array);
            } break;
            case TkOption: {
                strb option = NULL;
                gen_typename(gen, type.option.subtype, 1, &option);
                strbprintf(typename, "CurOption_%s", option);
                strbfree(option);
            } break;
            default: {
                MaybeAllocStr ty = gen_type(gen, type);
                if (ty.alloced) {
                    char *tn = strtrim(ty.str);
                    strbprintf(typename, "%s", tn);
                } else {
                    strbprintf(typename, "%s", ty);
                }
            }
        }
    }
}

// .alloced will always be true if it generated, if it's false, it wasn't an option expr
MaybeAllocStr gen_option_expr(Gen *gen, Expr expr) {
    if (expr.type.kind == TkOption && expr.type.option.gen_option) {
        strb typename = NULL;
        gen_typename(gen, expr.type.option.subtype, 1, &typename);
        expr.type = *expr.type.option.subtype;
        MaybeAllocStr value = gen_expr(gen, expr);

        strb option = NULL;
        strbprintf(&option, "curoption_%s(%s)", typename, value.str);

        if (value.alloced) strbfree(value.str);
        strbfree(typename);

        return (MaybeAllocStr){
            .str = option,
            .alloced = true,
        };
    }

    return (MaybeAllocStr){
        .str = "",
        .alloced = false,
    };
}

strb gen_numlit_expr(Expr expr) {
    assert(expr.kind == EkIntLit);
    strb s = NULL;
    Number n = eval_int_cast(expr.type, expr.intlit);

    switch (n.kind) {
        case NkF32:
            strbprintf(&s, "%f", n.f32);
            break;
        case NkF64:
            strbprintf(&s, "%f", n.f64);
            break;

        case NkU8:
            strbprintf(&s, "%"PRIu8, n.u8);
            break;
        case NkU16:
            strbprintf(&s, "%"PRIu16, n.u16);
            break;
        case NkU32:
            strbprintf(&s, "%"PRIu32, n.u32);
            break;
        case NkU64:
            strbprintf(&s, "%u"PRIu64, n.u64);
            break;
        case NkUsize:
            strbprintf(&s, "%zu", n.u64);
            break;

        case NkI8:
            strbprintf(&s, "%"PRIi8, n.i8);
            break;
        case NkI16:
            strbprintf(&s, "%"PRIi16, n.i16);
            break;
        case NkI32:
            strbprintf(&s, "%"PRIi32, n.i32);
            break;
        case NkI64:
            strbprintf(&s, "%"PRIi64, n.i64);
            break;
        case NkIsize:
            strbprintf(&s, "%zd", n.i64);
            break;
    }

    return s;
}

MaybeAllocStr gen_unop_expr(Gen *gen, Expr expr) {
    assert(expr.kind == EkUnop);

    strb ret = NULL;
    MaybeAllocStr value = gen_expr(gen, *expr.unop.val);

    switch (expr.unop.kind) {
        case UkAddress:
            strbprintf(&ret, "&%s", value);
            break;
        case UkNegate:
            strbprintf(&ret, "-%s", value);
            break;
        case UkNot:
            strbprintf(&ret, "!%s", value);
            break;
        case UkBitNot:
            strbprintf(&ret, "~%s", value);
            break;
    }

    if (value.alloced) strbfree(value.str);
    return (MaybeAllocStr){
        .str = ret,
        .alloced = true,
    };
}

MaybeAllocStr gen_fn_call(Gen *gen, Expr expr) {
    assert(expr.kind == EkFnCall);

    strb call = NULL;
    strbprintf(&call, "%s(", expr.fncall.name->ident);

    for (size_t i = 0; i < arrlenu(expr.fncall.args); i++) {
        MaybeAllocStr arg = gen_expr(gen, expr.fncall.args[i]);

        if (i == 0) {
            strbprintf(&call, "%s", arg.str);
        } else {
            strbprintf(&call, ", %s", arg.str);
        }

        if (arg.alloced) strbfree(arg.str);
    }
    strbpush(&call, ')');

    return (MaybeAllocStr){
        .str = call,
        .alloced = true,
    };
}

MaybeAllocStr gen_slice_literal_expr(Gen *gen, Expr expr) {
    assert(expr.type.kind == TkSlice);
    strb lit = NULL;
    Type slice = expr.type;

    strb typename = NULL;
    gen_typename(gen, &slice, 1, &typename);

    char *type = strtok(typename, "_");
    for (size_t i = 0; i < strlen(type); i++) {
        type[i] = tolower(type[i]);
    }
    typename[strlen(type)] = '_';

    strbprintf(&lit, "%s(", typename);

    MaybeAllocStr exprtype = gen_type(gen, slice);
    strbprintf(&lit, "(%s){", exprtype.str);
    if (exprtype.alloced) strbfree(exprtype.str);

    for (size_t i = 0; i < arrlenu(expr.literal.exprs); i++) {
        MaybeAllocStr val = gen_expr(gen, expr.literal.exprs[i]);

        if (i == 0) {
            strbprintf(&lit, "%s", val.str);
        } else {
            strbprintf(&lit, ", %s", val.str);
        }

        if (val.alloced) strbfree(val.str);
    }
    strbprintf(&lit, "}, %d)", arrlenu(expr.literal.exprs));

    return (MaybeAllocStr){
        .str = lit,
        .alloced = true,
    };
}

MaybeAllocStr gen_array_literal_expr(Gen *gen, Expr expr) {
    assert(expr.type.kind == TkArray);
    strb lit = NULL;
    Type arr = expr.type;

    strb typename = NULL;
    gen_typename(gen, &arr, 1, &typename);

    char *type = strtok(typename, "_");
    for (size_t i = 0; i < strlen(type); i++) {
        type[i] = tolower(type[i]);
    }
    typename[strlen(type)] = '_';

    strbprintf(&lit, "%s(", typename);

    if (arr.array.of->kind == TkArray) {
        strclear(typename, 0);
        gen_typename(gen, arr.array.of, 1, &typename);

        MaybeAllocStr length = gen_expr(gen, *arr.array.len);
        strbprintf(&lit, "(%s[%s]){", typename, length.str);

        if (length.alloced) strbfree(length.str);
    } else {
        MaybeAllocStr exprtype = gen_type(gen, expr.type);
        strbprintf(&lit, "(%s){", exprtype.str);

        if (exprtype.alloced) strbfree(exprtype.str);
    }

    for (size_t i = 0; i < arrlenu(expr.literal.exprs); i++) {
        MaybeAllocStr val = gen_expr(gen, expr.literal.exprs[i]);

        if (i == 0) {
            strbprintf(&lit, "%s", val.str);
        } else {
            strbprintf(&lit, ", %s", val.str);
        }

        if (val.alloced) strbfree(val.str);
    }
    strbpush(&lit, '}');

    MaybeAllocStr len = gen_expr(gen, *arr.array.len);
    strbprintf(&lit, ", %s)", len.str);

    if (len.alloced) strbfree(len.str);
    strbfree(typename);
    return (MaybeAllocStr){
        .str = lit,
        .alloced = true,
    };
}

MaybeAllocStr gen_literal_expr(Gen *gen, Expr expr) {
    assert(expr.kind == EkLiteral);
    strb lit = NULL;

    if (expr.type.kind == TkArray) {
        return gen_array_literal_expr(gen, expr);
    } else if (expr.type.kind == TkSlice) {
        return gen_slice_literal_expr(gen, expr);
    }

    MaybeAllocStr exprtype = gen_type(gen, expr.type);
    strbprintf(&lit, "(%s){", exprtype.str);

    if (expr.literal.kind == LitkExprs) {
        for (size_t i = 0; i < arrlenu(expr.literal.exprs); i++) {
            MaybeAllocStr val = gen_expr(gen, expr.literal.exprs[i]);

            if (i == 0) {
                strbprintf(&lit, "%s", val.str);
            } else {
                strbprintf(&lit, ", %s", val.str);
            }

            if (val.alloced) strbfree(val.str);
        }
    } else {
        for (size_t i = 0; i < arrlenu(expr.literal.vars); i++) {
            MaybeAllocStr reassigned = gen_expr(gen, expr.literal.vars[i].varreassign.name);
            MaybeAllocStr value = gen_expr(gen, expr.literal.vars[i].varreassign.value);

            if (i == 0) {
                strbprintf(&lit, ".%s = %s", reassigned.str, value.str);
            } else {
                strbprintf(&lit, ", .%s = %s", reassigned.str, value.str);
            }

            if (reassigned.alloced) strbfree(reassigned.str);
            if (value.alloced) strbfree(value.str);
        }
    }
    strbpush(&lit, '}');

    if (exprtype.alloced) strbfree(exprtype.str);
    return (MaybeAllocStr){
        .str = lit,
        .alloced = true,
    };
}

MaybeAllocStr gen_binop_expr(Gen *gen, Expr expr) {
    assert(expr.kind == EkBinop);

    MaybeAllocStr lhs = gen_expr(gen, *expr.binop.left);
    MaybeAllocStr rhs = gen_expr(gen, *expr.binop.right);
    strb ret = NULL;

    switch (expr.binop.kind) {
        case BkPlus:
            strbprintf(&ret, "%s + %s", lhs.str, rhs.str);
            break;
        case BkMinus:
            strbprintf(&ret, "%s - %s", lhs.str, rhs.str);
            break;
        case BkMultiply:
            strbprintf(&ret, "%s * %s", lhs.str, rhs.str);
            break;
        case BkDivide:
            strbprintf(&ret, "%s / %s", lhs.str, rhs.str);
            break;
        case BkMod:
            strbprintf(&ret, "%s %% %s", lhs.str, rhs.str);
            break;
        case BkLess:
            strbprintf(&ret, "%s < %s", lhs.str, rhs.str);
            break;
        case BkLessEqual:
            strbprintf(&ret, "%s <= %s", lhs.str, rhs.str);
            break;
        case BkGreater:
            strbprintf(&ret, "%s > %s", lhs.str, rhs.str);
            break;
        case BkGreaterEqual:
            strbprintf(&ret, "%s >= %s", lhs.str, rhs.str);
            break;
        case BkEquals:
            strbprintf(&ret, "%s == %s", lhs.str, rhs.str);
            break;
        case BkInequals:
            strbprintf(&ret, "%s != %s", lhs.str, rhs.str);
            break;
        case BkLeftShift:
            strbprintf(&ret, "%s << %s", lhs.str, rhs.str);
            break;
        case BkRightShift:
            strbprintf(&ret, "%s >> %s", lhs.str, rhs.str);
            break;
        case BkBitAnd:
            strbprintf(&ret, "%s & %s", lhs.str, rhs.str);
            break;
        case BkBitOr:
            strbprintf(&ret, "%s | %s", lhs.str, rhs.str);
            break;
        case BkBitXor:
            strbprintf(&ret, "%s ^ %s", lhs.str, rhs.str);
            break;
        case BkAnd:
            strbprintf(&ret, "%s && %s", lhs.str, rhs.str);
            break;
        case BkOr:
            strbprintf(&ret, "%s || %s", lhs.str, rhs.str);
            break;
    }
    
    if (lhs.alloced) strbfree(lhs.str);
    if (rhs.alloced) strbfree(rhs.str);

    return (MaybeAllocStr){
        .str = ret,
        .alloced = true,
    };
}

MaybeAllocStr gen_expr(Gen *gen, Expr expr) {
    if (expr.kind == EkType) {
        return gen_type(gen, expr.type_expr);
    }

    if (expr.kind != EkNull) {
        MaybeAllocStr opt = gen_option_expr(gen, expr);
        if (opt.alloced) return opt;
    }

    switch (expr.kind) {
        case EkIdent:
            return (MaybeAllocStr){
                .str = expr.ident, // nothing much i can do to silence this warning, but rest assured .str is not edited anywhere
                .alloced = false,
            };
        case EkIntLit:
        case EkFloatLit: {
            return (MaybeAllocStr){
                .str = gen_numlit_expr(expr),
                .alloced = true,
            };
        }
        case EkCharLit: {
            strb lit = NULL;
            strbprintf(&lit, "%d", expr.charlit);
            return (MaybeAllocStr){
                .str = lit,
                .alloced = true,
            };
        }
        case EkStrLit: {
            strb lit = NULL;
            strbprintf(&lit, "curstr(\"%s\")", expr.strlit);
            return (MaybeAllocStr){
                .str = lit,
                .alloced = true,
            };
        }
        case EkCstrLit: {
            strb lit = NULL;
            strbprintf(&lit, "\"%s\"", expr.cstrlit);
            return (MaybeAllocStr){
                .str = lit,
                .alloced = true,
            };
        }
        case EkTrue:
            return (MaybeAllocStr){
                .str = "true",
                .alloced = false,
            };
        case EkFalse:
            return (MaybeAllocStr){
                .str = "false",
                .alloced = false,
            };
        case EkNull: {
            strb typename = NULL;
            gen_typename(gen, expr.type.option.subtype, 1, &typename);

            strb option = NULL;
            strbprintf(&option, "curoptionnull_%s()", typename);

            strbfree(typename);
            return (MaybeAllocStr){
                .str = option,
                .alloced = true,
            };
        } break;
        case EkFieldAccess: {
            MaybeAllocStr subexpr = gen_expr(gen, *expr.fieldacc.accessing);
            if (expr.fieldacc.deref) {
                strb ret = NULL; strbprintf(&ret, "*%s", subexpr.str);
                if (subexpr.alloced) strbfree(subexpr.str);
                return (MaybeAllocStr){
                    .str = ret,
                    .alloced = true,
                };
            }

            MaybeAllocStr field = gen_expr(gen, *expr.fieldacc.field);
            strb ret = NULL;

            if (expr.fieldacc.accessing->type.kind == TkPtr) {
                strbprintf(&ret, "%s->%s", subexpr.str, field.str);
            } else if (expr.fieldacc.accessing->type.kind == TkTypeDef) {
                Stmnt stmnt =ast_find_decl(gen->ast, expr.fieldacc.accessing->type.typedeff);

                if (stmnt.kind == SkStructDecl) {
                    strbprintf(&ret, "%s.%s", subexpr.str, field.str);
                } else if (stmnt.kind == SkEnumDecl) {
                    strbprintf(&ret, "%s_%s", subexpr.str, field.str);
                }
            } else {
                strbprintf(&ret, "%s.%s", subexpr.str, field.str);
            }

            if (subexpr.alloced) strbfree(subexpr.str);
            if (field.alloced) strbfree(field.str);

            return (MaybeAllocStr){
                .str = ret,
                .alloced = true,
            };
        }
        case EkArrayIndex: {
            MaybeAllocStr access = gen_expr(gen, *expr.arrayidx.accessing);
            MaybeAllocStr index = gen_expr(gen, *expr.arrayidx.index);
            strb ret = NULL; strbprintf(&ret, "%s.ptr[%s]", access.str, index.str);

            if (access.alloced) strbfree(access.str);
            if (index.alloced) strbfree(index.str);

            return (MaybeAllocStr){
                .str = ret,
                .alloced = true,
            };
        }
        case EkGrouping: {
            MaybeAllocStr value = gen_expr(gen, *expr.group);
            strb ret = NULL; strbprintf(&ret, "(%s)", value.str);

            if (value.alloced) strbfree(value.str);
            return (MaybeAllocStr){
                .str = ret,
                .alloced = true,
            };
        } break;
        case EkFnCall:
            return gen_fn_call(gen, expr);
        case EkLiteral:
            return gen_literal_expr(gen, expr);
        case EkUnop:
            return gen_unop_expr(gen, expr);
        case EkBinop:
            return gen_binop_expr(gen, expr);
        case EkNone:
        case EkType:
        default:
            return (MaybeAllocStr){
                .str = "",
                .alloced = false,
            };
    }
}

// returns true if decl needs to be inserted
bool gen_decl_generic_slice(Gen *gen, Type type, strb *decl) {
    MaybeAllocStr typestr = gen_type(gen, *type.slice.of);

    strb typename = NULL;
    gen_typename(gen, type.slice.of, 1, &typename);

    strbprintfln(decl, "CurSliceDef(%s, %s);", typestr.str, typename);

    bool to_add = true;
    for (size_t i = 0; i < arrlenu(gen->generated_typedefs); i++) {
        if (streq(*decl, gen->generated_typedefs[i])) {
            to_add = false;
            break;
        }
    }

    strbfree(typename);
    if (typestr.alloced) strbfree(typestr.str);
    return to_add;
}

// returns true if decl needs to be inserted
bool gen_decl_generic_array(Gen *gen, Type type, strb *decl, uint8_t dimension) {
    if (type.kind == TkArray && type.array.of->kind == TkArray) {
        gen_decl_generic(gen, *type.array.of);
        gen_decl_generic_array(gen, *type.array.of->array.of, decl, dimension + 1);

        MaybeAllocStr length = gen_expr(gen, *type.array.of->array.len);
        strbprintf(decl, ", %s", length.str);

        if (dimension == 1) {
            MaybeAllocStr parent_len = gen_expr(gen, *type.array.len);
            strbprintfln(decl, ", %s)", parent_len.str);

            for (size_t i = 0; i < arrlenu(gen->generated_typedefs); i++) {
                if (streq(*decl, gen->generated_typedefs[i])) {
                    if (parent_len.alloced) strbfree(parent_len.str);
                    if (length.alloced) strbfree(length.str);

                    return false;
                }
            }

            if (parent_len.alloced) strbfree(parent_len.str);
        }

        if (length.alloced) strbfree(length.str);
        return true;
    } else if (type.kind == TkArray) {
        MaybeAllocStr typestr = gen_type(gen, *type.array.of);

        strb typename = NULL;
        gen_typename(gen, type.array.of, 1, &typename);

        MaybeAllocStr length = gen_expr(gen, *type.array.len);
        strbprintfln(decl, "CurArray1dDef(%s, %s, %s);", typestr.str, typename, length.str);

        for (size_t i = 0; i < arrlenu(gen->generated_typedefs); i++) {
            if (streq(*decl, gen->generated_typedefs[i])) {
                if (length.alloced) strbfree(length.str);
                strbfree(typename);
                if (typestr.alloced) strbfree(typestr.str);

                return false;
            }
        }

        if (length.alloced) strbfree(length.str);
        strbfree(typename);
        if (typestr.alloced) strbfree(typestr.str);
        return true;
    } else {
        MaybeAllocStr typestr = gen_type(gen, type);
        strb typename = NULL;

        gen_typename(gen, &type, 1, &typename);
        strbprintf(decl, "CurArray%ddDef(%s, %s", dimension, typestr.str, typename);

        strbfree(typename);
        if (typestr.alloced) strbfree(typestr.str);

        return true;
    }
}

void gen_decl_generic(Gen *gen, Type type) {
    strb def = NULL;

    switch (type.kind) {
        case TkSlice: {
            bool add = gen_decl_generic_slice(gen, type, &def);
            if (!add) {
                strbfree(def);
                return;
            }
        } break;
        case TkArray: {
            bool add = gen_decl_generic_array(gen, type, &def, 1);
            if (!add) {
                strbfree(def);
                return;
            }
        } break;
        case TkOption: {
            MaybeAllocStr typestr = gen_type(gen, *type.option.subtype);

            strb typename = NULL;
            gen_typename(gen, type.option.subtype, 1, &typename);

            strbprintfln(&def, "CurOptionDef(%s, %s);", typestr.str, typename);

            strbfree(typename);
            if (typestr.alloced) strbfree(typestr.str);

            for (size_t i = 0; i < arrlenu(gen->generated_typedefs); i++) {
                if (streq(def, gen->generated_typedefs[i])) {
                    strbfree(def);
                    return;
                }
            }
        } break;
        case TkTypeDef: {
            // NOTE: no generics right now, just for forward declaration
            // TODO: add typedefs generics

            strb typedeff = NULL;

            Stmnt stmnt = ast_find_decl(gen->ast, type.typedeff);
            if (stmnt.kind == SkStructDecl) {
                strbprintfln(&typedeff, "typedef struct %s %s;", type.typedeff, type.typedeff);
            } else if (stmnt.kind == SkEnumDecl) {
                strbprintfln(&typedeff, "typedef enum %s %s;", type.typedeff, type.typedeff);
            }

            for (size_t i = 0; i < arrlenu(gen->generated_typedefs); i++) {
                if (streq(typedeff, gen->generated_typedefs[i])) {
                    strbfree(typedeff);
                    return;
                }
            }
            arrpush(gen->generated_typedefs, typedeff);

            gen->defs = strbinsert(gen->defs, typedeff, gen->def_loc);
            gen->def_loc += strlen(typedeff);
        } break;
        default:
            return;
    }

    gen->defs = strbinsert(gen->defs, def, gen->def_loc);
    gen->def_loc += strlen(def);
    arrpush(gen->generated_typedefs, def);

    bool replaced = strreplace(def, "Def", "Imp");
    assert(replaced);
    gen->code = strbinsert(gen->code, def, gen->code_loc);
    gen->code_loc += strlen(def);

    replaced = strreplace(def, "Imp", "Def");
    assert(replaced);
}

strb gen_decl_proto(Gen *gen, Stmnt stmnt) {
    assert(stmnt.kind == SkVarDecl || stmnt.kind == SkConstDecl || stmnt.kind == SkFnDecl);
    const char *name = "";
    Type type;

    switch (stmnt.kind) {
        case SkVarDecl:
            assert(stmnt.vardecl.name.kind == EkIdent);
            name = stmnt.vardecl.name.ident;
            type = stmnt.vardecl.type;
            break;
        case SkConstDecl:
            assert(stmnt.constdecl.name.kind == EkIdent);
            name = stmnt.constdecl.name.ident;
            type = stmnt.constdecl.type;
            break;
        case SkFnDecl:
            assert(stmnt.fndecl.name.kind == EkIdent);
            name = stmnt.fndecl.name.ident;
            type = stmnt.fndecl.type;
            break;
        default: break;
    }

    strb ret = NULL;
    gen_indent(gen);
    if (type.kind == TkSlice || type.kind == TkArray || type.kind == TkOption) {
        gen_decl_generic(gen, type);

        strb typename = NULL;
        gen_typename(gen, &type, 1, &typename);

        strbprintf(&ret, "%s %s", typename, name);
        strbfree(typename);
        return ret;
    }

    MaybeAllocStr vartype = gen_type(gen, type);
    strbprintf(&ret, "%s %s", vartype.str, name);

    if (vartype.alloced) strbfree(vartype.str);
    return ret;
}

void gen_var_decl(Gen *gen, Stmnt stmnt) {
    assert(stmnt.kind == SkVarDecl);
    VarDecl vardecl = stmnt.vardecl;

    strb proto = gen_decl_proto(gen, stmnt);
    gen_write(gen, "%s", proto);

    if (vardecl.value.kind == EkNone) {
        if (vardecl.type.kind == TkArray) {
            gen_write(gen, " = ");

            MaybeAllocStr value = gen_array_literal_expr(gen, expr_literal(
                (Literal){
                    .kind = LitkExprs,
                    .exprs = NULL,
                },
                vardecl.type,
                stmnt.cursors_idx
                )
            );
            gen_writeln(gen, "%s;", value.str);

            if (value.alloced) strbfree(value.str);
            strbfree(proto);
            return;
        }

        gen_writeln(gen, ";");
    } else {
        gen_write(gen, " = ");

        MaybeAllocStr value = gen_expr(gen, vardecl.value);
        gen_writeln(gen, "%s;", value.str);

        if (value.alloced) strbfree(value.str);
    }

    strbfree(proto);
}

void gen_const_decl(Gen *gen, Stmnt stmnt) {
    assert(stmnt.kind == SkConstDecl);
    ConstDecl constdecl = stmnt.constdecl;

    strb proto = gen_decl_proto(gen, stmnt);

    gen_write(gen, "%s = ", proto);

    MaybeAllocStr value = gen_expr(gen, constdecl.value);
    gen_writeln(gen, "%s;", value.str);

    if (value.alloced) strbfree(value.str);
    strbfree(proto);
}

void gen_var_reassign(Gen *gen, Stmnt stmnt) {
    assert(stmnt.kind == SkVarReassign);
    VarReassign varre = stmnt.varreassign;

    gen_indent(gen);

    MaybeAllocStr reassign = gen_expr(gen, varre.name);
    MaybeAllocStr value = gen_expr(gen, varre.value);
    gen_writeln(gen, "%s = %s;", reassign.str, value.str);

    if (value.alloced) strbfree(value.str);
    if (reassign.alloced) strbfree(reassign.str);
}

void gen_all_defers(Gen *gen) {
    for (ptrdiff_t i = arrlen(gen->defers) - 1; i >= 0; i--) {
        gen_stmnt(gen, gen->defers[i].stmnt);
    }
}
void gen_defers(Gen *gen) {
    for (ptrdiff_t i = arrlen(gen->defers) - 1; i >= 0; i--) {
        if (gen->defers[i].indent == gen->indent) {
            gen_stmnt(gen, gen->defers[i].stmnt);
        }
    }
}

void gen_return(Gen *gen, Stmnt stmnt) {
    assert(stmnt.kind == SkReturn);
    gen_all_defers(gen);

    Return ret = stmnt.returnf;

    gen_indent(gen);
    if (ret.value.kind == EkNone) {
        gen_writeln(gen, "return;");
        return;
    }

    MaybeAllocStr value = gen_expr(gen, ret.value);
    gen_writeln(gen, "return %s;", value.str);

    if (value.alloced) strbfree(value.str);
}

void gen_continue(Gen *gen, Stmnt stmnt) {
    assert(stmnt.kind == SkContinue);
    gen_defers(gen);
    gen_indent(gen);
    gen_writeln(gen, "continue;");
}

void gen_break(Gen *gen, Stmnt stmnt) {
    assert(stmnt.kind == SkBreak);
    gen_defers(gen);
    gen_indent(gen);
    gen_writeln(gen, "break;");
}

void gen_fn_call_stmnt(Gen *gen, Stmnt stmnt) {
    assert(stmnt.kind == SkFnCall);
    Expr expr = expr_fncall(stmnt.fncall, type_none(), stmnt.cursors_idx);

    MaybeAllocStr call = gen_fn_call(gen, expr);
    gen_indent(gen);
    gen_writeln(gen, "%s;", call.str);

    if (call.alloced) strbfree(call.str);
}

void gen_if(Gen *gen, Stmnt stmnt) {
    assert(stmnt.kind == SkIf);
    If iff = stmnt.iff;

    gen_indent(gen);

    MaybeAllocStr cond = gen_expr(gen, iff.condition);

    if (iff.capturekind != CkNone) {
        gen_writeln(gen, "{");

        strb proto = gen_decl_proto(gen, *iff.capture.constdecl);
        gen_writeln(gen, "%s = %s.some;", proto, cond.str);
        gen_indent(gen);
        gen_write(gen, "if (%s.ok) ", cond.str);

        strbfree(proto);
    } else {
        gen_write(gen, "if (%s) ", cond.str);
    }

    gen_block(gen, iff.body);

    gen_indent(gen);
    gen_write(gen, "else ");
    gen_block(gen, iff.els);

    if (iff.capturekind != CkNone) {
        gen_indent(gen);
        gen_writeln(gen, "}");
    }

    if (cond.alloced) strbfree(cond.str);
}

void gen_for(Gen *gen, Stmnt stmnt) {
    assert(stmnt.kind == SkFor);
    For forf = stmnt.forf;

    gen_indent(gen);

    gen_writeln(gen, "{");

    gen_var_decl(gen, *forf.decl);

    MaybeAllocStr cond = gen_expr(gen, forf.condition);
    MaybeAllocStr reassign = gen_expr(gen, forf.reassign->varreassign.name);
    MaybeAllocStr value = gen_expr(gen, forf.reassign->varreassign.value);

    gen_indent(gen);
    gen_write(gen, "for (; %s; %s = %s) ", cond.str, reassign.str, value.str);
    gen_block(gen, forf.body);

    gen_indent(gen);
    gen_writeln(gen, "}");

    if (value.alloced) strbfree(value.str);
    if (reassign.alloced) strbfree(reassign.str);
    if (cond.alloced) strbfree(cond.str);
}

void gen_stmnt(Gen *gen, Stmnt *stmnt) {
    switch (stmnt->kind) {
        case SkNone:
            break;
        case SkDirective:
            gen_directive(gen, *stmnt);
            break;
        case SkExtern:
            gen_extern(gen, *stmnt);
            break;
        case SkDefer:
            gen_push_defer(gen, stmnt->defer);
            break;
        case SkBlock:
            gen_indent(gen);
            gen_block(gen, stmnt->block);
            gen_writeln(gen, "");
            break;
        case SkFnDecl:
            gen_fn_decl(gen, *stmnt, false);
            break;
        case SkStructDecl:
            // do nothing, defs will be resolved later
            break;
        case SkEnumDecl:
            // do nothing, defs will be resolved later
            break;
        case SkVarDecl:
            gen_var_decl(gen, *stmnt);
            break;
        case SkConstDecl:
            gen_const_decl(gen, *stmnt);
            break;
        case SkVarReassign:
            gen_var_reassign(gen, *stmnt);
            break;
        case SkReturn:
            gen_return(gen, *stmnt);
            break;
        case SkContinue:
            gen_continue(gen, *stmnt);
            break;
        case SkBreak:
            gen_break(gen, *stmnt);
            break;
        case SkFnCall:
            gen_fn_call_stmnt(gen, *stmnt);
            break;
        case SkIf:
            gen_if(gen, *stmnt);
            break;
        case SkFor:
            gen_for(gen, *stmnt);
            break;
    }
}

void gen_block(Gen *gen, Arr(Stmnt) block) {
    gen_writeln(gen, "{");
    gen->indent++;

    for (size_t i = 0; i < arrlenu(block); i++) {
        gen_stmnt(gen, &block[i]);
    }

    gen_defers(gen);
    gen_pop_defers(gen);
    gen->indent--;
    gen_indent(gen);
    gen_writeln(gen, "}");
}

void gen_fn_main_decl(Gen *gen, Stmnt stmnt) {
    assert(stmnt.kind == SkFnDecl);
    FnDecl fndecl = stmnt.fndecl;

    gen_writeln(gen, "int main(int argc, const char **argv) {");
    gen->indent++;

    if (arrlenu(fndecl.args) == 1) {
        Stmnt arg = fndecl.args[0];
        assert(arg.kind == SkConstDecl);

        assert(arg.constdecl.type.kind == TkSlice);
        gen_decl_generic(gen, arg.constdecl.type);

        gen_write(gen, builtin_args);
    }

    gen_indent(gen);
    gen_block(gen, fndecl.body);
    gen->indent--;
    gen_indent(gen);
    gen_writeln(gen, "}");
}

void gen_fn_decl(Gen *gen, Stmnt stmnt, bool is_extern) {
    assert(stmnt.kind == SkFnDecl);
    FnDecl fndecl = stmnt.fndecl;

    gen->code_loc = strlen(gen->code);
    gen->def_loc = strlen(gen->defs);
    gen_indent(gen);

    if (fndecl.name.kind == EkIdent && streq("main", fndecl.name.ident)) {
        gen_fn_main_decl(gen, stmnt);
        return;
    }

    strb proto = gen_decl_proto(gen, stmnt);
    strb code = NULL;
    strbprintf(&code, "%s(", proto);

    for (size_t i = 0; i < arrlenu(fndecl.args); i++) {
        Stmnt arg = fndecl.args[i];
        assert(arg.kind == SkConstDecl || arg.kind == SkVarDecl);

        strb arg_proto = gen_decl_proto(gen, arg);
        if (i == 0) {
            strbprintf(&code, "%s", arg_proto);
        } else {
            strbprintf(&code, ", %s", arg_proto);
        }

        strbfree(arg_proto);
    }
    strbprintf(&code, ")");

    gen->in_defs = true;
    gen_writeln(gen, "%s;", code);
    gen->in_defs = false;

    if (fndecl.has_body) {
        gen_write(gen, "%s ", code);
        gen_block(gen, fndecl.body);
    } else if (!is_extern) {
        gen_writeln(gen, "%v;", code);
    }

    strbfree(proto);
}

void gen_extern(Gen *gen, Stmnt stmnt) {
    assert(stmnt.kind == SkExtern);
    Stmnt *externf = stmnt.externf;

    switch (externf->kind) {
        case SkFnDecl:
            gen_fn_decl(gen, *stmnt.externf, true);
            break;
        case SkVarDecl:
            gen_var_decl(gen, *stmnt.externf);
            break;
        case SkConstDecl:
            gen_const_decl(gen, *stmnt.externf);
            break;
        case SkVarReassign:
            gen_var_reassign(gen, *stmnt.externf);
            break;
        default:
            break;
    }
}

void gen_struct_decl(Gen *gen, Stmnt stmnt) {
    assert(stmnt.kind == SkStructDecl);
    StructDecl structd = stmnt.structdecl;

    strb struct_def = NULL;
    strbprintf(&struct_def, "struct %s", structd.name.ident);

    for (size_t i = 0; i < arrlenu(gen->generated_typedefs); i++) {
        if (streq(struct_def, gen->generated_typedefs[i])) {
            strbfree(struct_def);
            return;
        }
    }
    arrpush(gen->generated_typedefs, struct_def);

    gen->def_loc = strlen(gen->defs);
    gen_indent(gen);

    gen->in_defs = true;
    gen_write(gen, "%s", struct_def);
    gen_block(gen, structd.fields);
    gen_writeln(gen, ";");
    gen->in_defs = false;
}

void gen_enum_decl(Gen *gen, Stmnt stmnt) {
    assert(stmnt.kind == SkEnumDecl);
    EnumDecl enumd = stmnt.enumdecl;

    strb enum_def = NULL;
    strbprintf(&enum_def, "enum %s", enumd.name.ident);

    for (size_t i = 0; i < arrlenu(gen->generated_typedefs); i++) {
        if (streq(enum_def, gen->generated_typedefs[i])) {
            strbfree(enum_def);
            return;
        }
    }

    arrpush(gen->generated_typedefs, enum_def);
    gen->def_loc = strlen(gen->defs);
    gen_indent(gen);

    gen->in_defs = true;

    gen_writeln(gen, "%s {", enum_def);
    gen->indent++;
    for (size_t i = 0; i < arrlenu(enumd.fields); i++) {
        assert(enumd.fields[i].kind == SkConstDecl);
        Stmnt f = enumd.fields[i];

        MaybeAllocStr expr = gen_expr(gen, f.constdecl.value);
        gen_indent(gen);
        gen_writeln(gen, "%s_%s = %s,", enumd.name.ident, f.constdecl.name.ident, expr.str);

        if (expr.alloced) strbfree(expr.str);
    }
    gen->indent--;
    gen_writeln(gen, "};");

    gen->in_defs = false;
}

void gen_resolve_def(Gen *gen, Dnode node) {
    for (size_t i = 0; i < arrlenu(node.children); i++) {
        size_t index = 0;
        for (; index < arrlenu(gen->dgraph.names); index++) {
            if (streq(node.children[i], gen->dgraph.names[index])) {
                break;
            }
        }

        gen_resolve_def(gen, gen->dgraph.children[index]);
    }

    Stmnt stmnt = node.us;
    if (stmnt.kind == SkStructDecl) {
        gen_struct_decl(gen, stmnt);
    } else if (stmnt.kind == SkEnumDecl) {
        gen_enum_decl(gen, stmnt);
    }
}

void gen_resolve_defs(Gen *gen) {
    for (size_t i = 0; i < arrlenu(gen->dgraph.children); i++) {
        gen_resolve_def(gen, gen->dgraph.children[i]);
    }
}

void gen_generate(Gen *gen) {
    char *defs;
    bool defs_ok = read_entire_file("./newsrc/current_builtin_defs.txt", &defs);
    if (!defs_ok) {
        defs = builtin_defs;
    }

    strbprintf(&gen->defs, "%s", defs);
    strbprintf(&gen->code, "#include \"output.h\"\n");

    for (size_t i = 0; i < arrlenu(gen->ast); i++) {
        Stmnt stmnt = gen->ast[i];
        switch (stmnt.kind) {
            case SkDirective:
                gen_directive(gen, stmnt);
                break;
            case SkExtern:
                gen_extern(gen, stmnt);
                break;
            case SkFnDecl:
                gen_fn_decl(gen, stmnt, false);
                break;
            case SkStructDecl:
            case SkEnumDecl:
                // do nothing, defs will be resolved later
                break;
            case SkVarDecl:
                gen_var_decl(gen, stmnt);
                break;
            case SkConstDecl:
                gen_const_decl(gen, stmnt);
                break;
            case SkVarReassign:
                gen_var_reassign(gen, stmnt);
                break;
            default:
                break;
        }
    }

    gen_resolve_defs(gen);

    strbprintf(&gen->defs, "#endif // CURRENT_DEFS_H");
}
