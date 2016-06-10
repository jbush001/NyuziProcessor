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
// Check that tlbinval instruction will remove a TLB entry from DTLB by
// mapping a page, ensuring it can be accessed, invalidating, then
// attempting to access it again. The second access will raise a fault.
//

                .globl _start
_start:         load_tlb_entries itlb_entries, dtlb_entries

                // Store known value on data page
                load_const s0, 0xdeadbeef
                load_const s1, 0x1234
                store_32 s0, (s1)

                // Fail on TLB miss
                lea s0, fail_test
                setcr s0, CR_TLB_MISS_HANDLER

                // Enable MMU
                move s0, FLAG_MMU_EN | FLAG_SUPERVISOR_EN
                setcr s0, CR_FLAGS
                flush_pipeline

                // Touch the first page. Ensure value is correct.
                load_32 s0, (s1)
                assert_reg s0, 0xdeadbeef

                // Invalidate page, ensure it raises TLB miss (and nothing
                // else does)
                lea s0, check_fault
                setcr s0, CR_TLB_MISS_HANDLER
                tlbinval s1
                load_32 s0, (s1)

                should_not_get_here

check_fault:    getcr s0, CR_TRAP_CAUSE
                assert_reg s0, TT_TLB_MISS | TRAP_CAUSE_DCACHE
                getcr s0, CR_TRAP_ADDRESS
                assert_reg s0, 0x1234

                call pass_test


itlb_entries:   .long 0x00000000, TLB_PRESENT | TLB_EXECUTABLE
                .long 0xffffffff, 0xffffffff

dtlb_entries:   .long 0x00000000, TLB_PRESENT
                .long 0x00001000, 0x00001000 | TLB_PRESENT | TLB_WRITABLE
                .long 0xffff0000, 0xffff0000 | TLB_PRESENT | TLB_WRITABLE    // I/O area
                .long 0xffffffff, 0xffffffff
