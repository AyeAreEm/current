#!/usr/bin/env bash

option="$1"

functions() {
    gcc -c -o tests/functions/greet.o tests/functions/greet.c
    ./current run tests/functions/main.cur
    echo functions exit code: $?
}

structs() {
    ./current run tests/structs/main.cur
    echo structs exit code: $?
}

vars() {
    ./current run tests/vars/main.cur
    echo vars exit code: $?
}

consts() {
    ./current run tests/consts/main.cur
    echo consts exit code: $?
}

enums() {
    ./current run tests/enums/main.cur
    echo enums exit code: $?
}

directives() {
    ./current run tests/directives/main.cur
    echo directives exit code: $?
}

escaped() {
    ./current run tests/escaped/main.cur
    echo escaped exit code: $?
}

arrays() {
    ./current run tests/arrays/main.cur
    echo escaped exit code: $?
}

options() {
    ./current run tests/options/main.cur
    echo escaped exit code: $?
}

all() {
    functions
    structs
    vars
    consts
    enums
    directives
    escaped
    arrays
    options
}

if [ "$option" == "functions" ]; then
    functions
elif [ "$option" == "structs" ]; then
    structs
elif [ "$option" == "vars" ]; then
    vars
elif [ "$option" == "consts" ]; then
    consts
elif [ "$option" == "enums" ]; then
    enums
elif [ "$option" == "directives" ]; then
    directives
elif [ "$option" == "escaped" ]; then
    escaped
elif [ "$option" == "arrays" ]; then
    arrays
elif [ "$option" == "options" ]; then
    options
elif [ "$option" == "all" ]; then
    all
else
    echo invalid option $option
fi
