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
#include "libc.h"
#include "vm.h"

// XXX need a global variable for _end to be emitted correctly.
int foo;

void kernel_main()
{
    vm_init();

    kprintf("Hello kernel land\n");

    // Map a page, then read and write to it
    vm_map_page(0xd0000000, vm_allocate_page() | PAGE_PRESENT | PAGE_WRITABLE
                | PAGE_SUPERVISOR | PAGE_GLOBAL);
    *((volatile unsigned int*) 0xd0000000) = 0xabcdef12;
    kprintf("%08x\n", *((volatile unsigned int*) 0xd0000000));

    // Start other threads
    *((volatile unsigned int*) 0xffff0100) = 0xffffffff;

//    *((unsigned int*) 1) = 1; // Cause fault
    for (;;)
        ;
}

void thread_n_main()
{
    kprintf("%d", __builtin_nyuzi_read_control_reg(0));
    for (;;)
        ;
}

