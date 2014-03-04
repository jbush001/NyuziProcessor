// 
// Copyright 1998-2012 Jeff Bush
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

#include "cxx_runtime.h"

#define va_start(AP, LASTARG) __builtin_va_start(AP, LASTARG);
#define va_arg(AP, TYPE) __builtin_va_arg(AP, TYPE)
#define va_end(AP) __builtin_va_end(AP)
#define va_list __builtin_va_list

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
void my_vsnprintf(char *out, int size, const char *format, va_list args)
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

	while (*format && size > 0) {
		switch (state) {
			case kScanText:
				if (*format == '%') {
					format++;
					state = kScanFlags;
					flags = 0;				/* reset attributes */
					prefixes = 0;
					width = 0;
					precision = 0;
				} else {
					size--;
					*out++ = *format++;
				}
				
				break;
				
			case kScanFlags: {
				const char *c;
				
				if (*format == '%') {
					*out++ = *format++;
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
								if (size > 0) {
									size--;
									*out++ = '-';
								}
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

						/* figure out pad char */						
						if (FLAG_IS_SET('0'))
							pad_char = '0';
						else
							pad_char = ' ';

						/* write padding */						
						for (pad_count = width - (64 - index); pad_count > 0 && size > 0;
							pad_count--) {
							*out++ = pad_char;
							size--;
						}

						/* write the string */
						while (index < 64 && size > 0) {
							size--;
							*out++ = temp_string[index++];
						}
				
						break;
					}


					case 'c':	/* Single character */
						*out++ = va_arg(args, int);
						size--;
						break;
				
					case 's': {	/* string */
						int index = 0;
						int max_width;
						char *c = va_arg(args, char*);
						
						if (precision == 0)
							max_width = size;
						else
							max_width = MIN(precision, size);

						for (index = 0; index < max_width && *c; index++)
							*out++ = *c++;

						while (index < MIN(width, max_width)) {
							*out++ = ' ';
							index++;
						}

						size -= index;
						break;
					}
				}
				
				format++;
				state = kScanText;
				break;				
			}
		}
	}
	
	*out = 0;
}

void my_printf(const char *fmt, ...)
{
	va_list arglist;
	char temp[256];

	va_start(arglist, fmt);
	my_vsnprintf(temp, sizeof(temp) - 1, fmt, arglist);

	for (const char *c = temp; *c; c++)
		*((volatile unsigned int*) 0xFFFF0004) = *c;
}

int main()
{
	my_printf("The first number is 0x%08x, the second %d\n", 0x123, -112); 
	// CHECK: The first number is 0x00000123, the second -112

	my_printf("<%15s> %c%c%c%c\n", "abcd", 'w', 'x', 'y', 'z'); 
	// CHECK: <abcd           > wxyz

	my_printf("<%3.5s> <%3.5s>\n", "qwertyuiop", "q");
	// CHECK: <qwert> <q  >

	return 0;
}

