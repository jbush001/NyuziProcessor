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
// Ensure we are properly translating I/O addresses, specifically that
// we are using the physical address and not the virtual address to determine
// if something is in the I/O range.
// Map a chunk of normal memory at the virtual range 0xffff0000 where I/O
// is physically located, and map the I/O range at 0x1000
//

                .globl _start
_start:         load_tlb_entries itlb_entries, dtlb_entries

                load_const s0, 0x1000
                load_const s1, 0xdeadbeef
                store_32 s1, (s0)

                // Enable MMU
                move s0, FLAG_MMU_EN | FLAG_SUPERVISOR_EN
                setcr s0, CR_FLAGS
                flush_pipeline

                // Read data value
                load_const s0, 0xffff0000
                load_32 s1, (s0)
                assert_reg s1, 0xdeadbeef

                // Write success value to new I/O region
                load_const s1, 0x1000
                lea s0, message
1:              load_u8 s2, (s0)        // Read a character
                bfalse s2, 3f           // If delimeter, exit
2:              load_32 s3, 0x40(s1)    // Read STATUS
                and s3, s3, 1           // Check write available bit
                bfalse s3, 2b           // If this is clear, busy wait
                store_32 s2, 0x48(s1)   // Write space available, send char
                add_i s0, s0, 1         // Increment pointer
                goto 1b                 // Loop for next char
3:

                // halt
                move s0, -1
                store_32 s0, 0x104(s1)
1:              goto 1b


message:        .asciz "PASS"

                .align 4, 0xff
itlb_entries:   .long 0x00000000, TLB_PRESENT | TLB_EXECUTABLE
                .long 0xffffffff, 0xffffffff

dtlb_entries:   .long 0x00000000, TLB_PRESENT
                .long 0x00001000, 0xffff0000 | TLB_PRESENT | TLB_WRITABLE
                .long 0xffff0000, 0x1000 | TLB_PRESENT | TLB_WRITABLE
                .long 0xffffffff, 0xffffffff
