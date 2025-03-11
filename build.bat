@echo off

set option=%1

if "%option%"=="build" (
    odin build src -out:current.exe
) else if "%option%"=="run" (
    shift
    odin run src -out:current.exe -- %*
) else (
    echo invalid option
)
