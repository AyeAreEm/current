# Directives
Current does not have build options from the cli but instead is written in your code.<br>
The idea is to have a full compile time system in place that uses directives and compile time code.

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
