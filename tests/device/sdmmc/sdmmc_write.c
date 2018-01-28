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

#include <stdio.h>
#include <bare-metal/sdmmc.h>

int main()
{
    unsigned char buf1[SDMMC_BLOCK_SIZE];
    unsigned char buf2[SDMMC_BLOCK_SIZE];
    unsigned int i;

    if (init_sdmmc_device() < 0)
    {
        printf("error initializing card\n");
        return -1;
    }

    // write a block
    for (i = 0; i < SDMMC_BLOCK_SIZE; i++)
        buf1[i] = (i ^ (i >> 3)) & 0xff;

    write_sdmmc_device(1, buf1);

    // read it back
    read_sdmmc_device(1, buf2);
    for (i = 0; i < SDMMC_BLOCK_SIZE; i++)
    {
        if (buf2[i] != ((i ^ (i >> 3)) & 0xff))
        {
            printf("FAIL: readback mismatch at offset %d, expected %02x got %02x\n",
                i, (i ^ (i >> 3)) & 0xff, buf2[i]);
            break;
        }
    }

    return 0;
}
