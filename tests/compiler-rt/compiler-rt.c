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

void print64bit(long long int value)
{
    unsigned char tmp[8];
    int i;

    memcpy(tmp, &value, 8);
    printf("0x");
    for (i = 7; i >= 0; i--)
        printf("%02x", tmp[i]);

    printf("\n");
}

void printfloathex(float value)
{
    printf("0x%08x\n", *((int*) &value));
}

long long int __ashldi3(long long int value, int shamt);
long long int __lshrdi3(long long int value, int shamt);
unsigned long long int __udivdi3(unsigned long long int dividend,
                                 unsigned long long int divisor);
long long int __divdi3(long long int value1, long long int value2);
unsigned long long int __umoddi3(unsigned long long int dividend,
                                 unsigned long long int divisor);
long long int __moddi3(long long int value1, long long int value2);
float __floatundisf(long long int a);

int main()
{
    // Shift left 64 bits, less than 32 bit shift, unsigned value
    print64bit(__ashldi3(0x1257493827394374LL, 3));
    // CHECK: 0x92ba49c139ca1ba0

    // Shift left 64 bits, more than 32 bit shift, unsigned value
    print64bit(__ashldi3(0x1257493827394374LL, 34));
    // CHECK: 0x9ce50dd000000000

    // Logical shift right 64 bits, less than 32 bit shift, unsigned value
    print64bit(__lshrdi3(0x1d348856d51c4737LL, 7));
    // CHECK: 0x003a6910adaa388e

    // Signed value
    print64bit(__lshrdi3(0xfd348856d51c4737LL, 7));
    // CHECK: 0x01fa6910adaa388e

    // Logical shift right 64 bits, more than 32 bit shift, unsigned value
    print64bit(__lshrdi3(0x1d348856d51c4737LL, 37));
    // CHECK: 0x0000000000e9a442

    // Signed value
    print64bit(__lshrdi3(0xfd348856d51c4737LL, 37));
    // CHECK: 0x0000000007e9a442

    // Unsigned 32 bit integer division, signed value
    printf("0x%08x\n", __udivsi3(0xf39eca1b, 17));
    // CHECK: 0x0e54a27a

    // Unsigned value
    printf("0x%08x\n", __udivsi3(0x5b0a6c63, 17));
    // CHECK: 0x055af751

    // Signed 32 bit integer division, signed value
    printf("0x%08x\n", __divsi3(0xf39eca1b, 17));
    // CHECK: 0xff45936b

    // Unsigned value
    printf("0x%08x\n", __divsi3(0x539eca1b, 17));
    // CHECK: 0x04eb3910

    // Unsigned 32 bit integer modulus, signed value
    printf("0x%08x\n", __umodsi3(0xf39eca1b, 495));
    // CHECK: 0x000001d1

    // Unsigned value
    printf("0x%08x\n", __umodsi3(0x539eca1b, 495));
    // CHECK: 0x000000d7

    // Signed 32 bit integer modulus, signed value
    printf("0x%08x\n", __modsi3(0xf39eca1b, 495));
    // CHECK: 0xfffffeb5

    // Unsigned value
    printf("0x%08x\n", __modsi3(0x539eca1b, 495));
    // CHECK: 0x000000d7

    // Unsigned 64 bit integer division, signed value
    print64bit(__udivdi3(0xf3c367523e29230aLL, 495));
    // CHECK: 0x007e114680625881

    // Unsigned value
    print64bit(__udivdi3(0x53c367523e29230aLL, 495));
    // CHECK: 0x002b51ebff175b17

    // Signed 64 bit integer division, signed value
    print64bit(__divdi3(0xf3c367523e29230aLL, 495));
    // CHECK: 0xfff9abe8e4b72972

    // Unsigned value
    print64bit(__divdi3(0x53c367523e29230aLL, 495));
    // CHECK: 0x002b51ebff175b17

    // Unsigned 64 bit integer modulus, signed value
    print64bit(__umoddi3(0xf3c367523e29230aLL, 495));
    // CHECK: 0x000000000000019b

    // Unsigned value
    print64bit(__umoddi3(0x53c367523e29230aLL, 495));
    // CHECK: 0x0000000000000191

    // Signed 64 bit integer modulus, signed value
    print64bit(__moddi3(0xf3c367523e29230aLL, 495));
    // CHECK: 0xffffffffffffff9c

    // Unsigned value
    print64bit(__moddi3(0x53c367523e29230aLL, 495));
    // CHECK: 0x0000000000000191

    // Convert 64 bit value to float, greater than > 32 bits
    printfloathex(__floatundisf(1674874919848732277LL));
    // CHECK: 0x5db9f2cf

    // < 32 bits
    printfloathex(__floatundisf(1674877LL));
    // CHECK: 0x49cc73e8
}
