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


#pragma once

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
int rand(void);

#ifdef __cplusplus
}
#endif
