#ifndef TYPES_H
#define TYPES_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

typedef struct Type Type;
typedef struct Expr Expr;

typedef enum TypeKind {
    TkNone, // null

    TkVoid,
    TkBool,

    TkChar,
    TkString,
    TkCstring,

    TkI8,
    TkI16,
    TkI32,
    TkI64,
    TkIsize,

    TkU8,
    TkU16,
    TkU32,
    TkU64,
    TkUsize,

    TkF32,
    TkF64,

    TkUntypedInt,
    TkUntypedFloat,

    TkArray,
    TkPtr,
    TkOption,

    TkTypeDef,
    TkTypeId,
} TypeKind;

typedef struct Array {
    Type *of;
    Expr *len; // if NULL, infer len
} Array;

typedef struct Option {
    Type *subtype;
    bool is_null;
    bool gen_option;
} Option;

typedef struct Type {
    TypeKind kind;
    size_t cursors_idx;
    bool constant;

    union {
        Array array;
        Type *ptr_to;
        Option option;
        const char *typedeff;
    };
} Type;

#define CONSTNESS bool
#define TYPECONST true
#define TYPEVAR   false

Type type_map(const char *t);
const char *typekind_stringify(TypeKind t);
Type type_none(void);
Type type_void(CONSTNESS constant, size_t index);
Type type_bool(CONSTNESS constant, size_t index);
Type type_char(CONSTNESS constant, size_t index);
Type type_string(CONSTNESS constant, size_t index);
Type type_cstring(CONSTNESS constant, size_t index);
Type type_integer(TypeKind kind, CONSTNESS constant, size_t index);
Type type_decimal(TypeKind kind, CONSTNESS constant, size_t index);
Type type_array(Array v, CONSTNESS constant, size_t index);
Type type_ptr(Type *v, CONSTNESS constant, size_t index);
Type type_option(Option v, CONSTNESS constant, size_t index);
Type type_typedef(const char *v, CONSTNESS constant, size_t index);

#endif // TYPES_H
