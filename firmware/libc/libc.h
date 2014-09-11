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

#define M_PI 3.1415

typedef unsigned int size_t;
typedef int veci16 __attribute__((__vector_size__(16 * sizeof(int))));
typedef unsigned int vecu16 __attribute__((__vector_size__(16 * sizeof(int))));
typedef float vecf16 __attribute__((__vector_size__(16 * sizeof(float))));

#ifdef __cplusplus
extern "C" {
#endif
	void *memcpy(void *dest, const void *src, size_t length);
	void *memset(void *dest, int value, size_t length);
	int strcmp(const char *str1, const char *str2);
	int strcasecmp(const char *str1, const char *str2);
	int strncasecmp(const char *str1, const char *str2, int length);
	unsigned long strlen(const char *str);
	char* strcpy(char *dest, const char *src);
	char* strncpy(char *dest, const char *src, int length);
	const char *strchr(const char *string, int c);
	char *strcat(char *c, const char *s);
	int isdigit(int c);
	int toupper(int val);
	int atoi(const char *num);
	int abs(int value);
	float fmod(float val1, float val2);
	float sin(float angle);
	float cos(float angle);
	float sqrt(float value);
	
#ifdef __cplusplus
}
#endif

#endif
