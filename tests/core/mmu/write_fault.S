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
// Ensure writing to a page that does not have its writable bit set
// faults and does not update memory.
//

.set ORIGINAL_VALUE, 0xb74e5a8d
.set TEST_ADDR, 0x2350


                .globl _start
_start:
                # Write an arbitrary value into the location we are going to
                # attempt to write. We'll check this after the test.
                li s0, ORIGINAL_VALUE       # Magic value
                li s1, TEST_ADDR
                store_32 s0, (s1)

                mmu_fault_test (TT_ILLEGAL_STORE | TRAP_CAUSE_DCACHE | TRAP_CAUSE_STORE), store_32, 0x2350, itlb_entries, dtlb_entries, FLAG_MMU_EN | FLAG_SUPERVISOR_EN

                # Disable MMU, check that location wasn't updated
                move s0, FLAG_SUPERVISOR_EN
                setcr s0, CR_FLAGS

                li s0, TEST_ADDR
                load_32 s0, (s0)
                assert_reg s0, ORIGINAL_VALUE

                call pass_test

itlb_entries:   .long 0x00001000, 0x00001000 | TLB_PRESENT | TLB_EXECUTABLE
                .long 0xffffffff, 0xffffffff

dtlb_entries:   .long 0x00001000, 0x00001000 | TLB_PRESENT
                .long 0x00002000, 0x00002000 | TLB_PRESENT     // writable bit not set
                .long 0xffff0000, 0xffff0000 | TLB_PRESENT | TLB_WRITABLE    // I/O area
                .long 0xffffffff, 0xffffffff
