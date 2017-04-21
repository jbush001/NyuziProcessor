//
// Copyright 2015-2016 Jeff Bush
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
// Ensure instructions will invalid operation fields raise traps
// (illegal instruction)
//

#define REG_ARITH_INST(__type__) (0xc0000000 | ((__type__) << 26))
#define MEM_INST(__type__) (0x80000000 | ((__type__) << 25))
#define BRANCH_INST(__type__) (0xf0000000 | ((__type__) << 25))

.macro _test_illegal_inst testnum, subtest, instvalue, flags
                lea s0, handle_fault\testnum\()_\subtest
                setcr s0, CR_TRAP_HANDLER

                // Switch modes if necessary
                move s0, \flags
                setcr s0, CR_FLAGS
                flush_pipeline

fault_loc\testnum\()_\subtest :
                .long \instvalue
                should_not_get_here
handle_fault\testnum\()_\subtest :
                getcr s0, CR_TRAP_CAUSE
                assert_reg s0, TT_ILLEGAL_INSTRUCTION

                // Check that we've switched back to supervisor mode
                getcr s0, CR_FLAGS
                assert_reg s0, FLAG_SUPERVISOR_EN
                getcr s0, CR_SAVED_FLAGS
                assert_reg s0, \flags

                // Check that trap PC is correct
                getcr s0, CR_TRAP_PC
                lea s1, fault_loc\testnum\()_\subtest
                cmpeq_i s0, s0, s1
                bnz s0, 1f
                call fail_test
1:
.endm

.macro test_illegal_inst testnum, instvalue
    // Test in user mode
    _test_illegal_inst \testnum, 0, \instvalue, 0

    // Test in supervisor mode
    _test_illegal_inst \testnum, 1, \instvalue, FLAG_SUPERVISOR_EN
.endm



                .globl _start
_start:
                // Check all in user mode
                test_illegal_inst 1, REG_ARITH_INST(3)
                test_illegal_inst 2, REG_ARITH_INST(6)
                test_illegal_inst 3, REG_ARITH_INST(7)
                test_illegal_inst 7, MEM_INST(9)
                test_illegal_inst 8, MEM_INST(10)
                test_illegal_inst 9, MEM_INST(11)
                test_illegal_inst 10, MEM_INST(12)
                test_illegal_inst 11, MEM_INST(15)
                test_illegal_inst 13, BRANCH_INST(5)

                call pass_test
