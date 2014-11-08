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

#ifndef __LIBC_H
#define __LIBC_H

typedef struct __file FILE;

#define NULL 0

#define M_PI 3.1415

#define va_start(AP, LASTARG) __builtin_va_start(AP, LASTARG);
#define va_arg(AP, TYPE) __builtin_va_arg(AP, TYPE)
#define va_end(AP) __builtin_va_end(AP)
#define va_list __builtin_va_list

#define ENOMEM -2
#define EINVAL -3

typedef unsigned int size_t;
typedef int veci16 __attribute__((__vector_size__(16 * sizeof(int))));
typedef unsigned int vecu16 __attribute__((__vector_size__(16 * sizeof(int))));
typedef float vecf16 __attribute__((__vector_size__(16 * sizeof(float))));
typedef int ptrdiff_t;

extern FILE *stdout;
extern FILE *stderr;

#ifdef __cplusplus
extern "C" {
#endif
	void *memcpy(void *dest, const void *src, size_t length);
	void *memset(void *dest, int value, size_t length);
	int strcmp(const char *str1, const char *str2);
	int strcasecmp(const char *str1, const char *str2);
	int strncasecmp(const char *str1, const char *str2, size_t length);
	size_t strlen(const char *str);
	char* strcpy(char *dest, const char *src);
	char* strncpy(char *dest, const char *src, size_t length);
	char *strchr(const char *string, int c);
	char *strcat(char *c, const char *s);
	int isdigit(int c);
	int toupper(int val);
	int atoi(const char *num);
	int abs(int value);
	double fmod(double val1, double val2);
	double sin(double angle);
	double cos(double angle);
	double sqrt(double value);
	void puts(const char *s);
	void *calloc(size_t size, size_t numElements);
	void *malloc(size_t size);
	void free(void*);
	void *memalign(size_t size, size_t align);
	void *realloc(void* oldmem, size_t bytes);
	void abort(void) __attribute__((noreturn));
	void exit(int status) __attribute__((noreturn));

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

#define assert(cond) if (!(cond)) { printf("ASSERT FAILED: %s:%d: %s", __FILE__, __LINE__, \
	#cond); abort(); }


#endif
