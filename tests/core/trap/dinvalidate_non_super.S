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
// Ensure that attempting to execute the 'dinvalidate' instruction faults
// and doesn't perform its side effects if the thread is in user mode.
//

.set DATA_LOCATION, 0x4000
.set WRITE_VALUE, 0x12345678

                .globl _start
_start:
                // Set up fault handler
                lea s0, handle_fault
                setcr s0, CR_TRAP_HANDLER

                // Switch to user mode
                move s0, 0
                setcr s0, CR_FLAGS
                flush_pipeline

                li s10, DATA_LOCATION
                li s11, WRITE_VALUE
                store_32 s11, (s10)

fault_loc:      dinvalidate s10 // This should fault

                should_not_get_here

handle_fault:   getcr s0, CR_TRAP_CAUSE
                assert_reg s0, TT_PRIVILEGED_OP
                getcr s0, CR_FLAGS
                assert_reg s0, FLAG_SUPERVISOR_EN
                getcr s0, CR_SAVED_FLAGS
                assert_reg s0, 0
                getcr s0, CR_TRAP_PC
                lea s1, fault_loc
                cmpeq_i s0, s0, s1
                bnz s0, 1f
                call fail_test
1:

                // Read the data location and ensure it still has the
                // new value (if the side effect of dinvalidate occurred,
                // it would have reverted the location to its original value).
                li s10, DATA_LOCATION
                load_32 s11, (s10)
                assert_reg s11, WRITE_VALUE

                call pass_test
