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

#include "../../asm_macros.inc"

//
// Ensure jumping to an unaligned address faults
//

                .globl _start
_start:

                // The first fault will occur in supervisor mode
                // Set up fault handler
                lea s0, handle_fault1
                setcr s0, CR_TRAP_HANDLER

                // jump to bad address
                move s0, 0x567
                b s0

handle_fault1:  getcr s0, CR_TRAP_CAUSE
                assert_reg s0, TT_UNALIGNED_ACCESS

                // Check that we're still in supervisor mode
                getcr s0, CR_FLAGS
                assert_reg s0, FLAG_SUPERVISOR_EN
                getcr s0, CR_SAVED_FLAGS
                assert_reg s0, FLAG_SUPERVISOR_EN

                getcr s0, CR_TRAP_PC
                assert_reg s0, 0x567
                call pass_test

                // The second fault will occur in user mode
                // Set up fault handler
                lea s0, handle_fault2
                setcr s0, CR_TRAP_HANDLER

                // Switch to user mode
                move s0, 0
                setcr s0, CR_FLAGS
                flush_pipeline

                // jump to bad address
                move s0, 0x357
                b s0

handle_fault2:  getcr s0, CR_TRAP_CAUSE
                assert_reg s0, TT_UNALIGNED_ACCESS

                // Check that we've swiched back to supervisor mode
                getcr s0, CR_FLAGS
                assert_reg s0, FLAG_SUPERVISOR_EN
                getcr s0, CR_SAVED_FLAGS
                assert_reg s0, 0

                getcr s0, CR_TRAP_PC
                assert_reg s0, 0x357
                call pass_test
