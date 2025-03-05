#!/bin/bash

option="$1"

if [[ "$option" == "build" ]]; then
    odin build src -out:xlang
else [[ "$option" == "run" ]]; then
    odin run src -out:xlang
else
    echo invalid option
fi
