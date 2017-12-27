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

volatile unsigned int glob_iarray[16];
volatile float glob_farray[16];

int main()
{
    veci16_t ipointers = {  0,  3, 13, 15, 12, 10,  7,  1,  5, 11,  9, 14,  6,  2,  4,  8 };
    ipointers <<= 2;
    ipointers += int(&glob_iarray);

    veci16_t fpointers = {  0,  3, 13, 15, 12, 10,  7,  1,  5, 11,  9, 14,  6,  2,  4,  8 };
    fpointers <<= 2;
    fpointers += int(&glob_farray);

    veci16_t ivalues1 = {   0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15 };
    __builtin_nyuzi_scatter_storei(ipointers, ivalues1);
    for (int i = 0; i < 16; i++)
        printf("%d ", glob_iarray[i]);
    // CHECK: 0 7 13 1 14 8 12 6 15 10 5 9 4 2 11 3

    vecf16_t fvalues1 = {   0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15 };
    __builtin_nyuzi_scatter_storef(fpointers, fvalues1);
    for (int i = 0; i < 16; i++)
        printf("%g ", glob_farray[i]);
    // CHECK: 0.0 7.0 13.0 1.0 14.0 8.0 12.0 6.0 15.0 10.0 5.0 9.0 4.0 2.0 11.0 3.0

    veci16_t ivalues2 = {  30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45 };
    __builtin_nyuzi_scatter_storei_masked(ipointers, ivalues2, 0xaaaa);
    for (int i = 0; i < 16; i++)
        printf("%d ", glob_iarray[i]);
    // CHECK: 0 37 43 31 14 8 12 6 45 10 35 39 4 2 41 33

    vecf16_t fvalues2 = {  30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45 };
    __builtin_nyuzi_scatter_storef_masked(fpointers, fvalues2, 0xaaaa);
    for (int i = 0; i < 16; i++)
        printf("%g ", glob_farray[i]);
    // CHECK: 0.0 37.0 43.0 31.0 14.0 8.0 12.0 6.0 45.0 10.0 35.0 39.0 4.0 2.0 41.0 33.0


    printf("\n");
    veci16_t gathered_iptrs1 = __builtin_nyuzi_gather_loadi(ipointers);
    for (int i = 0; i < 16; i++)
        printf("%d ", gathered_iptrs1[i]);
    // CHECK: 0 31 2 33 4 35 6 37 8 39 10 41 12 43 14 45

    vecf16_t gathered_fptrs1 = __builtin_nyuzi_gather_loadf(fpointers);
    for (int i = 0; i < 16; i++)
        printf("%g ", gathered_fptrs1[i]);
    // CHECK: 0.0 31.0 2.0 33.0 4.0 35.0 6.0 37.0 8.0 39.0 10.0 41.0 12.0 43.0 14.0 45.0

    printf("\n");
    veci16_t gathered_iptrs2 = __builtin_nyuzi_gather_loadi_masked(ipointers, 0xffff);
    for (int i = 0; i < 16; i++)
        printf("%d ", gathered_iptrs2[i]);
    // CHECK: 0 31 2 33 4 35 6 37 8 39 10 41 12 43 14 45

    vecf16_t gathered_fptrs2 = __builtin_nyuzi_gather_loadf_masked(fpointers, 0xffff);
    for (int i = 0; i < 16; i++)
        printf("%g ", gathered_fptrs2[i]);
    // CHECK: 0.0 31.0 2.0 33.0 4.0 35.0 6.0 37.0 8.0 39.0 10.0 41.0 12.0 43.0 14.0 45.0
}
