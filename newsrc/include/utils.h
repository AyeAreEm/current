#ifndef UTILS_H
#define UTILS_H

#include <stdarg.h>
#include <stdbool.h>
#include <assert.h>
#include <stddef.h>
#include <stdint.h>

#if defined(__linux__) || defined(__APPLE__) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__) || defined(__sun) || defined(__CYGWIN__)
#include <sys/types.h>
#elif defined(_WIN32) || defined(__MINGW32__)
#include <BaseTsd.h>
typedef SSIZE_T ssize_t;
#endif

#define TERM_RED     "\x1b[31m"
#define TERM_GREEN   "\x1b[32m"
#define TERM_YELLOW  "\x1b[33m"
#define TERM_BLUE    "\x1b[34m"
#define TERM_MAGENTA "\x1b[35m"
#define TERM_CYAN    "\x1b[36m"
#define TERM_END     "\x1b[0m"

#define TEST(cond) (printf("%s:%d %s\n", __FILE_NAME__, __LINE__, (cond) ? TERM_GREEN "PASSED" TERM_END : TERM_RED "FAILED" TERM_END))

#define AT(xs, len, index) (assert((index) < (len)), (xs)[(index)])
#define PUSH(xs, len, tail_idx, item) (assert((tail_idx) < (len)), (xs)[(tail_idx)++] = (item))
#define STRPUSH(str, len, tail_idx, ch)\
    do {\
        PUSH((str), (len), (tail_idx), (ch));\
        assert((tail_idx) < (len));\
        (str)[(tail_idx)] = '\0';\
    } while (0)\

void vprintfln(const char *fmt, va_list args);

void printfln(const char *fmt, ...);

void veprintf(const char *fmt, va_list args);
void veprintfln(const char *fmt, va_list args);

void eprintf(const char *fmt, ...);
void eprintfln(const char *fmt, ...);

void debug(const char *msg, ...);
void comp_elog(const char *msg, ...);

// returns false if failed
bool read_entire_file(const char *filename, char **buf);

// return false if failed
bool write_entire_file(const char *filename, const char *content);

// returns false if failed
bool parse_u64(const char *str, uint64_t *n);

// returns false if failed
bool parse_f64(const char *str, double *n);

// uses malloc
char *strclone(const char *str);

// sets str[0] = 0 and *len = 0.
// len can be NULL
void strclear(char *str, size_t *tail_idx);

bool streq(const char *s1, const char *s2);

int strhas(const char *hay, const char *needle);

// from and to must be of the same size
bool strreplace(char *s, const char *from, const char *to);

char *strltrim(char *str);
char *strrtrim(char *str);
char *strtrim(char *str);

// errors and exits when NULL
void *ealloc(size_t size);

// erroors and exits when NULL
void *erealloc(void *mem, size_t size);
#endif // UTILS_H
