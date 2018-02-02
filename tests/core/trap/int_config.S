//
// Copyright 2018 Jeff Bush
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

#include "../../asm_macros.inc"

//
// Ensure we can read and write interrupt configuration registers
//

            .globl _start
_start:     li s0, 0x871e
            setcr s0, CR_INTERRUPT_TRIGGER
            getcr s1, CR_INTERRUPT_TRIGGER
            assert_reg s1, 0x871e

            li s0, 0xdec4
            setcr s0, CR_INTERRUPT_TRIGGER
            getcr s1, CR_INTERRUPT_TRIGGER
            assert_reg s1, 0xdec4

            li s0, 0x9a0f
            setcr s0, CR_INTERRUPT_MASK
            getcr s1, CR_INTERRUPT_MASK
            assert_reg s1, 0x9a0f

            li s0, 0x5f21
            setcr s0, CR_INTERRUPT_MASK
            getcr s1, CR_INTERRUPT_MASK
            assert_reg s1, 0x5f21

            call pass_test