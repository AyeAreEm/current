#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdbool.h>
#if defined(__linux__) || defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__) || defined(__sun) || defined(__CYGWIN__)
#include <sys/types.h>
#elif defined(_WIN32) || defined(__MINGW32__)
#include <BaseTsd.h>
typedef SSIZE_T ssize_t;
#endif
typedef int8_t i8;
typedef int16_t i16;
typedef int32_t i32;
typedef int64_t i64;
typedef ssize_t isize;
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef size_t usize;
typedef float f32;
typedef double f64;
typedef struct CurString {
    const char *ptr;
    usize len;
} CurString;
#define curstr(s) ((CurString){.ptr = s, strlen(s)})
#define CurArray1d(T, Tname, A)\
typedef struct CurArray1d_##Tname##A {\
    T *ptr;\
    usize len;\
} CurArray1d_##Tname##A;\
CurArray1d_##Tname##A curarray1d_##Tname##A(T *ptr, usize len) {\
    CurArray1d_##Tname##A ret;\
    ret.ptr = ptr;\
    ret.len = len;\
    return ret;\
}
#define CurArray2d(T, Tname, A, B)\
typedef struct CurArray2d_##Tname##B##A {\
    CurArray1d_##Tname##A* ptr;\
    usize len;\
} CurArray2d_##Tname##B##A;\
CurArray2d_##Tname##B##A curarray2d_##Tname##B##A(CurArray1d_##Tname##A *ptr, usize len) {\
    CurArray2d_##Tname##B##A ret;\
    ret.ptr = ptr;\
    ret.len = len;\
    return ret;\
}
CurArray1d(i32, i32, 5);
CurArray1d_i325 gimme_5_i32s() {
    return curarray1d_i325((i32[5]){1, 2, 3, 4, 5}, 5);
}
int main() {
    CurArray1d_i325 arr = gimme_5_i32s();
}
