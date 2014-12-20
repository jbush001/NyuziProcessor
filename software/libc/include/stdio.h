// 
// Copyright (C) 2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 

#ifndef __STDIO_H
#define __STDIO_H

#include <stdarg.h>
#include <stddef.h>

#define EOF -1

typedef struct __file FILE;

extern FILE *stdout;
extern FILE *stdin;
extern FILE *stderr;

#ifdef __cplusplus
extern "C" {
#endif

void puts(const char *s);
void putchar(int ch);
int vfprintf(FILE *file, const char *format, va_list args);
int printf(const char *fmt, ...);
int sprintf(char *buf, const char *fmt, ...);
int snprintf(char *buf, size_t size, const char *fmt, ...);
void fputc(int ch, FILE *file);
void fputs(const char *s, FILE *file);
int fflush(FILE *file);
FILE *fopen(const char *filename, const char *mode);
size_t fread(void *ptr, size_t size, size_t nelem, FILE *stream);
size_t fwrite(const void *ptr, size_t size, size_t nelem, FILE *stream);
int fclose(FILE *stream);

#ifdef __cplusplus
}
#endif

#endif
