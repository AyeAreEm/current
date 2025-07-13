#!/usr/bin/env bash

option="$1"

build() {
    gcc -o current newsrc/main.c newsrc/cli.c newsrc/lexer.c newsrc/utils.c
}

if [ "$option" == "build" ]; then
    build
    # odin build src -out:current
elif [ "$option" == "run" ]; then
    build
    ./current ${@:2}
    # odin run src -out:current -- ${@:2}
else
    echo invalid option $option
fi
