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

#include "mmu_test_common.inc"

//
// Check that the processor faults and doesn't update the TLB if
// itlbinsert is called from user mode.
//

                .globl _start
_start:         load_tlb_entries itlb_entries, dtlb_entries

                lea s0, handle_fault1
                setcr s0, CR_TRAP_HANDLER
                lea s0, handle_fault2
                setcr s0, CR_TLB_MISS_HANDLER

                // Enable MMU, switch to user mode
                move s0, FLAG_MMU_EN
                setcr s0, CR_FLAGS
                flush_pipeline

                load_const s0, 0x1000
                load_const s1, 0x1000 | TLB_PRESENT | TLB_EXECUTABLE
fault_loc:      itlbinsert s0, s1   // This should fault

                should_not_get_here

handle_fault1:  getcr s0, CR_TRAP_CAUSE
                assert_reg s0, TT_PRIVILEGED_OP

                // Check that fault PC is correct
                getcr s0, CR_TRAP_PC
                lea s1, fault_loc
                cmpeq_i s0, s0, s1
                btrue s0, 1f
                call fail_test
1:

                // Jump to new page. This should fail because the entry
                // wasn't added to the TLB
                load_const s0, 0x1000
                move pc, s0

                should_not_get_here

handle_fault2:  getcr s0, CR_TRAP_CAUSE
                assert_reg s0, TT_TLB_MISS
                getcr s0, CR_TRAP_ADDRESS
                assert_reg s0, 0x1000

                call pass_test

itlb_entries:   .long 0x00000000, TLB_PRESENT | TLB_EXECUTABLE
                .long 0xffffffff, 0xffffffff

dtlb_entries:   .long 0x00000000, TLB_PRESENT
                .long 0xffff0000, 0xffff0000 | TLB_PRESENT | TLB_WRITABLE    // I/O area
                .long 0xffffffff, 0xffffffff
