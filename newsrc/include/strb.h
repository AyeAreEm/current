#ifndef STRINGBUILDER_H
#define STRINGBUILDER_H

#include <stddef.h>

typedef struct strbheader {
    size_t cap;
} strbheader;
typedef char* strb;

void strbpush(strb *s, char c);
void strbprintf(strb *s, const char *fmt, ...);

// if s == NULL, nothing happens
void strbfree(strb s);

#endif // STRINGBUILDER_H
