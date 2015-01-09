// 
// Copyright (C) 1998-2014 Jeff Bush
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

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include "__stdio_internal.h"

#define FLAG_IS_SET(x)	\
	((flags & (1 << (strchr(kFlagCharacters, x) - kFlagCharacters))) != 0)

#define SET_FLAG(x)	\
	flags |= 1 << (strchr(kFlagCharacters, x) - kFlagCharacters)

#define PREFIX_IS_SET(x)	\
	((prefixes & (1 << (strchr(kPrefixCharacters, x) - kPrefixCharacters))) != 0)

#define SET_PREFIX(x) \
	prefixes |= 1 << (strchr(kPrefixCharacters, x) - kPrefixCharacters)

#define MIN(x, y) ((x) < (y) ? (x) : (y))
#define MAX(x, y) ((x) > (y) ? (x) : (y))

const char *kHexDigits = "0123456789abcdef";
const char *kFlagCharacters = "-+ 0";
const char *kPrefixCharacters = "FNhlL";

/*
 *	 % flags width .precision prefix format
 */
int vfprintf(FILE *f, const char *format, va_list args)
{
	int flags = 0;
	int prefixes = 0;
	int width = 0;
	int precision = 0;
	
	enum {
		kScanText,
		kScanFlags,
		kScanWidth,
		kScanPrecision,
		kScanPrefix,
		kScanFormat
	} state = kScanText;

	while (*format) {
		switch (state) {
			case kScanText:
				if (*format == '%') {
					format++;
					state = kScanFlags;
					flags = 0;				/* reset attributes */
					prefixes = 0;
					width = 0;
					precision = 0;
				} else
					fputc(*format++, f);
				
				break;
				
			case kScanFlags: {
				const char *c;
				
				if (*format == '%') {
					fputc(*format++, f);
					state = kScanText;
					break;
				}
			
				c = strchr(kFlagCharacters, *format);
				if (c) {
					SET_FLAG(*format);
					format++;
				} else
					state = kScanWidth;
				
				break;
			}

			case kScanWidth:
				if (isdigit(*format))
					width = width * 10 + *format++ - '0';
				else if (*format == '.') {
					state = kScanPrecision;
					format++;
				} else
					state = kScanPrefix;
					
				break;
				
			case kScanPrecision:
				if (isdigit(*format))
					precision = precision * 10 + *format++ - '0';
				else
					state = kScanPrefix;
					
				break;
				
			case kScanPrefix: {
				const char *c = strchr(kPrefixCharacters, *format);
				if (c) {
					SET_PREFIX(*format);
					format++;
				} else
					state = kScanFormat;

				break;
			}

			case kScanFormat: {
				char temp_string[64];
				int index;
				char pad_char;
				int pad_count;
				int radix = 10;
			
				switch (*format) {
					case 'p':	/* pointer */
						width = 8;
						SET_FLAG('0');
						 
						/* falls through */

					case 'x':
					case 'X':	/* unsigned hex */
					case 'o':	/* octal */
					case 'u':	/* Unsigned decimal */
					case 'd':
					case 'i':	{ /* Signed decimal */
						unsigned int value;
						value = va_arg(args, unsigned);		/* long */

						/* figure out base */
						if (*format == 'o')
							radix = 8;
						else if (*format == 'x' || *format == 'X' || *format == 'p')
							radix = 16;
						else
							radix = 10;

						/* handle sign */
						if ((*format == 'd' || *format == 'i')) {
							if ((long) value < 0) {
								value = (unsigned) (- (long) value);
								fputc('-', f);
							}
						}

						/* write out the string backwards */
						index = 63;
						for (;;) {
							temp_string[index] = kHexDigits[value % radix];
							value /= radix;
							if (value == 0)
								break;
						
							if (index == 0)
								break;
								
							index--;
						}

						/* figure out width pad char */						
						if (FLAG_IS_SET('0'))
							pad_char = '0';
						else
							pad_char = ' ';

						/* write width padding */
						for (pad_count = (64 - index); pad_count < width; pad_count++)
							fputc(pad_char, f);
						
						/* write precision padding */
						for (; pad_count < precision; pad_count++)
							fputc('0', f);

						/* write the string */
						while (index < 64)
							fputc(temp_string[index++], f);
				
						break;
					}


					case 'c':	/* Single character */
						fputc(va_arg(args, int), f);
						break;
				
					case 's': {	/* string */
						int index = 0;
						int max_width;
						char *c = va_arg(args, char*);
						
						if (precision == 0)
							max_width = 0x7fffffff;
						else
							max_width = precision;

						for (index = 0; index < max_width && *c; index++)
							fputc(*c++, f);

						while (index < MIN(width, max_width)) {
							fputc(' ', f);
							index++;
						}

						break;
					}
					
					case 'f':
					case 'g':
					{
						// Printing floating point numbers accurately is a tricky problem.
						// This implementation is simple and buggy.
						// See "How to Print Floating Point Numbers Accurately" by Guy L. Steele Jr.
						// and Jon L. White for the gory details.
						// XXX does not handle inf and NaN
						float floatval = va_arg(args, float);
						int wholePart;
						float frac;

						if (floatval < 0.0f)
						{
							fputc('-', f);
							floatval = -floatval;
						}

						wholePart = (int) floatval;
						frac = floatval - wholePart;
		
						// Print the whole part (XXX ignores padding)
						if (wholePart == 0)
							fputc('0', f);
						else
						{
							char wholeStr[20];
							unsigned int wholeOffs = sizeof(wholeStr);
							while (wholePart > 0)
							{
								int digit = wholePart % 10;
								wholeStr[--wholeOffs] = digit + '0';
								wholePart /= 10;
							}

							while (wholeOffs < sizeof(wholeStr))
								fputc(wholeStr[wholeOffs++], f);
						}
		
						fputc('.', f);

						// Print the fractional part, not especially accurately
						int maxDigits = precision > 0 ? precision : 7;
						do
						{
							frac = frac * 10;	
							int digit = (int) frac;
							frac -= digit;
							fputc((digit + '0'), f);
						}
						while (frac > 0.0f && maxDigits-- > 0);
						
						break;
					}						
				}
				
				format++;
				state = kScanText;
				break;				
			}
		}
	}

	return 0;
}

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

