@echo off

:build
    gcc -Wall -Wextra -Wpedantic -o current \
    src/cli.c       \
    src/eval.c      \
    src/exprs.c     \
    src/gen.c       \
    src/keywords.c  \
    src/lexer.c     \
    src/main.c      \
    src/parser.c    \
    src/sema.c      \
    src/stmnts.c    \
    src/strb.c      \
    src/typecheck.c \
    src/types.c     \
    src/utils.c

if "%1"=="build" (
    call :build
) else if "%1"=="run" (
    call :build
    rem i hate batch
    ./current %2 %3 %4 %5 %6 %7 %8 %9
) else (
    echo invalid option %1
)
