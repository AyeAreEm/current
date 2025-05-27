# Directives
Current does not have build options from the cli but instead is written in your code.<br>
The idea is to have a full compile time system in place that uses directives and compile time code.

## Output
Specify output name.<br>
NOTE: without this directive, the compiler will assume the output name is the same as the filename passed to it
```c
#output "foo";
```

## Syslink
Link with system library name
```c
#syslink "c";
#syslink "raylib";
```
## Link
Link with relative path to filename
```c
#link "./foo.o";
#link "./bar.a";
#link "./baz.a";
```
