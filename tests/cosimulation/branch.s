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

.include "../asm_macros.inc"


#
# Test all branch types
#


                .globl _start
_start:
                move s0, 1
                move s1, 0
                move s2, -1

# Unconditional Branch
test0:          goto 1f
                move s10, 1
                goto 2f
1:              move s10, 2

# bfalse, taken
2:              bfalse s1, 1f
                move s10, 3
                goto 2f
1:              move s10, 4

# bfalse, not taken
2:              bfalse s0, 1f
                move s10, 5
                goto 2f
1:              move s10, 6


# btrue, taken
2:              btrue s0, 1f
                move s10, 7
                goto 2f
1:              move s10, 8

# btrue, not taken
2:              btrue s1, 1f
                move s10, 9
                goto 2f
1:              move s10, 10

# Call
2:              call calltest1
calltest1:      move s10, 23

# Call register
                lea s0, calltest2
                call s0
calltest2:      move s10, 24

# Load PC from memory
                lea s1, pcloaddest
                load_32 pc, (s1)
                move s11, 123        # This should not happen
pcloaddest:     .long pcloadhere
pcloadhere:     move s10, 1

# Load PC from register
                lea s1, pcarithhere
                move pc, s1
                move s10, 25
pcarithhere:    move s10, 26

# Make sure vector moves don't trigger branch
                move v31, s1
                move s10, 27

                halt_current_thread

