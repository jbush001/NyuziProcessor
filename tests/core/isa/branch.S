#
# Copyright 2011-2017 Jeff Bush
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
# Test all branch types
#

                .globl _start
_start:
                move s0, 1
                move s1, 0
                move s2, -1

# Unconditional Branch
test0:          b 1f
                should_not_get_here
1:

# bz, taken
                bz s1, 1f
                should_not_get_here
1:

# bz, not taken
                bz s0, 1f
                b 2f
1:              should_not_get_here


# bnz, taken
2:              bnz s0, 1f
                should_not_get_here
1:

# bnz, not taken
2:              bnz s1, 1f
                b 2f
1:              should_not_get_here

# Call
2:
                call calltest1
retaddr1:       should_not_get_here
                nop
                nop
                nop
                nop
                nop
                nop
calltest1:      lea s0, retaddr1
                cmpeq_i s1, s0, ra # Check that call sets return address correctly
                bnz s1, 2f
                should_not_get_here

# Call register
2:              lea s0, calltest2
                call s0
retaddr2:       should_not_get_here
                nop
                nop
                nop
                nop
                nop
                nop
calltest2:      lea s0, retaddr2
                cmpeq_i s1, s0, ra # Check that call sets return address correctly
                bnz s1, 2f
                should_not_get_here

2:              call pass_test
