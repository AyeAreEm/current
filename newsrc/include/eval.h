#ifndef EVAL_H
#define EVAL_H

#include <stddef.h>
#include <stdint.h>
#include "util.h"
#include "sema.h"

typedef enum NumberKind {
    NkF32,
    NkF64,

    NkU8,
    NkU16,
    NkU32,
    NkU64,
    NkUsize,

    NkI8,
    NkI16,
    NkI32,
    NkI64,
    NkIsize,
} NumberKind;

typedef struct Number {
    NumberKind kind;
    union {
        float f32;
        double f64;

        uint8_t u8;
        uint16_t u16;
        uint32_t u32;
        uint64_t u64;
        size_t usize;

        int8_t i8;
        int16_t i16;
        int32_t i32;
        int64_t i64;
        ssize_t isize;
    };
} Number;

Number eval_int_cast(Type type, uint64_t value);
uint64_t eval_expr(Sema *sema, Expr *expr);

#endif // EVAL_H
