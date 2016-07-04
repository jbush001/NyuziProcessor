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

// Clobbers s0, s1, s2
// itlb_entries and dtlb_entries point to two labels, each which points
// to a table. Each entry of the table is two words, the first being a
// virtual address and the second being the TLB entry (physical address
// plus flags). The macro stops reading table entries when it hits
// an entry where the virtual address is 0xffffffff.
//
.macro load_tlb_entries itlb_entries, dtlb_entries
                    // Load ITLB
                    lea s0, \itlb_entries
1:                  load_32 s1, (s0)
                    cmpeq_i s2, s1, -1
                    btrue s2, 2f
                    load_32 s2, 4(s0)
                    itlbinsert s1, s2
                    add_i s0, s0, 8
                    goto 1b
2:
                    // Load DTLB
                    lea s0, \dtlb_entries
1:                  load_32 s1, (s0)
                    cmpeq_i s2, s1, -1
                    btrue s2, 2f
                    load_32 s2, 4(s0)
                    dtlbinsert s1, s2
                    add_i s0, s0, 8
                    goto 1b
2:
.endm

//
// This first loads itlb_entries and dtlb_entries using the load_tlb_entries
// macro. It then executes 'access_op' memory operation at a given address.
// This is expected to cause a fault, which this will catch, then check that
// the reason, fault PC, and fault address are correct.
//
.macro mmu_fault_test cause, access_op, address, itlb_entries, dtlb_entries, flags
                    load_tlb_entries \itlb_entries, \dtlb_entries

                    lea s0, handle_fault
                    setcr s0, CR_TRAP_HANDLER
                    lea s0, fail_test
                    setcr s0, CR_TLB_MISS_HANDLER // Fail on TLB miss

                    move s0, \flags
                    setcr s0, CR_FLAGS          // Enable MMU
                    flush_pipeline

                    load_const s0, \address
fault_loc:          \access_op s0, (s0)            // This should fault
                    call fail_test                 // Fail if no

                    // After fault resumes from here. Check that it behaved as
                    // expected.
handle_fault:       getcr s0, CR_TRAP_CAUSE
                    assert_reg s0, \cause
                    getcr s0, CR_TRAP_ADDRESS
                    assert_reg s0, \address

                    // Check that fault PC is correct
                    getcr s0, CR_TRAP_PC
                    lea s1, fault_loc
                    cmpeq_i s0, s0, s1
                    btrue s0, 1f
                    call fail_test
1:

                    call pass_test
.endm

