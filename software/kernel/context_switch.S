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
// Push registers onto the current kernel stack, switch to a new stack, and pop
// the registers from the new thread off the stack.
//
// void context_switch(unsigned int **old_stack_ptr_ptr,
//                     unsigned int *new_stack_ptr)
//

                    .global context_switch
                    .type context_switch,@function
context_switch:     sub_i sp, sp, 0x840

                    // This must save and restore *all* vector registers,
                    // because they are not used in the kernel and are not
                    // saved by the trap handler.
                    store_v v0,  0(sp)
                    store_v v1,  0x40(sp)
                    store_v v2,  0x80(sp)
                    store_v v3,  0xc0(sp)
                    store_v v4,  0x100(sp)
                    store_v v5,  0x140(sp)
                    store_v v6,  0x180(sp)
                    store_v v7,  0x1c0(sp)
                    store_v v8,  0x200(sp)
                    store_v v9,  0x240(sp)
                    store_v v10, 0x280(sp)
                    store_v v11, 0x2c0(sp)
                    store_v v12, 0x300(sp)
                    store_v v13, 0x340(sp)
                    store_v v14, 0x380(sp)
                    store_v v15, 0x3c0(sp)
                    store_v v16, 0x400(sp)
                    store_v v17, 0x440(sp)
                    store_v v18, 0x480(sp)
                    store_v v19, 0x4c0(sp)
                    store_v v20, 0x500(sp)
                    store_v v21, 0x540(sp)
                    store_v v22, 0x580(sp)
                    store_v v23, 0x5c0(sp)
                    store_v v24, 0x600(sp)
                    store_v v25, 0x640(sp)
                    store_v v26, 0x680(sp)
                    store_v v27, 0x6c0(sp)
                    store_v v28, 0x700(sp)
                    store_v v29, 0x740(sp)
                    store_v v30, 0x780(sp)
                    store_v v31, 0x7c0(sp)

                    // Only need to save callee-saved scalar registers on the
                    // stack. The calling function(s) have already saved all
                    // caller-saved registers if needed.
                    store_32 s24, 0x800(sp)
                    store_32 s25, 0x804(sp)
                    store_32 s26, 0x808(sp)
                    store_32 s27, 0x80c(sp)
                    store_32 s28, 0x810(sp)
                    store_32 fp,  0x814(sp)
                    store_32 ra,  0x818(sp)

                    // Swap stacks
                    store_32 sp, (s0)   // Save old stack
                    move sp, s1         // Load new stack

                    // Restore vector registers from new stack
                    load_v v0,  0(sp)
                    load_v v1,  0x40(sp)
                    load_v v2,  0x80(sp)
                    load_v v3,  0xc0(sp)
                    load_v v4,  0x100(sp)
                    load_v v5,  0x140(sp)
                    load_v v6,  0x180(sp)
                    load_v v7,  0x1c0(sp)
                    load_v v8,  0x200(sp)
                    load_v v9,  0x240(sp)
                    load_v v10, 0x280(sp)
                    load_v v11, 0x2c0(sp)
                    load_v v12, 0x300(sp)
                    load_v v13, 0x340(sp)
                    load_v v14, 0x380(sp)
                    load_v v15, 0x3c0(sp)
                    load_v v16, 0x400(sp)
                    load_v v17, 0x440(sp)
                    load_v v18, 0x480(sp)
                    load_v v19, 0x4c0(sp)
                    load_v v20, 0x500(sp)
                    load_v v21, 0x540(sp)
                    load_v v22, 0x580(sp)
                    load_v v23, 0x5c0(sp)
                    load_v v24, 0x600(sp)
                    load_v v25, 0x640(sp)
                    load_v v26, 0x680(sp)
                    load_v v27, 0x6c0(sp)
                    load_v v28, 0x700(sp)
                    load_v v29, 0x740(sp)
                    load_v v30, 0x780(sp)
                    load_v v31, 0x7c0(sp)

                    // Restore callee-saved scalar registers
                    load_32 s24, 0x800(sp)
                    load_32 s25, 0x804(sp)
                    load_32 s26, 0x808(sp)
                    load_32 s27, 0x80c(sp)
                    load_32 s28, 0x810(sp)
                    load_32 fp,  0x814(sp)
                    load_32 ra,  0x818(sp)
                    add_i sp, sp, 0x840

                    ret

