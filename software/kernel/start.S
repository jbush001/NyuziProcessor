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

#define MEMORY_SIZE 0x1000000

                    .globl _start
_start:             getcr s0, 0
                    bnz s0, start_thread_n

                    // The temporary stack is only used while calling
                    // boot_setup_page_tables. As soon as that returns,
                    // this memory will not be touched again and can be
                    // used for other things.
                    li sp, 0x400000                 # Temporary stack
                    li s0, MEMORY_SIZE
                    call boot_setup_page_tables

                    // Set up TLB miss handler. This is a physical address, so need
                    // to mask off virtual address to convert.
                    lea s0, tlb_miss_handler
                    li s1, 0xffffff
                    and s0, s0, s1      // Mask off high bits
                    setcr s0, CR_TLB_MISS_HANDLER

                    // Set up normal trap handler
                    lea s0, trap_entry
                    setcr s0, CR_TRAP_HANDLER

                    // Set up entry address for trampoline
                    lea s0, kernel_main
                    setcr s0, CR_TRAP_PC
                    b trampoline

start_thread_n:     // Set up entry address for trampoline
                    lea s0, thread_n_main
                    setcr s0, CR_TRAP_PC

                    // Need to simultaneously enable the MMU and change the PC
                    // to the new kernel address in high virtual memory. Use
                    // eret as a trampoline to do this.
trampoline:         lea s0, page_dir_addr

                    // Convert to physical address
                    li s1, 0xffffff
                    and s0, s0, s1      // Mask off high bits

                    load_32 s0, (s0)   // Set up page directory
                    setcr s0, CR_PAGE_DIR_BASE
                    move s0, (FLAG_MMU_EN | FLAG_SUPERVISOR_EN | FLAG_INTERRUPT_EN)
                    setcr s0, CR_SAVED_FLAGS

                    // Set up new stack address in virtual memory
                    getcr s0, CR_CURRENT_HW_THREAD // get my thread ID
                    shl s0, s0, 14              // 16k bytes per stack
                    li sp, 0xffff0000           // Kernel stack base
                    sub_i sp, sp, s0            // Compute stack address

                    li s0, MEMORY_SIZE

                    // Go!
                    eret


                    .data
                    .globl page_dir_addr
                    .globl boot_pages_used

page_dir_addr:      .long 0         // Filled in during boot by VM code
boot_pages_used:    .long 0         // Ditto
