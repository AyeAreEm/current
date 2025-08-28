#!/usr/bin/env bash

option="$1"

build() {
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
}

if [ "$option" == "build" ]; then
    build
elif [ "$option" == "run" ]; then
    build
    ./current ${@:2}
else
    echo invalid option $option
fi
