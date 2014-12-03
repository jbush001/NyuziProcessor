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

#ifndef __STDLIB_H
#define __STDLIB_H

#include <stddef.h>

typedef int (*cmpfun)(const void *, const void *);

#ifdef __cplusplus
extern "C" {
#endif

void *calloc(size_t size, size_t numElements);
void *malloc(size_t size);
void *memalign(size_t size, size_t align);
void *realloc(void* oldmem, size_t bytes);
void free(void*);

void abort(void) __attribute__((noreturn));
void exit(int status) __attribute__((noreturn));
void qsort(void *base, size_t nel, size_t width, cmpfun cmp);
int atoi(const char *num);
int abs(int value);

#ifdef __cplusplus
}
#endif

#endif
