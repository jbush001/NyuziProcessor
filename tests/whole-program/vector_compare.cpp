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
#include <stdint.h>

// Test various forms of vector comparisons

const veci16_t kVecA = { -1, 0, 1, -1, 0, 1, -1, 0, 1, 0, 1, 2, 3, 4, 5, 6 };
const veci16_t kVecB = {  -1, -1, -1, 0, 0, 0, 1, 1, 1, 6, 5, 4, 3, 2, 1, 0 };
const vecf16_t kVecC = { -1, 0, 1, -1, 0, 1, -1, 0, 1, 0, 1, 2, 3, 4, 5, 6 };
const vecf16_t kVecD = {  -1, -1, -1, 0, 0, 0, 1, 1, 1, 6, 5, 4, 3, 2, 1, 0 };

void __attribute__ ((noinline)) printVector(veci16_t v)
{
    for (int lane = 0; lane < 16; lane++)
        printf("%d ", v[lane]);

    printf("\n");
}

void __attribute__ ((noinline)) compareVectors(veci16_t a, veci16_t b)
{
    printf("%04x\n", __builtin_nyuzi_mask_cmpi_ugt(a, b));
    printf("%04x\n", __builtin_nyuzi_mask_cmpi_uge(a, b));
    printf("%04x\n", __builtin_nyuzi_mask_cmpi_ult(a, b));
    printf("%04x\n", __builtin_nyuzi_mask_cmpi_ule(a, b));
    printf("%04x\n", __builtin_nyuzi_mask_cmpi_sgt(a, b));
    printf("%04x\n", __builtin_nyuzi_mask_cmpi_sge(a, b));
    printf("%04x\n", __builtin_nyuzi_mask_cmpi_slt(a, b));
    printf("%04x\n", __builtin_nyuzi_mask_cmpi_sle(a, b));
    printf("%04x\n", __builtin_nyuzi_mask_cmpi_eq(a, b));
    printf("%04x\n", __builtin_nyuzi_mask_cmpi_ne(a, b));
}

void __attribute__ ((noinline)) compareVectors(vecf16_t a, vecf16_t b)
{
    printf("%04x\n", __builtin_nyuzi_mask_cmpf_gt(a, b));
    printf("%04x\n", __builtin_nyuzi_mask_cmpf_ge(a, b));
    printf("%04x\n", __builtin_nyuzi_mask_cmpf_lt(a, b));
    printf("%04x\n", __builtin_nyuzi_mask_cmpf_le(a, b));
    printf("%04x\n", __builtin_nyuzi_mask_cmpf_eq(a, b));
    printf("%04x\n", __builtin_nyuzi_mask_cmpf_ne(a, b));
}

int main()
{
    // The first four tests validate convertint the result of a vector
    // comparison to another vector (the native format is a bitmask,
    // the compiler synthesizes the conversion)
    // XXX this doesn't test unsigned...

    printVector(kVecA > kVecB);
    // CHECK: 0 -1 -1
    // CHECK: 0 0 -1
    // CHECK: 0 0 0
    // CHECK: 0 0 0 0 -1 -1 -1

    printVector(kVecA >= kVecB);
    // CHECK: -1 -1 -1
    // CHECK: 0 -1 -1
    // CHECK: 0 0 -1
    // CHECK: 0 0 0 -1 -1 -1 -1

    printVector(kVecA < kVecB);
    // CHECK: 0 0 0
    // CHECK: -1 0 0
    // CHECK: -1 -1 0
    // CHECK: -1 -1 -1 0 0 0 0

    printVector(kVecA <= kVecB);
    // CHECK: -1 0 0
    // CHECK: -1 -1 0
    // CHECK: -1 -1 -1
    // CHECK: -1 -1 -1 -1 0 0 0

    // Test all comparison builtins
    compareVectors(kVecA, kVecB);
    // CHECK: e068
    // CHECK: f179
    // CHECK: 0e86
    // CHECK: 1f97
    // CHECK: e026
    // CHECK: f137
    // CHECK: 0ec8
    // CHECK: 1fd9
    // CHECK: 1111
    // CHECK: eeee

    compareVectors(kVecC, kVecD);
    // CHECK: e026
    // CHECK: f137
    // CHECK: 0ec8
    // CHECK: 1fd9
    // CHECK: 1111
    // CHECK: eeee
}
