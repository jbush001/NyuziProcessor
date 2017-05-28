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

#
# 32-bit integer division
# __divsi3(int dividend, int divisor)
#

                    .global __udivsi3
                    .type __udivsi3,@function
__udivsi3:          move s4, 0              # Quotient
                    cmplt_u s2, s0, s1      # dividend < divisor
                    bnz s2, done            # If yes, result is zero, bail

                    # Align high bits of divisor and dividend
                    clz s2, s0              # Get dividend leading bits
                    clz s3, s1              # Get divisor leading bits
                    sub_i s5, s3, s2        # Number of quotient bits
                    shl s1, s1, s5          # Shift divisor

divide_loop:        cmpge_u s2, s0, s1      # Is current dividend > divisor
                    and s2, s2, 1           # Set only lowest bit
                    or s4, s4, s2           # if true, quotient |= 1
                    shl s2, s2, 31          # Turn into 32-bit mask
                    ashr s2, s2, 31
                    and s3, s1, s2          # If the value is true, subtract amt = divisor
                    sub_i s0, s0, s3        # dividend -= divisor

                    bz s5, done             # If no more quotient bits, bail
                    sub_i s5, s5, 1         # Subtract 1 from quotient bits
                    shr s1, s1, 1           # Shift divisor right
                    shl s4, s4, 1           # Shift quotient left
                    b divide_loop

done:               move s0, s4             # Move quotient to return value
                    ret