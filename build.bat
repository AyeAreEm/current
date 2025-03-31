@echo off
if "%1"=="build" (
    odin build src -out:current.exe
) else if "%1"=="run" (
    rem i hate batch
    odin run src -out:current.exe -- %2 %3 %4 %5 %6 %7 %8 %9
) else (
    echo invalid option %1
)
