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
    union {
        float fval;
        int ival;
    } u;

    u.fval = value;
    printf("0x%08x\n", u.ival);
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

    // Unsigned 32-bit integer division
    printf("0x%08x\n", __udivsi3(346074795, 1918)); // CHECK: 0x0002c0d3
    printf("0x%08x\n", __udivsi3(0xabcdef12, 123)); // CHECK: 0x016593a2
    printf("0x%08x\n", __udivsi3(-226683378, 156)); // CHECK: 0x018dee17
    printf("0x%08x\n", __udivsi3(1024835, 1024835)); // CHECK: 0x00000001
    printf("0x%08x\n", __udivsi3(0xf1234567, 0xf1234567)); // CHECK: 0x00000001
    printf("0x%08x\n", __udivsi3(1071046619, -28)); // CHECK: 0x00000000
    printf("0x%08x\n", __udivsi3(-68861959, -758)); // CHECK: 0x00000000
    printf("0x%08x\n", __udivsi3(0, 521)); // CHECK: 0x00000000
    printf("0x%08x\n", __udivsi3(1785, 1729646273)); // CHECK: 0x00000000

    // Signed 32-bit integer division
    printf("0x%08x\n", __divsi3(786674736, 717)); // CHECK: 0x0010bdd7
    printf("0x%08x\n", __divsi3(-345606339, 1878)); // CHECK: 0xfffd3124
    printf("0x%08x\n", __divsi3(1858946429, -730)); // CHECK: 0xffd924bb
    printf("0x%08x\n", __divsi3(-1953179378, -27)); // CHECK: 0x044fd208
    printf("0x%08x\n", __divsi3(4594545, 4594545)); // CHECK: 0x00000001
    printf("0x%08x\n", __divsi3(-86739837, -86739837)); // CHECK: 0x00000001
    printf("0x%08x\n", __divsi3(0, 323)); // CHECK:  0x00000000
    printf("0x%08x\n", __divsi3(1976, 1560179702)); // CHECK:  0x00000000

    // Unsigned 32-bit integer modulus
    printf("0x%08x\n", __umodsi3(2099458709, 405)); // CHECK: 0x0000010d
    printf("0x%08x\n", __umodsi3(-1162139226, 133)); // CHECK: 0x00000024
    printf("0x%08x\n", __umodsi3(1404646660, -1354)); // CHECK: 0x53b93504
    printf("0x%08x\n", __umodsi3(-408733536, -674)); // CHECK: 0xe7a338a0
    printf("0x%08x\n", __umodsi3(0, 558)); // CHECK: 0x00000000
    printf("0x%08x\n", __umodsi3(1241, 642786273)); // CHECK: 0x000004d9

    // Signed 32-bit integer modulus
    printf("0x%08x\n", __modsi3(1352682325, 1431)); // CHECK: 0x000003bb
    printf("0x%08x\n", __modsi3(-637601430, 519)); // CHECK: 0xffffffbb
    printf("0x%08x\n", __modsi3(707539755, -919)); // CHECK: 0x000002e0
    printf("0x%08x\n", __modsi3(-1961166402, -1727)); // CHECK: 0xfffffd17
    printf("0x%08x\n", __modsi3(0, 757)); // CHECK: 0x00000000
    printf("0x%08x\n", __modsi3(1602, 665793497)); // CHECK: 0x00000642

    // Unsigned 64-bit integer division
    print64bit(__udivdi3(1050274330405180738LL, 797716LL)); // CHECK: 0x000001328b9550e9
    print64bit(__udivdi3(-4832816989400093653LL, 890412LL)); // CHECK: 0x00000de7db656d71
    print64bit(__udivdi3(1660101866605002714LL, -469277LL)); // CHECK: 0x0000000000000000
    print64bit(__udivdi3(-7017441335104154666LL, -671304LL)); // CHECK: 0x0000000000000000
    print64bit(__udivdi3(0, 671304LL)); // CHECK: 0x0000000000000000
    print64bit(__udivdi3(70319496, 1375068975430532LL)); // CHECK: 0x0000000000000000

    // Signed 64-bit integer division
    print64bit(__divdi3(21338495617053079LL, 639740LL)); // CHECK: 0x00000007c41c24da
    print64bit(__divdi3(-857072669283774717LL, 304846LL)); // CHECK: 0xfffffd7165e7a31f
    print64bit(__divdi3(9059441666292382320LL, -585119LL)); // CHECK: 0xfffff1eb10c8929f
    print64bit(__divdi3(-7933985095683411602LL, -179202LL)); // CHECK: 0x0000284456a0dfe3
    print64bit(__divdi3(0, 1209767421)); // CHECK: 0x0000000000000000
    print64bit(__divdi3(57052310, 1847170292623517LL)); // CHECK: 0x0000000000000000

    // Unsigned 64-bit integer modulus
    print64bit(__umoddi3(6035781528534459146LL, 830074LL)); // CHECK: 0x000000000003f2b2
    print64bit(__umoddi3(-881747499106622710LL, 377151LL)); // CHECK: 0x000000000002a354
    print64bit(__umoddi3(0x1235LL, 0xffffffffffffffffLL)); // CHECK: 0x0000000000001235
    print64bit(__umoddi3(0x8000000000000495LL, 0xffffffffffffffffLL)); // CHECK: 0x8000000000000495
    print64bit(__umoddi3(0LL, 1591700594LL)); // CHECK: 0x0000000000000000
    print64bit(__umoddi3(63883059LL, 692653866775409LL)); // CHECK: 0x0000000003cec733

    // Signed 64-bit integer modulus
    print64bit(__moddi3(2920820417930110757LL, 645766LL)); // CHECK: 0x0000000000051bc7
    print64bit(__moddi3(-6524524390609748054LL, 971521LL)); // CHECK: 0xfffffffffff2abb4
    print64bit(__moddi3(146552385095549494LL, -153866LL)); // CHECK: 0x0000000000006dfe
    print64bit(__moddi3(-4706584128254147473LL, -927318LL)); // CHECK: 0xfffffffffff510db
    print64bit(__moddi3(0LL, 255750984LL)); // CHECK: 0x0000000000000000
    print64bit(__moddi3(60227507LL, 1437590093692635LL)); // CHECK: 0x000000000396ffb3

    // Convert 64 bit value to float, greater than > 32 bits
    printfloathex(__floatundisf(1674874919848732277LL));
    // CHECK: 0x5db9f2cf

    // < 32 bits
    printfloathex(__floatundisf(1674877LL));
    // CHECK: 0x49cc73e8
}
