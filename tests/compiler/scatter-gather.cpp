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
#include <stdio.h>

volatile unsigned int glob_array[16];

int main()
{
    veci16_t values1 =   {  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15 };
    veci16_t values2 =   { 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45 };
    veci16_t pointers = {   0,  3, 13, 15, 12, 10,  7,  1,  5, 11,  9, 14,  6,  2,  4,  8 };
    veci16_t gathered_ptrs1;
    veci16_t gathered_ptrs2;
    pointers <<= 2;
    pointers += int(&glob_array);

    __builtin_nyuzi_scatter_storei(pointers, values1);
    for (int i = 0; i < 16; i++)
        printf("%d ", glob_array[i]);

    // CHECK: 0 7 13 1 14 8 12 6 15 10 5 9 4 2 11 3

    __builtin_nyuzi_scatter_storei_masked(pointers, values2, 0xaaaa);
    for (int i = 0; i < 16; i++)
        printf("%d ", glob_array[i]);

    // CHECK: 0 37 43 31 14 8 12 6 45 10 35 39 4 2 41 33

    printf("\n");
    gathered_ptrs1 = __builtin_nyuzi_gather_loadi(pointers);
    for (int i = 0; i < 16; i++)
        printf("%d ", gathered_ptrs1[i]);

    // CHECK: 0 31 2 33 4 35 6 37 8 39 10 41 12 43 14 45

    printf("\n");
    gathered_ptrs2 = __builtin_nyuzi_gather_loadi_masked(pointers, 0xffff);
    for (int i = 0; i < 16; i++)
        printf("%d ", gathered_ptrs2[i]);

    // CHECK: 0 31 2 33 4 35 6 37 8 39 10 41 12 43 14 45
}
