#
# Copyright 2011-2015 Jeff Bush
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

#include "../../asm_macros.inc"

#
# Test various comparisions
#

.equ BU, 0xc0800018
.equ BS, 0x60123498
.equ SM, 1


.macro compare_test compareop, reg1, reg2, expected
    li s10, \expected
    \compareop s11, \reg1, \reg2
    cmpeq_i s12, s10, s11
    bnz s12, 1f
    call fail_test
1:
.endmacro

            .globl _start
_start:     lea s0, ivec1
            load_v v0, (s0)
            load_v v1, 64(s0)

            # Vector integer comparisons
            compare_test cmpeq_i v0, v1, 0x0303
            compare_test cmpne_i v0, v1, 0xfcfc
            compare_test cmpgt_i v0, v1, 0x6868
            compare_test cmplt_i v0, v1, 0x9494
            compare_test cmpge_i v0, v1, 0x6b6b
            compare_test cmple_i v0, v1, 0x9797
            compare_test cmpgt_u v0, v1, 0x5454
            compare_test cmplt_u v0, v1, 0xa8a8
            compare_test cmpge_u v0, v1, 0x5757
            compare_test cmple_u v0, v1, 0xabab

            # Vector/scalar integer comparison
            li s0, BU
            compare_test cmpeq_i v0, s0, 0x1515
            compare_test cmpne_i v0, s0, 0xeaea
            compare_test cmpgt_i v0, s0, 0xeaea
            compare_test cmplt_i v0, s0, 0x0000
            compare_test cmpge_i v0, s0, 0xffff
            compare_test cmple_i v0, s0, 0x1515
            compare_test cmpgt_u v0, s0, 0x0000
            compare_test cmplt_u v0, s0, 0xeaea
            compare_test cmpge_u v0, s0, 0x1515
            compare_test cmple_u v0, s0, 0xffff

            # Scalar integer comparison
            li s1, BS
            compare_test cmpeq_i s1, s0, 0x0000
            compare_test cmpne_i s1, s0, 0xffff
            compare_test cmpgt_i s1, s0, 0xffff
            compare_test cmplt_i s1, s0, 0x0000
            compare_test cmpge_i s1, s0, 0xffff
            compare_test cmple_i s1, s0, 0x0000
            compare_test cmpgt_u s1, s0, 0x0000
            compare_test cmplt_u s1, s0, 0xffff
            compare_test cmpge_u s1, s0, 0x0000
            compare_test cmple_u s1, s0, 0xffff

            # Vector floating point comparison
            lea s0, fvec1
            load_v v0, (s0)
            load_v v1, 64(s0)
            compare_test cmpgt_f v0, v1, 0xff00
            compare_test cmplt_f v0, v1, 0x00ff
            compare_test cmpge_f v0, v1, 0xff00
            compare_test cmple_f v0, v1, 0x00ff

            # vector/scalar floating point comparison
            lea s0, fval3
            load_32 s0, (s0)
            lea s1, fval4
            load_32 s1, (s1)
            compare_test cmpgt_f v0, s0, 0xfe00
            compare_test cmplt_f v0, s0, 0x01ff
            compare_test cmpge_f v0, s0, 0xfe00
            compare_test cmple_f v0, s0, 0x01ff
            compare_test cmpgt_f v0, s1, 0xff80
            compare_test cmplt_f v0, s1, 0x007f
            compare_test cmpge_f v0, s1, 0xff80
            compare_test cmple_f v0, s1, 0x007f

            # scalar floating point comparison
            compare_test cmpgt_i s0, s1, 0xffff
            compare_test cmplt_i s0, s1, 0x0000
            compare_test cmple_i s0, s1, 0x0000
            compare_test cmpge_i s0, s1, 0xffff
            compare_test cmpgt_i s1, s0, 0x0000
            compare_test cmplt_i s1, s0, 0xffff
            compare_test cmple_i s1, s0, 0xffff
            compare_test cmpge_i s1, s0, 0x0000

            call pass_test

            .align 64
fvec1: .float -7.5, -6.5, -5.5, -4.5, -3.5, -2.5, -1.5, -0.5, 0.5, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5
fvec2: .float 7.5, 6.5, 5.5, 4.5, 3.5, 2.5, 1.5, 0.5, -0.5, -1.5, -2.5, -3.5, -4.5, -5.5, -6.5, -7.5
ivec1: .long BU, BS, BU, BS, BU, SM, BS, SM, BU, BS, BU, BS, BU, SM, BS, SM
ivec2: .long BU, BS, BS, BU, SM, BU, SM, BS, BU, BS, BS, BU, SM, BU, SM, BS
fval3: .float 1.0
fval4: .float -1.0

