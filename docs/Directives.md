# Directives
Current does not have build options from the cli but instead is written in your code.<br>
The idea is to have a full compile time system in place that uses directives and compile time code.

## Output
Specify output name.<br>
NOTE: without this directive, the compiler will assume the output name is the same as the filename passed to it
```c
#output "foo";
```

## Optimisation
There are 7 types of optimisation in Current.<br>
NOTE: if an optimisation has already been set, another optimise directive will be an error. You can change the kind of optimisation programmatically using compile time ifs.
1. O0
    - No optimisations
1. O1
    - Reduce size and execution time, longer compilation time
1. 02
    - Basically O1++, reduce size more, reduce execution time more, longer compilation time more
1. 03
    - Basically O2++, reduce size even more, reduce execution time even more, longer compilation time even more
    - May break your program
1. Odebug
    - This is the default. Includes debug information, emphasizes shorter compilation time with slight reduction in execution time
    - Middleground of O0 and O1, but with debug information
1. Ofast
    - Aggressive optimisation for fast execution time
    - May break your program
1. Osmall
    - Smaller executable size + O2

```
#O0;
#O1;
#O2;
#O3;
#Odebug;
#Ofast;
#Osmall;
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
```
