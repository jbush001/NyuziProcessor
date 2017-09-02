#
# Copyright 2017 Jeff Bush
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#include "arithmetic_macros.inc"

# This tests all floating point instruction forms, but doesn't validate
# the results extensively (see float.S)

# Can't encode floating point numbers for li pseudo op, so these are integer
# representations of these floating point numbers
#define ZERO 0x0
#define POINT_FIVE 0x3f000000
#define ONE 0x3f800000
#define TWO 0x40000000
#define THREE 0x40400000
#define SIX 0x40c00000

                .globl _start
_start:         test_sss add_f, THREE, TWO, ONE
                test_vvs add_f, result1, vec_op1, ONE
                test_vvsm add_f_mask, result2, 0x5555, vec_op1, ONE
                test_vvv add_f result3, vec_op1, vec_op2
                test_vvvm add_f_mask result4, 0xaaaa, vec_op1, vec_op2

                test_sss sub_f, ONE, THREE, TWO
                test_vvs sub_f, result5, vec_op1, ONE
                test_vvsm sub_f_mask, result6, 0x5555, vec_op1, ONE
                test_vvv sub_f result7, vec_op1, vec_op2
                test_vvvm sub_f_mask result8, 0xaaaa, vec_op1, vec_op2

                test_sss mul_f, SIX, TWO, THREE
                test_vvs mul_f, result9, vec_op1, TWO
                test_vvsm mul_f_mask, result10, 0x5555, vec_op1, TWO
                test_vvv mul_f result11, vec_op1, vec_op2
                test_vvvm mul_f_mask result12, 0xaaaa, vec_op1, vec_op2

                test_ss ftoi, 6, SIX
                test_vs ftoi, result13, SIX
                test_vsm ftoi_mask, result14, 0x5555, SIX
                test_vv ftoi, result15, vec_op1
                test_vvm ftoi_mask, result16, 0xaaaa, vec_op1

                test_ss itof SIX, 6
                test_vs itof, result17, 6
                test_vsm itof_mask, result18, 0x5555, 6
                test_vv itof, vec_op2, int_op1
                test_vvm itof_mask, result19, 0xaaaa, int_op1

                test_ss reciprocal, POINT_FIVE, TWO
                test_vs reciprocal, result20, TWO
                test_vsm reciprocal_mask, result21, 0x5555, TWO
                test_vv reciprocal, result22, vec_op3
                test_vvm reciprocal_mask, result23, 0xaaaa, vec_op3

                call pass_test

                .align 64
vec_op1:  .float 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0
vec_op2:  .float 0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0
vec_op3:  .float 1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 64.0, 128.0, 256.0, 512.0, 1024.0, 2048.0, 4096.0, 8192.0, 16384.0, 32768.0
int_op1:  .long 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
result1:  .float 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0
result2:  .float 1.5, 0.0, 2.5, 0.0, 3.5, 0.0, 4.5, 0.0, 5.5, 0.0, 6.5, 0.0, 7.5, 0.0, 8.5, 0.0
result3:  .float 0.5, 2.0, 3.5, 5.0, 6.5, 8.0, 9.5, 11.0, 12.5, 14.0, 15.5, 17.0, 18.5, 20.0, 21.5, 23.0
result4:  .float 0.0, 2.0, 0.0, 5.0, 0.0, 8.0, 0.0, 11.0, 0.0, 14.0, 0.0, 17.0, 0.0, 20.0, 0.0, 23.0
result5:  .float -0.5, 0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0, 6.5, 7.0
result6:  .float -0.5, 0.0, 0.5, 0.0, 1.5, 0.0, 2.5, 0.0, 3.5, 0.0, 4.5, 0.0, 5.5, 0.0, 6.5, 0.0
result7:  .float 0.5, 0.0, -0.5, -1.0, -1.5, -2.0, -2.5, -3.0, -3.5, -4.0, -4.5, -5.0, -5.5, -6.0, -6.5, -7.0
result8:  .float 0.0, 0.0, 0.0, -1.0, 0.0, -2.0, 0.0, -3.0, 0.0, -4.0, 0.0, -5.0, 0.0, -6.0, 0.0, -7.0
result9:  .float 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0
result10: .float 1.0, 0.0, 3.0, 0.0, 5.0, 0.0, 7.0, 0.0, 9.0, 0.0, 11.0, 0.0, 13.0, 0.0, 15.0, 0.0
result11: .float 0.0, 1.0, 3.0, 6.0, 10.0, 15.0, 21.0, 28.0, 36.0, 45.0, 55.0, 66.0, 78.0, 91.0, 105.0, 120.0
result12: .float 0.0, 1.0, 0.0, 6.0, 0.0, 15.0, 0.0, 28.0, 0.0, 45.0, 0.0, 66.0, 0.0, 91.0, 0.0, 120.0
result13: .long 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6
result14: .long 6, 0, 6, 0, 6, 0, 6, 0, 6, 0, 6, 0, 6, 0, 6, 0
result15: .long 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8
result16: .long 0, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 7, 0, 8
result17: .float 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6
result18: .float 6, 0, 6, 0, 6, 0, 6, 0, 6, 0, 6, 0, 6, 0, 6, 0
result19: .float 0.0, 1.0, 0.0, 3.0, 0.0, 5.0, 0.0, 7.0, 0.0, 9.0, 0.0, 11.0, 0.0, 13.0, 0.0, 15.0
result20: .float 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5
result21: .float 0.5, 0.0, 0.5, 0.0, 0.5, 0.0, 0.5, 0.0, 0.5, 0.0, 0.5, 0.0, 0.5, 0.0, 0.5, 0.0
result22: .float 1.0, 0.5, 0.25, 0.125, 0.0625, 0.03125, 0.015625, 0.0078125, 0.00390625, 0.001953125, 0.0009765625, 0.00048828125, 0.000244140625, 0.0001220703125, 0.00006103515625, 0.000030517578125
result23: .float 0.0, 0.5, 0.0, 0.125, 0.0, 0.03125, 0.0, 0.0078125, 0.0, 0.001953125, 0.0, 0.00048828125, 0.0, 0.0001220703125, 0.0, 0.000030517578125
