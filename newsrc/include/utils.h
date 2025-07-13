#ifndef UTILS_H
#define UTILS_H

#include <stdarg.h>
#include <stdbool.h>
#include <assert.h>
#include <stddef.h>
#include <stdint.h>

#define TERM_RED  "\x1B[91;1m"
#define TERM_YELLOW  "\x1B[93;1m"
#define TERM_END  "\x1B[0m"

#define AT(xs, len, index) (assert((index) < (len)), (xs)[(index)])
#define PUSH(xs, len, tail_idx, item) (assert((tail_idx) < (len)), (xs)[(tail_idx)++] = (item))
#define STRPUSH(str, len, tail_idx, ch)\
    do {\
        PUSH((str), (len), (tail_idx), (ch));\
        assert((tail_idx) < (len));\
        (str)[(tail_idx)] = '\0';\
    } while (0);\

void printfln(const char *fmt, ...);

void eprintf(const char *fmt, ...);
void eprintfln(const char *fmt, ...);

void debug(const char *msg, ...);
void elog(const char *msg, ...);

// returns false if failed
bool read_file(const char *filename, char **buf);

// returns false if failed
bool parse_u64(const char *str, uint64_t *n);

// returns false if failed
bool parse_f64(const char *str, double *n);

// uses malloc
char *strclone(const char *str);

// sets str[0] = 0 and *len = 0.
// len can be NULL
void strclear(char *str, size_t *tail_idx);
#endif // UTILS_H
