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
// Verify a TLB miss in the middle of another fault works correctly
// Specifically that it saves the fault state and restores it on eret.
//

                .globl _start
_start:         load_tlb_entries itlb_entries, dtlb_entries

                // Set up fault handlers
                lea s0, handle_fault
                setcr s0, CR_TRAP_HANDLER
                lea s0, handle_tlb_miss
                setcr s0, CR_TLB_MISS_HANDLER

                // Enable MMU
                move s0, FLAG_MMU_EN | FLAG_SUPERVISOR_EN
                setcr s0, CR_FLAGS
                flush_pipeline

                // Set up vector pointers
                load_v v1, vecptr
align_fault_loc: store_scat v0, (v1) // This will fault when it hits address 17 and call handle_fault

                should_not_get_here

                .align 64, 0xff
vecptr:         .long 0x3000, 0x3000, 0x3000, 0x3000, 0x3000, 0x3000, 0x3000, 0x1017, 0x3000, 0x3000, 0x3000, 0x3000, 0x3000, 0x3000, 0x3000, 0x3000


//
// This handles the first alignment fault
//
handle_fault:   load_const s10, 0x88cf70b4
                setcr s10, CR_SCRATCHPAD0
                load_const s10, 0x78662516
                setcr s10, CR_SCRATCHPAD1

                // Note: use a register that won't be clobbered in the
                // TLB miss handler.
                load_const s11, 0x2000
tlb_miss_loc:   store_32 s11, (s11)     // This will cause a TLB miss the first time

                // We have returned from the TLB miss here. Ensure the
                // fault control registers were restored
                getcr s10, CR_TRAP_CAUSE
                assert_reg s10, TT_UNALIGNED_ACCESS | TRAP_CAUSE_DCACHE | TRAP_CAUSE_STORE
                getcr s10, CR_TRAP_ADDRESS
                assert_reg s10, 0x1017
                getcr s10, CR_SCRATCHPAD0
                assert_reg s10, 0x88cf70b4
                getcr s10, CR_SCRATCHPAD1
                assert_reg s10, 0x78662516
                getcr s10, CR_SUBCYCLE
                assert_reg s10, 7
                getcr s10, CR_FLAGS
                assert_reg s10, 6

                lea s25, align_fault_loc
                getcr s26, CR_TRAP_PC
                cmpeq_i s25, s25, s26
                btrue s25, 1f
                call fail_test
1:
                call pass_test


//
// This handles the nested trap
//
handle_tlb_miss:
                // Clobber some control registers. When this returns,
                // handle_fault will ensure the previous value is restored
                move s10, 0
                setcr s10, CR_SCRATCHPAD0
                setcr s10, CR_SCRATCHPAD1
                setcr s10, CR_SUBCYCLE

                // Check fault
                getcr s26, CR_TRAP_CAUSE
                assert_reg s26, TT_TLB_MISS | TRAP_CAUSE_DCACHE | TRAP_CAUSE_STORE
                getcr s26, CR_TRAP_ADDRESS
                assert_reg s26, 0x2000

                lea s25, tlb_miss_loc
                getcr s26, CR_TRAP_PC
                cmpeq_i s25, s25, s26
                btrue s25, 1f
                call fail_test
1:

                // Update TLB
                load_const s26, 0x2000
                load_const s27, 0x2000 | TLB_PRESENT | TLB_WRITABLE
                dtlbinsert s26, s27
                eret


itlb_entries:   .long 0x00001000, 0x00001000 | TLB_PRESENT | TLB_EXECUTABLE
                .long 0xffffffff, 0xfffffff

dtlb_entries:   .long 0x00001000, 0x00001000 | TLB_PRESENT
                .long 0x00003000, 0x00003000 | TLB_PRESENT | TLB_WRITABLE   // writes to this page
                .long 0xffff0000, 0xffff0000 | TLB_PRESENT | TLB_WRITABLE    // I/O area
                .long 0xffffffff, 0xffffffff
