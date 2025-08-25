#include <stdarg.h>
#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include "include/strb.h"
#include "include/utils.h"

static strbheader *strbh(strb s) {
    return (strbheader*)(s) - 1;
}

static size_t strbcap(strb s) {
    return strbh(s)->cap;
}

void strbnew(strb *s) {
    strbheader *h = ealloc(sizeof(strbheader) + sizeof(char) * 2);
    h->cap = 2;
    *s = (char *)(h + 1);
}

void strbgrow(strb *s) {
    strbheader *h = erealloc(strbh(*s), strbcap(*s) * 2 + sizeof(char) + sizeof(strbheader));
    h->cap = h->cap * 2 + 1;
    *s = (char*)(h + 1);
}

void strbpush(strb *s, char c) {
    if (*s == NULL) {
        strbnew(s);
    } else if (strlen(*s) + 1 >= strbcap(*s)) {
        strbgrow(s);
    }

    size_t len = strlen(*s);
    (*s)[len] = c;
    (*s)[len + 1] = '\0';
}

static void strbpushs(strb *sb, const char *s) {
    for (size_t i = 0; i < strlen(s); i++) {
        strbpush(sb, s[i]);
    }
}

void vstrbprintf(strb *s, const char *fmt, va_list args) {
    char *buf;
    vasprintf(&buf, fmt, args);
    strbpushs(s, buf);
}

void strbprintf(strb *s, const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vstrbprintf(s, fmt, args);
    va_end(args);
}

void strbprintfln(strb *s, const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vstrbprintf(s, fmt, args);
    strbpush(s, '\n');
    va_end(args);
}

// warning: this frees sb and returns a new strb
strb strbinsert(strb sb, const char *str, size_t index) {
    assert(strlen(sb) >= index);

    strb newsb = NULL;
    for (size_t i = 0; i < index; i++) {
        strbpush(&newsb, sb[i]);
    }
    strbpushs(&newsb, str);
    for (size_t i = index; i < strlen(sb); i++) {
        strbpush(&newsb, sb[i]);
    }
    strbfree(sb);

    return newsb;
}

void strbfree(strb s) {
    if (s) {
        free(strbh(s));
    }
}
