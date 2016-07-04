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
// Ensure that attempting to execute the 'eret' (return from exception)
// instruction faults if the thread is in user mode
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

fault_loc:      eret    // This should fault

                should_not_get_here

handle_fault:   getcr s0, CR_TRAP_CAUSE
                assert_reg s0, TT_PRIVILEGED_OP
                getcr s0, CR_TRAP_PC
                lea s1, fault_loc
                cmpeq_i s0, s0, s1
                btrue s0, 1f
                call fail_test
1:              call pass_test
