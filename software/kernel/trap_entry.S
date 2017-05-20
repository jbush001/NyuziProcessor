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

#include "asm.h"

#define IFRAME_SIZE 192
#define IFRAME_SP_OFFSET 120
#define IFRAME_PC_OFFSET 128

//
// General trap handler. This saves all scalar registers, but does not save
// vector registers. This means the kernel cannot use vector registers and
// must save them on context switch.
//

                        .globl trap_entry
                        .type trap_entry, @function
trap_entry:             setcr s0, CR_SCRATCHPAD0        // Save s0 in scratchpad
                        setcr s1, CR_SCRATCHPAD1        // Save s1 in scratchpad

                        getcr s0, CR_SAVED_FLAGS        // Get old flags
                        and s0, s0, FLAG_SUPERVISOR_EN  // Was in supervisor mode?
                        bnz s0, is_supervisor

                        // Need to switch to kernel stack. First, find the
                        // current thread for this hardware thread.
                        getcr s0, CR_CURRENT_HW_THREAD  // Current hardware thread
                        shl s0, s0, 2                   // Multiply by 4 (bytes/entry)
                        lea s1, trap_kernel_stack_addr
                        load_32 s1, (s1)                // Get base of array
                        add_i s1, s1, s0                // Find element ptr
                        load_32 s1, (s1)                // Get kernel_stack pointer
                        store_32 sp, IFRAME_SP_OFFSET - IFRAME_SIZE(s1) // Save user stack
                        move sp, s1                     // switch stacks
                        b save_frame

                        // Already in kernel mode. Don't need to switch stacks, just
                        // decrement pointer
is_supervisor:          store_32 sp, IFRAME_SP_OFFSET - IFRAME_SIZE(sp)   // save old stack

                        // Save remaining registers
save_frame:             getcr s0, CR_SCRATCHPAD0        // restore s0
                        getcr s1, CR_SCRATCHPAD1        // restore s1
                        sub_i sp, sp, IFRAME_SIZE       // Reserve space for iframe

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
                        store_32 s28, 112(sp)
                        // sp was already saved at 114 on entry
                        store_32 fp, 116(sp)
                        store_32 ra, 124(sp)

                        getcr s0, CR_TRAP_PC
                        store_32 s0, IFRAME_PC_OFFSET(sp)
                        getcr s0, CR_SAVED_FLAGS
                        store_32 s0, 132(sp)
                        getcr s0, CR_SAVED_SUBCYCLE
                        store_32 s0, 136(sp)

                        move s0, sp  // pointer to iframe is argument to handle_trap

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
                        load_32 s28, 112(sp)
                        load_32 fp, 116(sp)
                        load_32 ra, 124(sp)

                        load_32 s0, IFRAME_PC_OFFSET(sp)
                        setcr s0, CR_TRAP_PC    // eret will jump to here
                        load_32 s0, 132(sp)
                        setcr s0, CR_SAVED_FLAGS
                        load_32 s0, 136(sp)
                        setcr s0, CR_SAVED_SUBCYCLE
                        load_32 s0, 0(sp)    // Restore s0
                        load_32 sp, IFRAME_SP_OFFSET(sp) // Restore old stack pointer
                        eret

trap_kernel_stack_addr: .long trap_kernel_stack


//
// Jump to a user mode task.
//
//  void jump_to_user_mode(int argc, void *argv, unsigned int inital_pc,
//      unsigned int user_stack_ptr);
//
// Use eret to simultaneously jump to PC and switch modes.
//

                        .globl jump_to_user_mode
jump_to_user_mode:      setcr s2, CR_TRAP_PC        // Address to jump to.
                        move s10, FLAG_MMU_EN | FLAG_INTERRUPT_EN
                        setcr s10, CR_SAVED_FLAGS
                        move sp, s3
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
                    getcr s0, CR_TRAP_ADDR      // Get fault virtual address
                    shr s0, s0, 22              // Convert to page directory index
                    shl s0, s0, 2               // Multiply offset by 4 (bytes/entry)
                    add_i s0, s0, s1            // Pointer to page directory entry
                    load_32 s0, (s0)            // Read page directory entry
                    and s1, s0, 1               // Is present bit set?
                    bz s1, pte_not_present      // No page table
                    shr s0, s0, 12              // Mask off all low bits to get rounded PTE base
                    shl s0, s0, 12

                    // Read page table
                    getcr s1, CR_TRAP_ADDR      // Get fault virtual address
                    shr s1, s1, 12              // Convert to page table index
                    and s1, s1, 1023            // Mask off page directory index
                    shl s1, s1, 2               // Multiply by 4 (bytes/entry)
                    add_i s1, s1, s0            // Pointer to page table entry
                    load_32 s0, (s1)            // Read page table entry value

                    // Update TLB
update_tlb:         getcr s1, CR_TRAP_CAUSE     // Get fault reason
                    and s1, s1, 0x20            // Is DTLB miss?
                    bz s1, fill_itlb            // If no, branch to update ITLB

fill_dltb:          getcr s1, CR_TRAP_ADDR      // Get fault virtual address
                    dtlbinsert s1, s0           // Set virtual address for DTLB
                    b done

fill_itlb:          getcr s1, CR_TRAP_ADDR      // Get fault virtual address
                    itlbinsert s1, s0           // Set virtual address for ITLB

done:               getcr s0, CR_SCRATCHPAD0    // Get saved s0 from scratchpad
                    getcr s1, CR_SCRATCHPAD1    // Get saved s1
                    eret

pte_not_present:    move s0, 0                  // Null entry (present bit not set)
                    b update_tlb                // Insert this into TLB


                    .globl disable_interrupts
disable_interrupts: getcr s0, CR_FLAGS
                    and s1, s0, FLAG_MMU_EN | FLAG_SUPERVISOR_EN
                    setcr s1, CR_FLAGS
                    ret

                    .globl enable_interrupts
enable_interrupts:  getcr s0, CR_FLAGS
                    or s1, s0, FLAG_INTERRUPT_EN
                    setcr s1, CR_FLAGS
                    ret

                    .globl restore_interrupts
restore_interrupts: setcr s0, CR_FLAGS
                    ret
