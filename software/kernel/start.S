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

#include "asm.h"

//
// Execution of the kernel begins at _start. Thread 0 sets up some memory management
// structures, turns on the MMU, then jumps to kernel_main. Other threads bypass
// that and jump directly to main.
//

                    .globl _start
_start:             getcr s0, 0
                    btrue s0, start_thread_n

                    load_32 sp, temp_stack
                    load_32 s0, memory_size
                    call boot_setup_page_tables

                    // Set up TLB miss handler. This is a physical address, so need
                    // to mask off virtual address to convert.
                    load_32 s0, tlb_miss_addr
                    move s1, -1
                    shr s1, s1, 8       // Generate mask for low 24 bits
                    and s0, s0, s1      // Mask off high bits
                    setcr s0, CR_TLB_MISS_HANDLER

                    // Set up normal trap handler
                    load_32 s0, trap_entry_addr
                    setcr s0, CR_TRAP_HANDLER

                    // Set up entry address for trampoline
                    load_32 s0, kernel_main_addr
                    setcr s0, CR_TRAP_PC
                    goto trampoline

start_thread_n:     // Set up entry address for trampoline
                    load_32 s0, thread_n_main_addr
                    setcr s0, CR_TRAP_PC

                    // Need to simultaneously enable the MMU and change the PC
                    // to the new kernel address in high virtual memory. Use
                    // eret as a trampoline to do this.
trampoline:         load_32 s0, page_dir_addr   // Set up page directory
                    setcr s0, CR_PAGE_DIR_BASE
                    move s0, (FLAG_MMU_EN | FLAG_SUPERVISOR_EN | FLAG_INTERRUPT_EN)
                    setcr s0, CR_SAVED_FLAGS

                    // Set up new stack address in virtual memory
                    getcr s0, CR_CURRENT_HW_THREAD // get my thread ID
                    shl s0, s0, 14              // 16k bytes per stack
                    load_32 sp, kernel_stacks
                    sub_i sp, sp, s0            // Compute stack address

                    load_32 s0, memory_size

                    // Go!
                    eret

                    .globl page_dir_addr
                    .globl boot_pages_used

// temp_stack is only used while calling boot_setup_page_tables. As soon as that returns,
// this memory will not be touched again and can be used for other things.
temp_stack:         .long 0x400000
memory_size:        .long 0x1000000 // XXX hardcoded
page_dir_addr:      .long 0         // Filled in during boot by VM code
boot_pages_used:    .long 0         // Ditto
kernel_main_addr:   .long kernel_main
kernel_stacks:      .long 0xffff0000
tlb_miss_addr:      .long tlb_miss_handler
trap_entry_addr:    .long trap_entry
thread_n_main_addr: .long thread_n_main
