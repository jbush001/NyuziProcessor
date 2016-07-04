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
// Ensure inserting TLB entries multiple times for the same virtual address
// replaces the existing entry. This inserts several different physical
// mappings and checks that only the last mapping takes effect
//

                .globl _start
_start:         load_tlb_entries itlb_entries, dtlb_entries

                // Before enabling MMU, write a value that we will
                // read back later to ensure the proper page is mapped.
                load_const s0, 0xdeadbeef
                load_const s1, 0x2000
                store_32 s0, (s1)

                // Enable MMU
                move s0, FLAG_MMU_EN | FLAG_SUPERVISOR_EN
                setcr s0, CR_FLAGS
                flush_pipeline

                // Read from the mapped location and ensure it
                // gets the value from physical page 0x2000
                load_const s1, 0x1000
                load_32 s0, (s1)
                assert_reg s0, 0xdeadbeef

                call pass_test

itlb_entries:   .long 0x00000000, TLB_PRESENT | TLB_EXECUTABLE
                .long 0xffffffff, 0xfffffff

dtlb_entries:   .long 0x00000000, TLB_PRESENT

                // Note duplicate inserts for 0x1000
                .long 0x00001000, 0x00009000 | TLB_PRESENT
                .long 0x00001000, 0x00008000 | TLB_PRESENT
                .long 0x00001000, 0x00007000 | TLB_PRESENT
                .long 0x00001000, 0x00002000 | TLB_PRESENT
                .long 0xffff0000, 0xffff0000 | TLB_PRESENT | TLB_WRITABLE    // I/O area
                .long 0xffffffff, 0xffffffff
