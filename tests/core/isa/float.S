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

#include "arithmetic_macros.h"

#
# Basic floating point sanity tests. This does not test all instruction
# forms (see float_ops.S), nor does it exhaustively validate floating
# point conformance, but checks a bunch of common cases.
#

.macro test_op_loop start, end, op
            lea s0, \start
            lea s6, \end
1:          load_32 s1, (s0)       # operand 1
            load_32 s2, 4(s0)      # operand 2
            load_32 s3, 8(s0)      # expected result
            \op s4, s1, s2
            cmpeq_i s5, s4, s3     # Use integer compare so we don't treat specials differently
            bnz s5, 2f
            call fail_test
2:          add_i s0, s0, 12
            cmpeq_i s5, s0, s6
            bz s5, 1b
.endmacro

.macro test_compare op, result_list
            lea s0, compare_vals        # base ptr
            lea s1, compare_vals_end
            lea s2, \result_list
            move s3, s0                 # op1
1:          move s4, s0                 # op2
2:          load_32 s5, (s3)            # Read first op
            load_32 s6, (s4)            # Read second op
            load_u8 s7, (s2)            # Read expected
            \op s8, s5, s6
            and s8, s8, 1               # Chop bits
            cmpeq_i s9, s8, s7          # Check result
            bnz s9, 3f                  # If this matches, continue
            call fail_test
3:          add_i s2, s2, 1             # increment expected pointer
            add_i s4, s4, 4             # increment op2
            cmpeq_i s9, s4, s1          # op2 pointer at end?
            bz s9, 2b                   # No, so check next
            add_i s3, s3, 4             # increment op1
            cmpeq_i s9, s4, s1          # op1 pointer at end?
            bz s9, 1b                   # No, reset op2 ptr and loop
.endmacro

            .globl _start
_start:     test_op_loop add_ops, add_ops_end, add_f
            test_op_loop sub_ops, sub_ops_end, sub_f
            test_op_loop mul_ops, mul_ops_end, mul_f

            # Comparison tests
            test_compare cmpgt_f, cmpgt_expect
            test_compare cmpge_f, cmpge_expect
            test_compare cmplt_f, cmplt_expect
            test_compare cmple_f, cmple_expect
            test_compare cmpeq_f, cmpeq_expect
            test_compare cmpne_f, cmpne_expect
            call pass_test

compare_vals:
    .long 0x7f800000    # inf
    .float 2
    .float 1
    .float 0
    .float -1
    .float -2
    .long 0xff800000    # - inf
    .long 0x7fffffff    # NaN
compare_vals_end:

cmpgt_expect:
    .byte 0, 1, 1, 1, 1, 1, 1, 0   # op1 = inf
    .byte 0, 0, 1, 1, 1, 1, 1, 0   # op1 = 2
    .byte 0, 0, 0, 1, 1, 1, 1, 0   # op1 = 1
    .byte 0, 0, 0, 0, 1, 1, 1, 0   # op1 = 0
    .byte 0, 0, 0, 0, 0, 1, 1, 0   # op1 = -1
    .byte 0, 0, 0, 0, 0, 0, 1, 0   # op1 = -2
    .byte 0, 0, 0, 0, 0, 0, 0, 0   # op1 = -inf
    .byte 0, 0, 0, 0, 0, 0, 0, 0   # op1 = NaN

cmpge_expect:
    .byte 1, 1, 1, 1, 1, 1, 1, 0   # op1 = inf
    .byte 0, 1, 1, 1, 1, 1, 1, 0   # op1 = 2
    .byte 0, 0, 1, 1, 1, 1, 1, 0   # op1 = 1
    .byte 0, 0, 0, 1, 1, 1, 1, 0   # op1 = 0
    .byte 0, 0, 0, 0, 1, 1, 1, 0   # op1 = -1
    .byte 0, 0, 0, 0, 0, 1, 1, 0   # op1 = -2
    .byte 0, 0, 0, 0, 0, 0, 1, 0   # op1 = -inf
    .byte 0, 0, 0, 0, 0, 0, 0, 0   # op1 = NaN

