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
// Ensure executing getcr instruction faults in user mode.
//

                .globl _start
_start:
                // Set up fault handler
                lea s0, handle_fault
                setcr s0, CR_TRAP_HANDLER

                // Switch to user mode
                move s0, 0
                setcr s0, CR_FLAGS
                flush_pipeline

fault_loc:      getcr s0, CR_TRAP_HANDLER        // This should fault
                should_not_get_here

handle_fault:   // Check that s0 was not updated. If it were, that could
                // leak information from the supervisor
                assert_reg s0, 0

                getcr s10, CR_TRAP_CAUSE
                assert_reg s10, TT_PRIVILEGED_OP
                getcr s0, CR_FLAGS
                assert_reg s0, FLAG_SUPERVISOR_EN
                getcr s0, CR_SAVED_FLAGS
                assert_reg s0, 0
                getcr s10, CR_TRAP_PC
                lea s11, fault_loc
                cmpeq_i s10, s10, s11
                bnz s10, 1f
                call fail_test
1:              call pass_test


