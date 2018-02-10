//
// Copyright 2018 Jeff Bush
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

#include "util.h"

int bitmap_alloc(unsigned int *array, int num_bits)
{
    int bitindex;
    int wordindex = 0;

    // Scan whole words at a time looking for a non-zero index
    while (array[wordindex] == 0xffffffff)
    {
        if (++wordindex == num_bits / 32)
            return -1;
    }

    // Search this word for the first zero bit. Inverting the bitmap
    // allows us to scan for this, since there is no
    // count-trailing-ones.
    bitindex = __builtin_clz(~array[wordindex]);
    array[wordindex] |= 0x80000000 >> bitindex;
    return wordindex * 32 + bitindex;
}

void bitmap_free(unsigned int *array, int index)
{
    array[index / 32] &= ~(0x80000000 >> (index % 32));
}

#ifdef TEST_BITMAP_ALLOC

#define NUM_TEST_BITS 128

void test_bitmap()
{
    unsigned int bitmap[NUM_TEST_BITS / 32];
    int index;

    memset(bitmap, 0, sizeof(bitmap));

    for (index = 0; index < NUM_TEST_BITS; index++)
        assert(bitmap_alloc(bitmap, NUM_TEST_BITS) == index);

    assert(bitmap_alloc(bitmap, NUM_TEST_BITS) == -1);

    for (index = 0; index < NUM_TEST_BITS; index += 3)
        bitmap_free(bitmap, index);

    for (index = 0; index < NUM_TEST_BITS; index += 3)
        assert(bitmap_alloc(bitmap, NUM_TEST_BITS) == index);

    kprintf("bitmap tests passed\n");
}

#endif
