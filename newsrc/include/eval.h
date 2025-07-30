#ifndef EVAL_H
#define EVAL_H

#include <stdint.h>
#include "sema.h"

uint64_t eval_expr(Sema *sema, Expr *expr);

#endif // EVAL_H
