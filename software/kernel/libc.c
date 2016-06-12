//
// Copyright 2011-2016 Jeff Bush
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

#include "libc.h"

#define va_start(AP, LASTARG) __builtin_va_start(AP, LASTARG);
#define va_arg(AP, TYPE) __builtin_va_arg(AP, TYPE)
#define va_end(AP) __builtin_va_end(AP)
#define va_list __builtin_va_list

extern void putc(int c);

int isdigit(int c)
{
    if (c >= '0' && c <= '9')
        return 1;

    return 0;
}

void *memchr(const void *_s, int c, unsigned int n)
{
    const char *s = (const char*) _s;

    for (unsigned int i = 0; i < n; i++)
    {
        if (s[i] == c)
            return (void*) &s[i];
    }

    return 0;
}

int strcmp(const char *str1, const char *str2)
{
    while (*str1 && *str1 == *str2)
    {
        str1++;
        str2++;
    }

    return *str1 - *str2;
}

char *strchr(const char *string, int c)
{
    for (const char *s = string; *s; s++)
        if (*s == c)
            return (char*) s;

    return 0;
}

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

static const char *kHexDigits = "0123456789abcdef";
static const char *kFlagCharacters = "-+ 0";
static const char *kPrefixCharacters = "FNhlL";

static int vprintf(const char *format, va_list args)
{
    int flags = 0;
    int prefixes = 0;
    int width = 0;
    int precision = 0;

    enum
    {
        kScanText,
        kScanFlags,
        kScanWidth,
        kScanPrecision,
        kScanPrefix,
        kScanFormat
    } state = kScanText;

    while (*format)
    {
        switch (state)
        {
            case kScanText:
                if (*format == '%')
                {
                    format++;
                    state = kScanFlags;
                    flags = 0;				/* reset attributes */
                    prefixes = 0;
                    width = 0;
                    precision = 0;
                }
                else
                    putc(*format++);

                break;

            case kScanFlags:
            {
                const char *c;

                if (*format == '%')
                {
                    putc(*format++);
                    state = kScanText;
                    break;
                }

                c = strchr(kFlagCharacters, *format);
                if (c)
                {
                    SET_FLAG(*format);
                    format++;
                }
                else
                    state = kScanWidth;

                break;
            }

            case kScanWidth:
                if (isdigit(*format))
                    width = width * 10 + *format++ - '0';
                else if (*format == '.')
                {
                    state = kScanPrecision;
                    format++;
                }
                else
                    state = kScanPrefix;

                break;

            case kScanPrecision:
                if (isdigit(*format))
                    precision = precision * 10 + *format++ - '0';
                else
                    state = kScanPrefix;

                break;

            case kScanPrefix:
            {
                const char *c = strchr(kPrefixCharacters, *format);
                if (c)
                {
                    SET_PREFIX(*format);
                    format++;
                }
                else
                    state = kScanFormat;

                break;
            }

            case kScanFormat:
            {
                char temp_string[64];
                int index;
                char pad_char;
                int pad_count;
                int radix = 10;

                switch (*format)
                {
                    case 'p':	/* pointer */
                        width = 8;
                        SET_FLAG('0');

                    /* falls through */

                    case 'x':
                    case 'X':	/* unsigned hex */
                    case 'o':	/* octal */
                    case 'u':	/* Unsigned decimal */
                    case 'd':
                    case 'i':	  /* Signed decimal */
                    {
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
                        if ((*format == 'd' || *format == 'i'))
                        {
                            if ((long) value < 0)
                            {
                                value = (unsigned) (- (long) value);
                                putc('-');
                            }
                        }

                        /* write out the string backwards */
                        index = 63;
                        for (;;)
                        {
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
                            putc(pad_char);

                        /* write precision padding */
                        for (; pad_count < precision; pad_count++)
                            putc('0');

                        /* write the string */
                        while (index < 64)
                            putc(temp_string[index++]);

                        break;
                    }


                    case 'c':	/* Single character */
                        putc(va_arg(args, int));
                        break;

                    case 's':  	/* string */
                    {
                        int max_width;
                        char *c = va_arg(args, char*);

                        if (precision == 0)
                            max_width = 0x7fffffff;
                        else
                            max_width = precision;

                        for (index = 0; index < max_width && *c; index++)
                            putc(*c++);

                        while (index < MIN(width, max_width))
                        {
                            putc(' ');
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
                        float floatval = va_arg(args, double);
                        int wholePart;
                        float frac;

                        if (floatval < 0.0f)
                        {
                            putc('-');
                            floatval = -floatval;
                        }

                        wholePart = (int) floatval;
                        frac = floatval - wholePart;

                        // Print the whole part (XXX ignores padding)
                        if (wholePart == 0)
                            putc('0');
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
                                putc(wholeStr[wholeOffs++]);
                        }

                        putc('.');

                        // Print the fractional part, not especially accurately
                        int maxDigits = precision > 0 ? precision : 7;
                        do
                        {
                            frac = frac * 10;
                            int digit = (int) frac;
                            frac -= digit;
                            putc(digit + '0');
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

int kprintf(const char *format, ...)
{
    va_list args;
    int result;

    va_start(args, format);
    result = vprintf(format, args);
    va_end(args);

    return result;
}

void putchar(int c)
{
    putc(c);
}

void puts(const char *s)
{
    for (const char *c = s; *c; c++)
        putc(*c);

    putc('\n');
}

void panic(const char *format, ...)
{
    va_list args;

    kprintf("KERNEL PANIC: ");

    va_start(args, format);
    vprintf(format, args);
    va_end(args);

    putchar('\n');

    *((volatile unsigned int*) 0xffff0104) = 0xffffffff;

    while (1);
}

void* memset(void *_dest, int value, unsigned int length)
{
    char *dest = (char*) _dest;
    value &= 0xff;

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

void *memcpy(void *_dest, const void *_src, unsigned int length)
{
    char *dest = _dest;
    const char *src = _src;

    while (length-- > 0)
        *dest++ = *src++;

    return _dest;
}

unsigned int strlcpy(char *dest, const char *src, unsigned int length)
{
    char *d = dest;
    while (*src && length-- > 0)
        *d++ = *src++;

    *d = 0;
    return d - src;
}

int memcmp(const void *_str1, const void *_str2, unsigned int len)
{
    const char *str1 = _str1;
    const char *str2 = _str2;

    while (len--)
    {
        int diff = *str1++ - *str2++;
        if (diff)
            return diff;
    }

    return 0;
}
