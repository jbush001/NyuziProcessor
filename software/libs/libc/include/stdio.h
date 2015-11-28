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

#include <stdarg.h>
#include <stddef.h>

#define FILENAME_MAX 32
#define BUFSIZ 256

#define EOF -1

#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2

typedef struct __file FILE;
typedef int off_t;

extern FILE *stdout;
extern FILE *stdin;
extern FILE *stderr;

#ifdef __cplusplus
extern "C" {
#endif

int puts(const char *s);
int putchar(int ch);
int vfprintf(FILE*, const char *format, va_list args);
int printf(const char *fmt, ...);
int fprintf(FILE*, const char *fmt, ...);
int sprintf(char *buf, const char *fmt, ...);
int snprintf(char *buf, size_t size, const char *fmt, ...);
int vsnprintf(char *buf, size_t size, const char *fmt, va_list args);
int fputc(int ch, FILE*);
int fputs(const char *s, FILE*);
int fgetc(FILE*);
int fflush(FILE*);
FILE *fopen(const char *filename, const char *mode);
size_t fread(void *ptr, size_t size, size_t nelem, FILE *stream);
size_t fwrite(const void *ptr, size_t size, size_t nelem, FILE *stream);
int fclose(FILE*);
off_t fseek(FILE*, off_t offset, int whence);
off_t ftell(FILE*);
int ferror(FILE*);
int ungetc(int character, FILE*);

#ifdef __cplusplus
}
#endif