cmplt_expect:
    .byte 0, 0, 0, 0, 0, 0, 0, 0   # op1 = inf
    .byte 1, 0, 0, 0, 0, 0, 0, 0   # op1 = 2
    .byte 1, 1, 0, 0, 0, 0, 0, 0   # op1 = 1
    .byte 1, 1, 1, 0, 0, 0, 0, 0   # op1 = 0
    .byte 1, 1, 1, 1, 0, 0, 0, 0   # op1 = -1
    .byte 1, 1, 1, 1, 1, 0, 0, 0   # op1 = -2
    .byte 1, 1, 1, 1, 1, 1, 0, 0   # op1 = -inf
    .byte 0, 0, 0, 0, 0, 0, 0, 0   # op1 = NaN

cmple_expect:
    .byte 1, 0, 0, 0, 0, 0, 0, 0   # op1 = inf
    .byte 1, 1, 0, 0, 0, 0, 0, 0   # op1 = 2
    .byte 1, 1, 1, 0, 0, 0, 0, 0   # op1 = 1
    .byte 1, 1, 1, 1, 0, 0, 0, 0   # op1 = 0
    .byte 1, 1, 1, 1, 1, 0, 0, 0   # op1 = -1
    .byte 1, 1, 1, 1, 1, 1, 0, 0   # op1 = -2
    .byte 1, 1, 1, 1, 1, 1, 1, 0   # op1 = -inf
    .byte 0, 0, 0, 0, 0, 0, 0, 0   # op1 = NaN

cmpeq_expect:
    .byte 1, 0, 0, 0, 0, 0, 0, 0   # op1 = inf
    .byte 0, 1, 0, 0, 0, 0, 0, 0   # op1 = 2
    .byte 0, 0, 1, 0, 0, 0, 0, 0   # op1 = 1
    .byte 0, 0, 0, 1, 0, 0, 0, 0   # op1 = 0
    .byte 0, 0, 0, 0, 1, 0, 0, 0   # op1 = -1
    .byte 0, 0, 0, 0, 0, 1, 0, 0   # op1 = -2
    .byte 0, 0, 0, 0, 0, 0, 1, 0   # op1 = -inf
    .byte 0, 0, 0, 0, 0, 0, 0, 0   # op1 = NaN

cmpne_expect:
    .byte 0, 1, 1, 1, 1, 1, 1, 1   # op1 = inf
    .byte 1, 0, 1, 1, 1, 1, 1, 1   # op1 = 2
    .byte 1, 1, 0, 1, 1, 1, 1, 1   # op1 = 1
    .byte 1, 1, 1, 0, 1, 1, 1, 1   # op1 = 0
    .byte 1, 1, 1, 1, 0, 1, 1, 1   # op1 = -1
    .byte 1, 1, 1, 1, 1, 0, 1, 1   # op1 = -2
    .byte 1, 1, 1, 1, 1, 1, 0, 1   # op1 = -inf
    .byte 1, 1, 1, 1, 1, 1, 1, 1   # op1 = NaN

