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
// This creates two virtual mappings to the same physical address
// (cache synonym) and ensures the value written in one is readable
// in the other.
//

                .globl _start
_start:         load_tlb_entries itlb_entries, dtlb_entries

                // Enable MMU
                move s0, FLAG_MMU_EN | FLAG_SUPERVISOR_EN
                setcr s0, CR_FLAGS
                flush_pipeline

                load_const s0, 0xdeadbeef
                load_const s1, 0x2234
                store_32 s0, (s1)
                load_const s2, 0x3234
                load_32 s3, (s2)
                assert_reg s3, 0xdeadbeef

                call pass_test


itlb_entries:   .long 0x00001000, 0x00001000 | TLB_PRESENT | TLB_EXECUTABLE
                .long 0xffffffff, 0xffffffff

dtlb_entries:   .long 0x00001000, 0x00001000 | TLB_PRESENT
                .long 0x00002000, 0x00001000 | TLB_PRESENT | TLB_WRITABLE
                .long 0x00003000, 0x00001000 | TLB_PRESENT | TLB_WRITABLE
                .long 0xffff0000, 0xffff0000 | TLB_PRESENT | TLB_WRITABLE    // I/O area
                .long 0xffffffff, 0xffffffff
