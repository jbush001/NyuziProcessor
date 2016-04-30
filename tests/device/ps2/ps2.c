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
#include <stdlib.h>
#include <unistd.h>

static volatile unsigned int * const REGISTERS = (volatile unsigned int*) 0xffff0000;

unsigned int wait_keypress()
{
    int timeout = 5000;
    while (REGISTERS[0x80 / 4] == 0 && timeout-- > 0)
        ;

    if (timeout == 0)
    {
        printf("FAIL: Timeout waiting for keyboard character\n");
        exit(1);
    }

    return REGISTERS[0x84 / 4];
}

int main()
{
    unsigned int start_value;
    unsigned int scancode;

    for (unsigned int i = 0; i < 20; i++)
    {
        scancode = wait_keypress();
        printf("%02x\n", scancode);
        if (scancode != i)
        {
            printf("FAIL: mismatch: want %02x got %02x", i, scancode);
            exit(1);
        }
    }

    printf("overrun...\n");
    // Test overrun
    usleep(5000);

    // Ensure the oldest characters are dropped
    start_value = wait_keypress();
    printf("%02x\n", start_value);
    for (unsigned int i = 1; i < 20; i++)
    {
        scancode = wait_keypress();
        printf("%02x\n", scancode);
        if (scancode != i + start_value)
        {
            printf("FAIL: mismatch: want %02x got %02x", i + start_value, scancode);
            exit(1);
        }
    }

    printf("PASS\n");

    return 0;
}
