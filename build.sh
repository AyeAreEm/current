#!/usr/bin/env bash

option="$1"

if [ "$option" == "build" ]; then
    odin build src -out:current
elif [ "$option" == "run" ]; then
    odin run src -out:current -- ${@:2}
else
    echo invalid option $option
fi
