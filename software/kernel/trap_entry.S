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

#include "asm_macros.inc"

//
// General trap handler. This saves all scalar registers, but does not save
// vector registers. This means the kernel cannot use vector registers and
// must save them on context switch.
//

.set IFRAME_SIZE, 192

                        .globl trap_entry
                        .type trap_entry, @function
trap_entry:             sub_i sp, sp, IFRAME_SIZE
                        store_32 s0, 0(sp)
                        store_32 s1, 4(sp)
                        store_32 s2, 8(sp)
                        store_32 s3, 12(sp)
                        store_32 s4, 16(sp)
                        store_32 s5, 20(sp)
                        store_32 s6, 24(sp)
                        store_32 s7, 28(sp)
                        store_32 s8, 32(sp)
                        store_32 s9, 36(sp)
                        store_32 s10, 40(sp)
                        store_32 s11, 44(sp)
                        store_32 s12, 48(sp)
                        store_32 s13, 52(sp)
                        store_32 s14, 56(sp)
                        store_32 s15, 60(sp)
                        store_32 s16, 64(sp)
                        store_32 s17, 68(sp)
                        store_32 s18, 72(sp)
                        store_32 s19, 76(sp)
                        store_32 s20, 80(sp)
                        store_32 s21, 84(sp)
                        store_32 s22, 88(sp)
                        store_32 s23, 92(sp)
                        store_32 s24, 96(sp)
                        store_32 s25, 100(sp)
                        store_32 s26, 104(sp)
                        store_32 s27, 108(sp)
                        store_32 fp, 112(sp)
                        # Stack pointer slot is unused
                        store_32 ra, 120(sp)

                        getcr s0, 2
                        store_32 s0, 124(sp)   # Saved PC
                        getcr s0, 8
                        store_32 s0, 128(sp)   # Saved flags
                        getcr s0, 13
                        store_32 s0, 132(sp)   # Subcycle

                        move s0, sp

                        call handle_trap

                        load_32 s1, 4(sp)
                        load_32 s2, 8(sp)
                        load_32 s3, 12(sp)
                        load_32 s4, 16(sp)
                        load_32 s5, 20(sp)
                        load_32 s6, 24(sp)
                        load_32 s7, 28(sp)
                        load_32 s8, 32(sp)
                        load_32 s9, 36(sp)
                        load_32 s10, 40(sp)
                        load_32 s11, 44(sp)
                        load_32 s12, 48(sp)
                        load_32 s13, 52(sp)
                        load_32 s14, 56(sp)
                        load_32 s15, 60(sp)
                        load_32 s16, 64(sp)
                        load_32 s17, 68(sp)
                        load_32 s18, 72(sp)
                        load_32 s19, 76(sp)
                        load_32 s20, 80(sp)
                        load_32 s21, 84(sp)
                        load_32 s22, 88(sp)
                        load_32 s23, 92(sp)
                        load_32 s24, 96(sp)
                        load_32 s25, 100(sp)
                        load_32 s26, 104(sp)
                        load_32 s27, 108(sp)
                        load_32 fp, 112(sp)
                        load_32 ra, 120(sp)

                        load_32 s0, 124(sp)   # Saved PC
                        setcr s0, 2
                        load_32 s0, 128(sp)   # Saved flags
                        setcr s0, 8
                        load_32 s0, 132(sp)   # Subcycle
                        setcr s0, 13
                        load_32 s0, 0(sp)
                        add_i sp, sp, IFRAME_SIZE
                        eret

//
// TLB miss handler. This is invoked with the MMU disabled.
//
// Virtual address format:
// +--------------------+--------------------+------------------------+
// |  pgdir index (10)  |  pgtbl index (10)  |    page offset (12)    |
// +--------------------+--------------------+------------------------+
//
// Page directory entry:
// +----------------------------------------+-----------------------+-+
// |         page table address (20)        |       unused (9)      |P|
// +----------------------------------------+-----------------------+-+
//
// Page table entry:
// +----------------------------------------+---------------+---------+
// |            page address (20)           |   unused (5)  |G S X W P|
// +----------------------------------------+---------------+---------+
//  G - Global
//  S - Supervisor
//  X - Executable
//  W - Writable
//  P - Present
//

                    .globl tlb_miss_handler
tlb_miss_handler:   setcr s0, CR_SCRATCHPAD0    // Save s0 in scratchpad
                    setcr s1, CR_SCRATCHPAD1    // Same for s1

                    getcr s1, CR_PAGE_DIR_BASE  // Read page dir phys addr

                    // Read page directory
                    getcr s0, CR_TRAP_ADDRESS   // Get fault virtual address
                    shr s0, s0, 22              // Convert to page directory index
                    shl s0, s0, 2               // Multiply offset by 4 (bytes/entry)
                    add_i s0, s0, s1            // Pointer to page directory entry
                    load_32 s0, (s0)            // Read page directory entry
                    and s1, s0, 1               // Is present bit set?
                    bfalse s1, pte_not_present  // No page table
                    shr s0, s0, 12              // Mask off all low bits to get rounded PTE base
                    shl s0, s0, 12

                    // Read page table
                    getcr s1, CR_TRAP_ADDRESS   // Get fault virtual address
                    shr s1, s1, 12              // Convert to page table index
                    and s1, s1, 1023            // Mask off page directory index
                    shl s1, s1, 2               // Multiply by 4 (bytes/entry)
                    add_i s1, s1, s0            // Pointer to page table entry
                    load_32 s0, (s1)            // Read page table entry value

                    // Update TLB
update_tlb:         getcr s1, CR_TRAP_REASON    // Get fault reason
                    cmpeq_i s1, s1, FR_ITLB_MISS // ITLB miss?
                    btrue s1, fill_itlb          // If yes, branch to update ITLB

fill_dltb:          getcr s1, CR_TRAP_ADDRESS   // Get fault virtual address
                    dtlbinsert s1, s0           // Set virtual address for DTLB
                    goto done

fill_itlb:          getcr s1, CR_TRAP_ADDRESS   // Get fault virtual address
                    itlbinsert s1, s0           // Set virtual address for ITLB

done:               getcr s0, CR_SCRATCHPAD0    // Get saved s0 from scratchpad
                    getcr s1, CR_SCRATCHPAD1    // Get saved s1
                    eret

pte_not_present:    move s0, 0                  // Null entry (present bit not set)
                    goto update_tlb             // Insert this into TLB
