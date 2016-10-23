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
// Ensure instruction/data translation are working correctly by mapping
// code to a high address and executing it.
//

                .globl _start
_start:         load_tlb_entries itlb_entries, dtlb_entries

                // Enable MMU
                move s0, FLAG_MMU_EN | FLAG_SUPERVISOR_EN
                setcr s0, CR_FLAGS
                flush_pipeline

                // Jump to high memory
                move s0, 1
                shl s0, s0, 31      // 0x80000000
                move pc, s0         // Jump to address

itlb_entries:   .long 0x00001000, 0x00001000 | TLB_PRESENT | TLB_EXECUTABLE | TLB_SUPERVISOR
                .long 0x00001000, 0x1000 | TLB_PRESENT | TLB_EXECUTABLE | TLB_SUPERVISOR
                .long 0x80000000, 0x00002000 | TLB_PRESENT | TLB_EXECUTABLE | TLB_SUPERVISOR
                .long 0xffffffff, 0xffffffff

dtlb_entries:   .long 0x00001000, 0x00001000 | TLB_PRESENT | TLB_SUPERVISOR
                .long 0x00001000, 0x1000 | TLB_PRESENT | TLB_SUPERVISOR
                .long 0x80000000, 0x00002000 | TLB_PRESENT | TLB_SUPERVISOR
                .long 0xffff0000, 0xffff0000 | TLB_PRESENT | TLB_SUPERVISOR | TLB_WRITABLE
                .long 0xffffffff, 0xffffffff

                .align 0x1000, 0xff

                // Physical page 0x2000, mapped at 0x80000000
                // Need to be careful here to only use PC relative addresses here because
                // this is not running at the address it is linked at.
                // I've cloned the print and thread macros here to ensure this doesn't
                // break if the implementation of those changes.

                // Print message
                lea s0, message
                load_const s1, 0xffff0040   // Load address of serial registers
1:              load_u8 s2, (s0)            // Read a character
                bfalse s2, 3f               // If delimeter, exit
2:              load_32 s3, (s1)            // Read UART STATUS
                and s3, s3, 1               // Check write available bit
                bfalse s3, 2b               // If this is clear, busy wait
                store_32 s2, 8(s1)          // Write space available, send char
                add_i s0, s0, 1             // Increment pointer
                goto 1b                     // Loop for next char
3:
                // Exit simulation
                move s0, -1
                shl s0, s0, 16
                or s0, s0, 0x104
                move s1, -1
	            store_32 s1, (s0)
1:	            goto 1b

message:        .asciz "PASS"
