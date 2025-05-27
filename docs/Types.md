# Types
Primitive types
```
void

bool

i8 i16 i32 i64 isize
u8 u16 u32 u64 usize

f32 f64

char -> utf8

* -> pointer to variable (*i32)
^ -> pointer to constant (^i32)

[N]type -> array of N types ([2]i32 or [_]i32{1, 2})

string -> [^]u8 + '\0', len
cstring -> [^]u8 + '\0'

? -> option (?i32)
! -> result (!i32)
```
