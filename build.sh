#!/usr/bin/env bash

option="$1"

build() {
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
}

if [ "$option" == "build" ]; then
    build
elif [ "$option" == "run" ]; then
    build
    ./current ${@:2}
else
    echo invalid option $option
fi
