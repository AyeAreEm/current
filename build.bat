@echo off

:build
    gcc -Wall -Wextra -Wpedantic -o current \
    newsrc/cli.c       \
    newsrc/eval.c      \
    newsrc/exprs.c     \
    newsrc/gen.c       \
    newsrc/keywords.c  \
    newsrc/lexer.c     \
    newsrc/main.c      \
    newsrc/parser.c    \
    newsrc/sema.c      \
    newsrc/stmnts.c    \
    newsrc/strb.c      \
    newsrc/typecheck.c \
    newsrc/types.c     \
    newsrc/utils.c

if "%1"=="build" (
    call :build
) else if "%1"=="run" (
    call :build
    rem i hate batch
    ./current %2 %3 %4 %5 %6 %7 %8 %9
) else (
    echo invalid option %1
)
