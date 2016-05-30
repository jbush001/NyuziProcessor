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
#include "kernel_heap.h"
#include "libc.h"
#include "registers.h"
#include "slab.h"
#include "thread.h"
#include "trap.h"
#include "vm_area_map.h"
#include "vm_page.h"
#include "vm_translation_map.h"
#include "vm_address_space.h"

void test_trap(void)
{
    *((unsigned int*) 1) = 1; // Cause fault
}

void thread_funcb()
{
    // Assign homonym page to ensure it is separate from the one
    // in the other address space
    *((volatile unsigned int*) 0x10000000) = 0x12345678;
    while (1)
    {
        kprintf("funcb: %08x %08x\n",  *((volatile unsigned int*) 0x10000000),
                *((volatile unsigned int*) 0x20000000));  // Should be 0x12345678 <counter>
        reschedule();
    }
}

void test_context_switch(void)
{
    struct vm_address_space *space1;
    struct vm_address_space *space2;
    unsigned int page1;
    unsigned int page2;
    unsigned int page3;

    page1 = vm_allocate_page();
    page2 = vm_allocate_page();
    page3 = vm_allocate_page();
    space1 = create_address_space();
    space2 = create_address_space();

    // Cache homonym: same virtual address points to two different
    // physical addresses
    vm_map_page(space1->translation_map, 0x10000000, page1 | PAGE_PRESENT | PAGE_WRITABLE);
    vm_map_page(space2->translation_map, 0x10000000, page3 | PAGE_PRESENT | PAGE_WRITABLE);

    // Cache synonym: different virtual addresses point to the same
    // physical address
    vm_map_page(space1->translation_map, 0x10001000, page2 | PAGE_PRESENT | PAGE_WRITABLE);
    vm_map_page(space2->translation_map, 0x20000000, page2 | PAGE_PRESENT | PAGE_WRITABLE);

    // Create a new thread
    spawn_kernel_thread(space2, thread_funcb, 0);

    // Need to context switch to set up new address space
    reschedule();

    // In map1. Assign homonym address to ensure it doesn't show up in
    // other address space.
    *((volatile unsigned int*) 0x10000000) = 0xdeadbeef;

    while (1)
    {
        kprintf("funca: %08x\n",  *((volatile unsigned int*) 0x10000000));
        // Should be 0xdeadbeef

        // Increment counter in synonym page
        (*((volatile unsigned int*) 0x10001000))++;
        reschedule();
    }
}

#define TIMER_INTERVAL 500000

void start_timer(void)
{
    REGISTERS[REG_TIMER_INTERVAL] = TIMER_INTERVAL;
}

void timer_tick(void)
{
    kprintf(".");
    REGISTERS[REG_TIMER_INTERVAL] = TIMER_INTERVAL;
    ack_interrupt(1);
}

void kernel_main(void)
{
    struct vm_translation_map *init_map;

    vm_page_init();
    init_map = vm_translation_map_init();
    boot_init_heap((char*) KERNEL_HEAP_BASE + PAGE_STRUCTURES_SIZE);
    vm_address_space_init(init_map);
    boot_init_thread();
    kprintf("Kernel started\n");
    dump_area_map(&get_kernel_address_space()->area_map);

#if 0
    test_area_map();
#endif

    register_interrupt_handler(1, timer_tick);
    start_timer();

#if 0
    test_slab();
    *((volatile unsigned int*) 0xffff0100) = 0xffffffff;
    test_trap();
#endif

#if 0
    test_context_switch();
#endif

    exec_program("program.elf");

    for (;;)
        reschedule();
}

void thread_n_main(void)
{
    kprintf("%c", __builtin_nyuzi_read_control_reg(0) + 'A');
    for (;;)
        ;
}

