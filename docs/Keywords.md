# Keywords
List of all keywords and how to use them<br>
NOTE: if you are looking for types, look at <a href="./Types.md">Types.md</a>

```
fn
    foo :: fn() void;

return
    return 10;

extern
    extern foo :: fn() void;

true | false
    foo := true;
    foo := false;

null
    foo: ?i32 = null; // need to specify the type

if
    if (true) { }

    some_value: ?i32 = 10;
    if (some_value) [sv] {
        // sv == 10
    }

else
    if (true) {
    } else if (foo) {
    } else {
    }

for
    for (i := 0; i < 10; i += 1) { }

    nums := [3]i32{1, 2, 3};
    for (nums) [n] { }
    for (nums) [n, i] {
        // n == 1 ... 2 ... 3
        // i == 0 ... 1 ... 2
    }
    for (nums) [&n] {
        // n: *i32;
        // if nums was a constant then
        // n: ^i32;
    }
```
