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

.include "../../asm_macros.inc"

#
# Test load_sync/store_sync instructions.
#

#define VALUE1 0xace9e130
#define VALUE2 0xff3dac7b
#define VALUE3 0x60c1da91

                .text
                .align    4

                .globl    _start
_start:         lea s0, test_sync

                // Successful
                li s2, VALUE2
                load_sync s1, (s0)
                assert_reg s1, VALUE1
                store_sync s2, (s0)
                assert_reg s2, 1        // written successfully
                load_32 s1, (s0)
                assert_reg s1, VALUE2

                // Unsuccessful
                li s2, VALUE3
                load_sync s1, (s0)
                assert_reg s1, VALUE2
                store_32 s4, 4(s0)       // Will invalidate cache line
                store_sync s2, (s0)
                assert_reg s2, 0        // failed
                load_32 s1, (s0)
                assert_reg s1, VALUE2

                call pass_test

                .align 4
test_sync:      .long VALUE1

