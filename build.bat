@echo off
shift
set option=%0
shift
set params=%0
shift
if "%option%"=="build" (
    odin build src -out:current.exe
) else if "%option%"=="run" (
    :loop
    if "%0"=="" goto endloop
    set params=%params% %0
    shift
    goto loop
    :endloop
    echo %params%
    odin run src -out:current.exe -- %params%
) else (
    echo invalid option
)
