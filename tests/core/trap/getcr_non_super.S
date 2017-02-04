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


// The fault handler advances the program counter two instructions.
// In this macro, this will skip the offending instruction and the
// branch to the failure case.
.macro check_getcr_fail index
                getcr s0, \index
                goto fail_test
.endm

// If a fault occurs, it will branch to the third instruction in this
// macro, which in turn branches to the failure case. If it doesn't
// fail, the second instruction will jump over the branch to the failure
// case.
.macro check_getcr_pass index
                getcr s0, \index
                goto 1f
                goto fail_test
1:
.endm


                .globl _start
_start:

                // Set up fault handler
                lea s0, handle_fault
                setcr s0, CR_TRAP_HANDLER

                // Switch to user mode
                setcr s0, CR_FLAGS
                flush_pipeline

                // These registers should be accessible
                check_getcr_pass CR_CURRENT_THREAD
                check_getcr_pass CR_CYCLE_COUNT

                // Access all other registers, which will fault
                check_getcr_fail 1
                check_getcr_fail 2
                check_getcr_fail 3
                check_getcr_fail 4
                check_getcr_fail 5
                check_getcr_fail 7
                check_getcr_fail 8
                check_getcr_fail 9
                check_getcr_fail 10
                check_getcr_fail 11
                check_getcr_fail 12
                check_getcr_fail 13
                check_getcr_fail 14
                check_getcr_fail 15
                check_getcr_fail 16
                check_getcr_fail 17
                check_getcr_fail 18
                check_getcr_fail 19
                check_getcr_fail 20
                check_getcr_fail 21
                check_getcr_fail 22
                check_getcr_fail 23
                check_getcr_fail 24
                check_getcr_fail 25
                check_getcr_fail 26
                check_getcr_fail 27
                check_getcr_fail 28
                check_getcr_fail 29
                check_getcr_fail 30
                check_getcr_fail 31
                call pass_test


handle_fault:   getcr s10, CR_TRAP_CAUSE
                assert_reg s10, TT_PRIVILEGED_OP
                getcr s10, CR_TRAP_PC
                add_i s10, s10, 8       // Skip offender and branch
                setcr s10, CR_TRAP_PC
                eret

