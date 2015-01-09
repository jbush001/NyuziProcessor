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

#include <ctype.h>
#include <string.h>
#include <stddef.h>
#include <stdint.h>

void* memset(void *_dest, int value, size_t length)
{
	char *dest = (char*) _dest;
	value &= 0xff;

	// XXX Possibly fill bytes/words until alignment is hit

	if ((((unsigned int) dest) & 63) == 0)
	{
		// Write 64 bytes at a time.
		veci16_t reallyWideValue = __builtin_nyuzi_makevectori(value | (value << 8) | (value << 16) 
			| (value << 24));
		while (length > 64)
		{
			*((veci16_t*) dest) = reallyWideValue;
			length -= 64;
			dest += 64;
		}
	}

	if ((((unsigned int) dest) & 3) == 0)
	{
		// Write 4 bytes at a time.
		unsigned wideVal = value | (value << 8) | (value << 16) | (value << 24);
		while (length > 4)
		{
			*((unsigned int*) dest) = wideVal;
			dest += 4;
			length -= 4;
		}		
	}

	// Write one byte at a time
	while (length > 0)
	{
		*dest++ = value;
		length--;
	}
	
	return _dest;
}

int strcmp(const char *str1, const char *str2)
{
	while (*str1 && *str2 && *str1 == *str2)
	{
		str1++;
		str2++;
	}

	return *str1 - *str2;
}

int strcasecmp(const char *str1, const char *str2)
{
	while (*str1 && *str2 && toupper(*str1) == toupper(*str2))
	{
		str1++;
		str2++;
	}

	return toupper(*str1) - toupper(*str2);
}

int strncasecmp(const char *str1, const char *str2, size_t length)
{
	if (length-- == 0)
		return 0;
	
	while (*str1 && *str2 && length && toupper(*str1) == toupper(*str2))
	{
		str1++;
		str2++;
		length--;
	}

	return toupper(*str1) - toupper(*str2);
}

size_t strlen(const char *str)
{
	long len = 0;
	while (*str++)
		len++;

	return len;
}

char* strcpy(char *dest, const char *src)
{
	char *d = dest;
	while (*src)
		*d++ = *src++;

	*d = 0;
	return dest;
}

char* strncpy(char *dest, const char *src, size_t length)
{
	char *d = dest;
	while (*src && length-- > 0)
		*d++ = *src++;

	*d = 0;
	return dest;
}

char *strchr(const char *string, int c)
{
	for (const char *s = string; *s; s++)
		if (*s == c)
			return (char*) s;

	return 0;
}

char *strcat(char *c, const char *s)
{
	char *ret = c;
	while (*c)
		c++;
	
	while (*s)
		*c++ = *s++;
	
	*c = '\0';
	return ret;
}

int isdigit(int c)
{
	if (c >= '0' && c <= '9')
		return 1;
	
	return 0;
}

int toupper(int val)
{
	if (val >= 'a' && val <= 'z')
		return val - ('a' - 'A');
	
	return val;
}

int atoi(const char *num)
{
	int value = 0;
	while (*num && isdigit(*num))
		value = value * 10 + *num++  - '0';

	return value;
}
