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
#include "slab.h"
#include "thread.h"
#include "vm_page.h"
#include "vm_translation_map.h"

struct linked_node
{
    struct linked_node *next;
    int value;
    int stuff[16];
};

MAKE_SLAB(node_slab, struct linked_node);

void test_slab(void)
{
    int i;
    int j;
    struct linked_node *node;
    struct linked_node *list = 0;

    for (j = 1; j < 128; j++)
    {
        // Allocate a bunch of nodes
        for (i = 0; i < j; i++)
        {
            node = (struct linked_node*) slab_alloc(&node_slab);
            node->next = list;
            list = node;
            node->value = j;
        }

        // Free all but one
        for (i = 0; i < j - 1; i++)
        {
            node = list;
            list = list->next;
            slab_free(&node_slab, node);
        }
    }

    for (node = list; node; node = node->next)
        kprintf("%d ", node->value);

    kprintf("\n");
}

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
    struct vm_translation_map *map1;
    struct vm_translation_map *map2;
    unsigned int page1;
    unsigned int page2;
    unsigned int page3;

    page1 = vm_allocate_page();
    page2 = vm_allocate_page();
    page3 = vm_allocate_page();
    map1 = new_translation_map();
    map2 = new_translation_map();

    // Cache homonym: same virtual address points to two different
    // physical addresses
    vm_map_page(map1, 0x10000000, page1 | PAGE_PRESENT | PAGE_WRITABLE);
    vm_map_page(map2, 0x10000000, page3 | PAGE_PRESENT | PAGE_WRITABLE);

    // Cache synonym: different virtual addresses point to the same
    // physical address
    vm_map_page(map1, 0x10001000, page2 | PAGE_PRESENT | PAGE_WRITABLE);
    vm_map_page(map2, 0x20000000, page2 | PAGE_PRESENT | PAGE_WRITABLE);

    // Current thread
    boot_init_thread(map1);

    // Create a new thread
    spawn_thread(map2, thread_funcb, 0);

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

void kernel_main(void)
{
    vm_page_init();
    vm_translation_map_init();
    kprintf("Kernel started\n");

#if 0
    test_slab();
    *((volatile unsigned int*) 0xffff0100) = 0xffffffff;
    test_trap();
#endif

#if 0
    test_context_switch();
#endif

    exec_program("program.elf");

    boot_init_thread(new_translation_map());

    for (;;)
        reschedule();
}

void thread_n_main(void)
{
    kprintf("%c", __builtin_nyuzi_read_control_reg(0) + 'A');
    for (;;)
        ;
}

