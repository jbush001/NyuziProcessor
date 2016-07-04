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

#define REG_ARITH_INST(__type__) (0xc0000000 | ((__type__) << 26))
#define IMM_ARITH_INST(__type__) ((__type__) << 28)
#define MEM_INST(__type__) (0x80000000 | ((__type__) << 25))

.macro test_illegal_inst testnum, instvalue
                lea s0, handle_fault\testnum
                setcr s0, CR_TRAP_HANDLER
fault_loc\testnum :
                .long \instvalue
                should_not_get_here
handle_fault\testnum :
                getcr s0, CR_TRAP_CAUSE
                assert_reg s0, TT_ILLEGAL_INSTRUCTION

                // Check that PC is correct
                getcr s0, CR_TRAP_PC
                lea s1, fault_loc\testnum
                cmpeq_i s0, s0, s1
                btrue s0, 1f
                call fail_test
1:
.endm

                .globl _start
_start:         test_illegal_inst 1, REG_ARITH_INST(3)
                test_illegal_inst 2, REG_ARITH_INST(6)
                test_illegal_inst 3, REG_ARITH_INST(7)
                test_illegal_inst 4, IMM_ARITH_INST(3)
                test_illegal_inst 5, IMM_ARITH_INST(6)
                test_illegal_inst 6, IMM_ARITH_INST(7)
                test_illegal_inst 7, MEM_INST(9)
                test_illegal_inst 8, MEM_INST(10)
                test_illegal_inst 9, MEM_INST(11)
                test_illegal_inst 10, MEM_INST(12)
                test_illegal_inst 11, MEM_INST(15)
                call pass_test