FILE __stdout = { 
	.write_buf = NULL, 
	.write_offset = 0,
	.write_buf_len = 0 
};

FILE __stdin = {
	.write_buf = NULL, 
	.write_offset = 0,
	.write_buf_len = 0 
};

FILE *stdout = &__stdout;
FILE *stderr = &__stdout;
FILE *stdin = &__stdin;

void putchar(int ch)
{
	fputc(ch, stdout);
}

void puts(const char *s)
{
	for (const char *c = s; *c; c++)
		putchar(*c);

	putchar('\n');
}

volatile unsigned int * const REGISTERS = (volatile unsigned int*) 0xffff0000;

void fputc(int ch, FILE *file)
{
	if (file == stdout)
	{
		// Write to serial port
		while ((REGISTERS[6] & 1) == 0)
				;
		
		REGISTERS[8] = ch;	
	}
	else if (file->write_offset < file->write_buf_len)
		file->write_buf[file->write_offset++] = ch;
}

void fputs(const char *str, FILE *file)
{
	while (*str)
		fputc(*str++, file);
}

FILE *fopen(const char *filename, const char *mode)
{
	// XXX implement me
	return NULL;
}

size_t fwrite(const void *ptr, size_t size, size_t count, FILE *file)
{
	size_t left = size * count;
	const char *out = ptr;
	while (left--)
		fputc(*out++, file);
	
	return count;
}

size_t fread(void *ptr, size_t size, size_t nelem, FILE *stream)
{
	// XXX implement me
	return 0;
}

int fclose(FILE *stream)
{
	// XXX implement me
	return -1;
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
	return 0;
}

