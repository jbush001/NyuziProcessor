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

#include <stdint.h>

typedef int _veci16_t __attribute__((__vector_size__(16 * sizeof(int))));

void* memset(void *_dest, int value, unsigned int length)
{
    char *dest = (char*) _dest;
    value &= 0xff;

    // XXX Possibly fill bytes/words until alignment is hit

    if ((((unsigned int) dest) & 63) == 0)
    {
        // Write 64 bytes at a time.
        _veci16_t reallyWideValue = (veci16_t)(value | (value << 8) | (value << 16)
                                    | (value << 24));
        while (length > 64)
        {
            *((_veci16_t*) dest) = reallyWideValue;
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
