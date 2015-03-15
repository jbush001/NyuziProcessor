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

#ifdef __cplusplus
extern "C" {
#endif

void *memcpy(void *dest, const void *src, size_t length);
void *memset(void *dest, int value, size_t length);
int strcmp(const char *str1, const char *str2);
int memcmp(const void *a, const void *b, size_t length);
int strcasecmp(const char *str1, const char *str2);
int strncasecmp(const char *str1, const char *str2, size_t length);
size_t strlen(const char *str);
char* strcpy(char *dest, const char *src);
char* strncpy(char *dest, const char *src, size_t length);
char *strchr(const char *string, int c);
char *strcat(char *c, const char *s);

#ifdef __cplusplus
}
#endif

