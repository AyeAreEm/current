#include <stdint.h>
#include <string.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include "include/utils.h"

void vprintfln(const char *fmt, va_list args) {
    vprintf(fmt, args); 
    printf("\n");
}

void printfln(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vprintfln(fmt, args);
    va_end(args);
}

void veprintf(const char *fmt, va_list args) {
    vfprintf(stderr, fmt, args);
}

void veprintfln(const char *fmt, va_list args) {
    veprintf(fmt, args);
    fprintf(stderr, "\n");
}

void eprintf(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    veprintf(fmt, args);
    va_end(args);
}

void eprintfln(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    veprintfln(fmt, args);
    va_end(args);
}

// returns false if failed
bool read_file(const char *filename, char **buf) {
    long length = 0;
    FILE *fd = fopen(filename, "rb");
    if (!fd) return false;

    fseek(fd, length, SEEK_END);
    length = ftell(fd);
    fseek(fd, 0, SEEK_SET);

    if (length == -1) {
        fclose(fd);
        return false;
    }

    *buf = malloc((length + 1) * sizeof(char));
    if (*buf) {
        size_t read = fread(*buf, sizeof(char), length, fd);
        if (read != (size_t)length) {
            fclose(fd);
            return false;
        }
    }
    (*buf)[(size_t)length + 1] = '\0';

    fclose(fd);
    return true;
}

void debug(const char *msg, ...) {
    printf(TERM_YELLOW "DEBUG" TERM_END ": ");

    va_list args;
    va_start(args, msg);

    vprintfln(msg, args);

    va_end(args);
}

void comp_elog(const char *msg, ...) {
    eprintf(TERM_RED "error" TERM_END ": ");

    va_list args;
    va_start(args, msg);

    veprintfln(msg, args);

    va_end(args);
    exit(1);
}

// returns false if failed
bool parse_u64(const char *str, uint64_t *n) {
    if (strcmp(str, " ") == 0) return false;

    size_t str_head = 0;
    uint64_t value = 0;

    if (strlen(str) > 1 && str[str_head] == '+') {
        str_head += 1;
    }

    int base = 10;
    if (strlen(str) > 2 && str[str_head] == '0') {
        switch (str[str_head + 1]) {
            case 'b':
            {
                base = 2;
                str_head += 2;
            } break;
            case 'o':
            {
                base = 8;
                str_head += 2;
            } break;
            case 'x':
            {
                base = 16;
                str_head += 2;
            } break;
        }
    }

    size_t index = 0;
    for (size_t i = 0; i < strlen(str); i++) {
        if (str[i] == '_') {
            index += 1;
            continue;
        }
        uint64_t v = str[i] - '0';
        if (v >= base) {
            break;
        }
        value *= base;
        value += v;
        index += 1;
    }
    str_head += index;

    *n = value;
    return str_head == strlen(str);
}

bool parse_f64(const char *str, double *n) {
    char *end;
    double x = strtod(str, &end);
    *n = x;
    return *end == '\0';
}

char *strclone(const char *str) {
    char *s = malloc(strlen(str) + sizeof(char));
    for (size_t i = 0; i < strlen(str); i++) {
        s[i] = str[i];
    }
    s[strlen(str)] = '\0';
    return s;
}

void strclear(char *str, size_t *tail_idx) {
    if (tail_idx) {
        for (size_t i = 0; i < *tail_idx; i++) {
            str[i] = '\0';
        }
        *tail_idx = 0;
    } else {
        str[0] = '\0';
    }
}

bool streq(const char *s1, const char *s2) {
    return strcmp(s1, s2) == 0;
}

bool strhas(const char *hay, const char *needle) {
    size_t needle_idx = 0;
    size_t needle_len = strlen(needle);
    size_t hay_len = strlen(needle);

    if (needle_len > hay_len) {
        return false;
    }

    for (size_t i = 0; i < hay_len; i++) {
        if (hay[i] != needle[needle_idx]) {
            needle_idx = 0;
            continue;
        }

        needle_idx++;
        if (needle_idx == needle_len) return true;
    }

    return false;
}

void *ealloc(size_t size) {
    void *mem = malloc(size);
    if (!mem) {
        comp_elog("failed to allocate memory");
    }
    return mem;
}

void *erealloc(void *mem, size_t size) {
    mem = realloc(mem, size);
    if (!mem) {
        comp_elog("failed to reallocate memory");
    }
    return mem;
}