add_ops:
    .float 17.79, 19.32, 37.11      # Exponents equal. Will carry into next significand bit
    .float 0.34, 44.23, 44.57       # Exponent 2 larger
    .float 44.23, 0.034, 44.264     # Exponent 1 larger
    .float -1.0, 5.0, 4.0           # First element is negative and has smaller exponent
    .float -5.0, 1.0, -4.0          # First element is negative and has larger exponent
    .float 5.0, -1.0, 4.0           # Second element is negative and has smaller exponent
    .float 1.0, -5.0, -4.0          # Second element is negative and has larger exponent
    .float 5.0, 0.0, 5.0            # Zero identity (zero is a special case in IEEE754)
    .float 0.0, 5.0, 5.0
    .float 0.0, 0.0, 0.0
    .float 7.0, -7.0, 0.0           # Sum is zero, positive first operand
    .float -7.0, 7.0, 0.0           # Sum is zero, negative first operand
    .float 1000000.0, 0.0000001, 1000000.0      # Second op is lost because of precision
    .float 0.0000001, 0.00000001, 0.00000011    # Very small number
    .float 1000000.0, 10000000.0, 11000000.0    # Large number
    .float -0.0, 2.323, 2.323       # negative zero
    .float 2.323, -0.0 , 2.323      # negative zero
    .float 5.67666007898e-42, 0.0, 5.67666007898e-42   # subnormal minus zero
    .float inf, inf, inf
    .float inf, 1.0, inf
    .float -inf, 1.0, -inf
    .float 0, -inf, -inf
    .float 1.0, inf, inf
    .float 1.0, -inf, -inf
    .float inf, -inf, nan
    .float nan, 1.0, nan
    .float 1.0, nan, nan
    .float nan, nan, nan
    .long 0x00800000, 0x80800000, 0 # Add underflow 2e-38 + -2e-38 = 0
    .long 0x7f7fffff, 0x7f7fffff, 0x7f800000 # Add overflow: 1e+38 + 1e+38 = inf
add_ops_end:

sub_ops:
    .float 5.0, 0.5, 4.5            # Positive result
    .float -1.0, 5.0, -6.0          # Negative result
    .float 1.0, 5.0, -4.0
    .float -1.0, -5.0, 4.0          # Subtract negative is add
    .float 1.0, -5.0, 6.0           # Same
    .float 5.0, 5.0, 0.0            # Result is zero
    .float 5.0, 0.0, 5.0            # Subtract zero does nothing
    .float 5.0, -0.0, 5.0           # Same, negative zero
    .float 0.0, 5.0, -5.0           # Subtract number from zero
    .float -0.0, 5.0, -5.0          # Same, negative zero
    .float 1000000.0, 0.0000001, 1000000.0      # Second op is lost because of precision
    .float 0.0000001, 0.00000001, 0.00000009    # Very small number
    .float 10000000.0, 1000000.0, 9000000.0     # Large number
    .float inf, -inf, inf
    .float inf, -1.0, inf
    .float -inf, -1.0, -inf
    .float 0, inf, -inf
    .float 1.0, -inf, inf
    .float 1.0, inf, -inf
    .float inf, inf, nan
    .float nan, 1.0, nan
    .float 1.0, nan, nan
    .float nan, nan, nan
sub_ops_end:

mul_ops:
    .float 0.0, 4.0, 0.0            # Zero identity
    .float 4.0, 0.0, 0.0
    .float 4.0, -0.0, -0.0          # Same w/ negative zero
    .float -4.0, 0.0, -0.0
    .float 1.0, 4.0, 4.0            # One identity
    .float 4.0, 1.0, 4.0
    .float 2.5, 12.0, 30.0
    .float -2.0, 4.0, -8.0          # negative x positive
    .float 2.0, -4.0, -8.0          # positive x negative
    .float -2.0, -4.0, 8.0          # negative x negative
    .float 100000.0, 7.0, 700000.0
    .float 7.0, 100000.0, 700000.0
    .float 5.0, 0.00001, 0.00005
    .float 0.00001, 5.0, 0.00005
    .float inf, 0, nan
    .float 0, inf, nan
    .float inf, inf, inf
    .float inf, -inf, -inf
    .float -inf, inf, -inf
    .float inf, 1, inf
    .float 1, inf, inf
    .float nan, 1, nan
    .float 1, nan, nan
    .long 0x7f7fffff, 0x40800000, 0x7f800000       # Mul overflow: 1e+38 * 4 = inf
    .long 0x00800000, 0x2d000000, 0x0              # Mul underflow: 1e-38 * 1e-12 = 0
mul_ops_end:
