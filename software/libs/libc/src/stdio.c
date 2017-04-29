//
// Copyright 2011-2015 Jeff Bush
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "__stdio_internal.h"
#include "uart.h"

int printf(const char *fmt, ...)
{
    va_list arglist;

    va_start(arglist, fmt);
    vfprintf(stdout, fmt, arglist);
    va_end(arglist);

    return 0;
}

int sprintf(char *buf, const char *fmt, ...)
{
    va_list arglist;
    FILE str = {
        .write_buf = buf,
        .write_offset = 0,
        .write_buf_len = 0x7fffffff
    };

    va_start(arglist, fmt);
    vfprintf(&str, fmt, arglist);
    va_end(arglist);
    fputc('\0', &str);	// Null terminate

    return str.write_offset;
}

int snprintf(char *buf, size_t length, const char *fmt, ...)
{
    va_list arglist;
    FILE str = {
        .write_buf = buf,
        .write_offset = 0,
        .write_buf_len = length
    };

    va_start(arglist, fmt);
    vfprintf(&str, fmt, arglist);
    va_end(arglist);
    fputc('\0', &str);	// Null terminate

    return str.write_offset;
}

int vsnprintf(char *buf, size_t length, const char *fmt, va_list arglist)
{
    FILE str = {
        .write_buf = buf,
        .write_offset = 0,
        .write_buf_len = length
    };

    vfprintf(&str, fmt, arglist);
    fputc('\0', &str);	// Null terminate

    return str.write_offset;
}

static FILE __stdout = {
    .write_buf = NULL,
    .write_offset = 0,
    .write_buf_len = 0
};

static FILE __stdin = {
    .write_buf = NULL,
    .write_offset = 0,
    .write_buf_len = 0
};

FILE *stdout = &__stdout;
FILE *stderr = &__stdout;
FILE *stdin = &__stdin;

int putchar(int ch)
{
    fputc(ch, stdout);
    return 1;
}

int puts(const char *s)
{
    const char *c;
    for (c = s; *c; c++)
        putchar(*c);

    putchar('\n');
    return c - s + 1;
}

int fputc(int ch, FILE *file)
{
    if (file == stdout)
        write_uart(ch);
    else if (file->write_buf)
    {
        if (file->write_offset < file->write_buf_len)
            file->write_buf[file->write_offset++] = ch;
    }
    else
        write(file->fd, &ch, 1);

    return 1;
}

int fputs(const char *str, FILE *file)
{
    const char *c;
    for (c = str; *c; c++)
        fputc(*c, file);

    return c - str;
}

int fgetc(FILE *f)
{
    unsigned char c;
    int got = read(f->fd, &c, 1);
    if (got < 0)
        return -1;

    return c;
}

FILE *fopen(const char *filename, const char *mode)
{
    (void) mode;

    int fd  = open(filename, 0);
    if (fd < 0)
        return NULL;

    FILE *fptr = (FILE*) malloc(sizeof(FILE));
    fptr->write_buf = 0;
    fptr->fd = fd;

    return fptr;
}

size_t fwrite(const void *ptr, size_t size, size_t count, FILE *file)
{
    size_t left = size * count;
    const char *out = ptr;
    while (left--)
        fputc(*out++, file);

    return count;
}

size_t fread(void *ptr, size_t size, size_t nelem, FILE *f)
{
    int got = read(f->fd, ptr, size * nelem);
    if (got < 0)
        return 0;

    return got / size;
}

int fclose(FILE *f)
{
    int result = close(f->fd);
    free(f);
    return result;
}

off_t fseek(FILE *f, off_t offset, int whence)
{
    return lseek(f->fd, offset, whence);
}

off_t ftell(FILE *f)
{
    return lseek(f->fd, 0, SEEK_CUR);
}

int fprintf(FILE *f, const char *fmt, ...)
{
    va_list arglist;

    va_start(arglist, fmt);
    vfprintf(f, fmt, arglist);
    va_end(arglist);
    return 0;	// XXX
}

int fflush(FILE *file)
{
    (void) file;
    return 0;
}

int ferror(FILE *file)
{
    (void) file;
    return 0;	// XXX not implemented
}

int ungetc(int character, FILE *file)
{
    // XXX hack. Does not allow putting a different character back.
    lseek(file->fd, -1, SEEK_CUR);
    return character;
}
