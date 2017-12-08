//
// Copyright 2016 Jeff Bush
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

#include "../asm_macros.inc"

                .globl _start
_start:         li s0, REG_THREAD_RESUME
                li s1, 3
                store_32 s1, (s0)
                getcr s0, CR_CURRENT_THREAD
                shl s0, s0, 2
                lea s1, jump_table
                add_i s0, s0, s1
                b s0
                nop
                nop
                nop
jump_table:
1:              b 1b
2:              b 2b
3:              b 3b
4:              b 4b

jump_target:    li s0, 0x6bee68ca
5:              b 5b