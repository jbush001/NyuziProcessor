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
// Check that processor raises page fault if it attempts to execute from a
// page that does not have the present bit set.
//

                .globl _start
_start:         load_tlb_entries itlb_entries, dtlb_entries
                lea s0, fault_handler
                setcr s0, CR_TRAP_HANDLER
                move s0, FLAG_MMU_EN | FLAG_SUPERVISOR_EN
                setcr s0, CR_FLAGS
                flush_pipeline
                goto notpresent_page        // Jump to nonexecutable page

fault_handler:  getcr s0, CR_TRAP_CAUSE
                assert_reg s0, TT_PAGE_FAULT
                getcr s0, CR_TRAP_ADDRESS
                assert_reg s0, 0x2000   // Will resume here

                // Check that fault PC is correct
                getcr s0, CR_TRAP_PC
                lea s1, notpresent_page
                cmpeq_i s0, s0, s1
                btrue s0, 1f
                call fail_test
1:

                call pass_test

itlb_entries:   .long 0x00000000, TLB_PRESENT | TLB_EXECUTABLE
                .long 0x00001000, 0x00001000 | TLB_PRESENT | TLB_EXECUTABLE // code is here
                .long 0x00002000, 0x00002000 | TLB_EXECUTABLE   // NOTE: no present bit set
                .long 0xffffffff, 0xffffffff

dtlb_entries:   .long 0x00000000, TLB_PRESENT
                .long 0x00001000, 0x00001000 | TLB_PRESENT
                .long 0xffff0000, 0xffff0000 | TLB_PRESENT | TLB_WRITABLE    // I/O area
                .long 0xffffffff, 0xffffffff

                .align 0x1000, 0xff
notpresent_page: should_not_get_here
