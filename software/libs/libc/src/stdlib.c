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

#include <ctype.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>

static int randseed = -1;

int __errno_array[__MAX_THREADS];

void abort(void)
{
    puts("abort");
    __builtin_trap();
}

int abs(int value)
{
    if (value < 0)
        return -value;

    return value;
}

// XXX bug: doesn't handle negative numbers
int atoi(const char *num)
{
    int value = 0;
    while (*num && isdigit(*num))
        value = value * 10 + *num++  - '0';

    return value;
}

int rand(void)
{
    randseed = randseed * 1103515245 + 12345;
    return randseed & 0x7fffffff;
}

void srand(unsigned int seed)
{
    randseed = seed;
}

void* bsearch(const void *searchKey, const void *base, size_t num,
              size_t size, int (*compare)(const void*,const void*))
{
    int low = 0;
    int high = num - 1;
    while (low <= high)
    {
        int mid = (low + high) / 2;
        void *midKey = (char*) base + mid * size;
        int compVal = (*compare)(searchKey, midKey);
        if (compVal == 0)
            return midKey;
        else if (compVal < 0)
            high = mid - 1;
        else
            low = mid + 1;
    }

    return NULL;
}



