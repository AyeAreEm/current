#ifndef STRINGBUILDER_H
#define STRINGBUILDER_H

#include <stddef.h>
#include <stdarg.h>

typedef struct strbheader {
    size_t cap;
} strbheader;
typedef char* strb;

void strbpush(strb *s, char c);
void vstrbprintf(strb *s, const char *fmt, va_list args);
void strbprintf(strb *s, const char *fmt, ...);
void strbprintfln(strb *s, const char *fmt, ...);

// warning: this frees sb and returns a new strb
strb strbinsert(strb sb, const char *str, size_t index);

// if s == NULL, nothing happens
void strbfree(strb s);

#endif // STRINGBUILDER_H
