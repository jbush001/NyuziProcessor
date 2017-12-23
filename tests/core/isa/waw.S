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

.include "../../asm_macros.inc"

#
# Test Write-After-Write conflict. Specifically when a short latency
# instruction is issued after a long latency one, and they have
# the same destination register, the scoreboard delays  issuing the
# second until the first completes.
#

                .text
                .align    4

                .globl    _start
_start:         move s1, 17
                move s2, 19
                move s3, 5
                move s4, 9
                move s5, 14 # add result

                # Ensure all existing instructions are cleared
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop

                # Conflict here
                mull_i s3, s1, s2
                add_i s3, s3, s4

                # Clear pipeline to ensure no RAW scheduling
                nop
                nop
                nop
                nop
                nop
                nop
                nop
                nop

                cmpeq_i s6, s3, s5
                bnz s4, 1f
                call fail_test
1:              call pass_test
