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

typedef struct __file FILE;

extern FILE *stdout;
extern FILE *stderr;

#ifdef __cplusplus
extern "C" {
#endif

void puts(const char *s);
void putchar(int ch);
int vfprintf(FILE *file, const char *format, va_list args);
int printf(const char *fmt, ...);
int sprintf(char *buf, const char *fmt, ...);
void fputc(int ch, FILE *file);
void fputs(const char *s, FILE *file);
size_t fwrite(const void *ptr, size_t size, size_t count, FILE *file);

#ifdef __cplusplus
}
#endif

#endif
