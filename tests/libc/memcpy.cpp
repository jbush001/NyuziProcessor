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

#include <stdio.h>
#include <string.h>

#define DEST_FILL 0xcc

unsigned char source[512] __attribute__ ((aligned (64)));
unsigned char dest[512] __attribute__ ((aligned (64)));

int __attribute__ ((noinline)) memcpy_trial(int destOffset, int sourceOffset, int length)
{
    memset(dest, DEST_FILL, sizeof(dest));
    memcpy(dest + destOffset, source + sourceOffset, length);
    for (int i = 0; i < sizeof(dest); i++)
    {
        if (i >= destOffset && i < destOffset + length)
        {
            if (dest[i] != source[i - destOffset + sourceOffset])
            {
                printf("mismatch @%d (%d,%d,%d) %02x %02x\n", i, destOffset, sourceOffset, length,
                       dest[i], source[i - destOffset + sourceOffset]);
                return 0;
            }
        }
        else if (dest[i] != DEST_FILL)
        {
            printf("clobber @%d (%d,%d,%d) %02x\n", i, destOffset, sourceOffset, length,
                   dest[i]);
            return 0;
        }
    }

    return 1;
}

const int kOffsets[] = {
    0, 1, 2, 3, 4, 5, 6, 7, 8,
    62, 63, 64, 65, 66
};

const int kLengths[] = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17,
    31, 32, 33, 63, 64, 65, 127, 128, 129, 192
};

int main()
{
    for (int i = 0; i < sizeof(source); i++)
        source[i] = i ^ 0x67;

    for (auto sourceOffset : kOffsets)
    {
        for (auto destOffset : kOffsets)
        {
            for (auto length : kLengths)
            {
                if (!memcpy_trial(destOffset, sourceOffset, length))
                    goto done;
            }
        }
    }

    printf("PASS\n"); // CHECK: PASS

done:
    return 0;
}
