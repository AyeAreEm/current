#ifndef TYPECHECK_H
#define TYPECHECK_H

#include "sema.h"

void tc_make_constant(Type *type);
void tc_const_decl(Sema *sema, Stmnt *stmnt);
bool tc_can_compare_equality(Type lhs, Type rhs);
bool tc_can_compare_order(Type lhs, Type rhs);
bool tc_is_unsigned(Sema *sema, Expr expr);
void tc_var_decl(Sema *sema, Stmnt *stmnt);
bool tc_equals(Sema *sema, Type lhs, Type *rhs);
void tc_number_within_bounds(Sema *sema, Type type, Expr expr);
void tc_return(Sema *sema, Stmnt *stmnt);

#endif // TYPECHECK_H
