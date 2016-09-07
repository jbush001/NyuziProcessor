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
// Ensure dflush will cause a TLB miss if there isn't a mapping.
//

                .globl _start
_start:         load_tlb_entries itlb_entries, dtlb_entries

                // Enable MMU
                move s0, FLAG_MMU_EN | FLAG_SUPERVISOR_EN
                setcr s0, CR_FLAGS
                flush_pipeline

                lea s0, fail_test               // First test fails if there is a TLB miss
                setcr s0, CR_TRAP_HANDLER
                setcr s0, CR_TLB_MISS_HANDLER

                load_const s0, 0x2234           // Has mapping
                dflush  s0

                lea s0, tlb_fault               // Second test should produce TLB miss
                setcr s0, CR_TLB_MISS_HANDLER

                load_const s0, 0x3234           // no mapping
fault_loc:      dflush  s0                      // This should raise a tlb fault

                should_not_get_here

tlb_fault:      // Check that the fault is correct
                getcr s0, CR_TRAP_CAUSE
                assert_reg s0, TT_TLB_MISS | TRAP_CAUSE_DCACHE
                getcr s0, CR_TRAP_ADDRESS
                assert_reg s0, 0x3234

                // Check that fault PC is corect
                getcr s0, CR_TRAP_PC
                lea s1, fault_loc
                cmpeq_i s0, s0, s1
                btrue s0, 1f
                call fail_test
1:
                call pass_test

itlb_entries:   .long 0x00001000, 0x00001000 | TLB_PRESENT | TLB_EXECUTABLE
                .long 0xffffffff, 0xfffffff

dtlb_entries:   .long 0x00001000, 0x00001000 | TLB_PRESENT
                .long 0x00002000, 0x00002000 | TLB_PRESENT
                .long 0xffff0000, 0xffff0000 | TLB_PRESENT | TLB_WRITABLE    // I/O area
                .long 0xffffffff, 0xffffffff
