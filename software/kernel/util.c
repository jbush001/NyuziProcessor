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
    int wordindex;

    for (wordindex = 0; wordindex < num_bits; wordindex += 32)
    {
        if (array[wordindex] != 0xffffffff)
        {
            // Search this word for the first zero bit. Inverting the bitmap
            // allows us to scan for this, since there is no
            // count-trailing-ones.
            bitindex = __builtin_ctz(~array[wordindex]);
            array[wordindex] |= 1 << bitindex;
            return wordindex * 32 + bitindex;
        }
    }

    return -1;
}

void bitmap_free(unsigned int *array, int index)
{
    array[index / 32] &= ~(0x80000000 >> (index % 32));
}

