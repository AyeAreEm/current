@echo off

set option=%1

if "%option%"=="build" (
    odin build src -out:xlang.exe
) else if "%option%"=="run" (
    odin run src -out:xlang.exe
) else (
    echo invalid option
)
