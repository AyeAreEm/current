#!/usr/bin/env bash

option="$1"

functions() {
    gcc -c -o tests/functions/greet.o tests/functions/greet.c
    ./pine run tests/functions/main.pine
    echo functions exit code: $?
}

structs() {
    ./pine run tests/structs/main.pine
    echo structs exit code: $?
}

vars() {
    ./pine run tests/vars/main.pine
    echo vars exit code: $?
}

consts() {
    ./pine run tests/consts/main.pine
    echo consts exit code: $?
}

enums() {
    ./pine run tests/enums/main.pine
    echo enums exit code: $?
}

directives() {
    ./pine run tests/directives/main.pine
    echo directives exit code: $?
}

escaped() {
    ./pine run tests/escaped/main.pine
    echo escaped exit code: $?
}

arrays() {
    ./pine run tests/arrays/main.pine
    echo escaped exit code: $?
}

options() {
    ./pine run tests/options/main.pine
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
