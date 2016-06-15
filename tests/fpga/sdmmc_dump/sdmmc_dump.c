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
#include <sdmmc.h>

#define TRANSFER_LENGTH 8

//
// Read the first few sectors of the SD card and dump them out the
// serial port. This uses the SPI mode driver in libos.
// ***This is not yet functional***.  I'm still debugging issues with
// it. The define BITBANG_SDMMC must be disabled in hardware/fpga/de2-115/de2_115_top.sv
// for this to be operational.
//

int main()
{
    int result;

    result = init_sdmmc_device();
    if (result < 0)
    {
        printf("error %d initializing card\n", result);
        return 0;
    }

    for (int block_num = 0; block_num < TRANSFER_LENGTH; block_num++)
    {
        unsigned char buf[512];
        result = read_sdmmc_device(block_num, buf);
        if (result < 0)
        {
            printf("error %d reading from device\n", result);
            break;
        }

        for (int address = 0; address < BLOCK_SIZE; address += 16)
        {
            printf("%08x ", address + block_num * BLOCK_SIZE);
            for (int offset = 0; offset < 16; offset++)
                printf("%02x ", buf[address + offset]);

            printf("  ");
            for (int offset = 0; offset < 16; offset++)
            {
                unsigned char c = buf[address + offset];
                if (c >= 32 && c <= 128)
                    printf("%c ", c);
                else
                    printf(".");
            }

            printf("\n");
        }

        printf("\n");
    }

    return 0;
}
