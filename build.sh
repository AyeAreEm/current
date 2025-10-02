#!/usr/bin/env bash

option="$1"
cflags="-Wall -Wextra -Wpedantic"

build() {
    gcc $cflags $1 -o current \
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

release() {
    build "-g -Og"
}

if [ "$option" == "build" ]; then
    build ""
elif [ "$option" == "release" ]; then
    release
elif [ "$option" == "run" ]; then
    build
    ./current ${@:2}
else
    echo invalid option $option
fi
