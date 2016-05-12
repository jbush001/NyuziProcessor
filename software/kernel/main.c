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
#include "vm.h"

struct linked_node
{
    struct linked_node *next;
    int value;
    int stuff[16];
};

void context_switch(unsigned int **old_stack_ptr_ptr,
                    unsigned int *new_stack_ptr,
                    unsigned int new_page_dir_addr,
                    unsigned int new_address_space_id);

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

void test_translation_map(void)
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

    switch_to_translation_map(map1);
    *((volatile unsigned int*) 0x10000000) = 0xdeadbeef;
    *((volatile unsigned int*) 0x10001000) = 0x12345678;
    switch_to_translation_map(map2);
    kprintf("1: %08x\n",  *((volatile unsigned int*) 0x10000000));  // Should be 0
    kprintf("2: %08x\n",  *((volatile unsigned int*) 0x20000000));  // Should be 0x12345678
    switch_to_translation_map(map1);
    kprintf("1: %08x\n",  *((volatile unsigned int*) 0x10000000));  // Should be 0xdeadbeef
    kprintf("2: %08x\n",  *((volatile unsigned int*) 0x10001000));  // Should be 0x12345678
    switch_to_translation_map(map2);

    destroy_translation_map(map1);
}

void test_trap(void)
{
    *((unsigned int*) 1) = 1; // Cause fault
}

struct thread th_a;
struct thread th_b;

void thread_funca()
{
    while (1)
    {
        kprintf("A");
        switch_to_thread(&th_b);
    }
}

void thread_funcb()
{
    while (1)
    {
        kprintf("B");
        switch_to_thread(&th_a);
    }
}

void test_context_switch(void)
{
    struct vm_translation_map *map = new_translation_map();

    // Set up thread A
    boot_init_thread(&th_a);
    th_a.map = map;

    // Set up thread B
    th_b.current_stack = (unsigned int*) kmalloc(0x2000) + 0x2000 - 0x840;
    ((unsigned int*) th_b.current_stack)[0x814 / 4] = (unsigned int) thread_funcb;
    kprintf("thread start address is %08x\n", &((unsigned int*) th_b.current_stack)[0x808 / 4]);
    th_b.map = map;

    thread_funca();
}

void kernel_main(void)
{
    vm_init();
    kprintf("Hello kernel land\n");

#if 0
    test_slab();
    test_translation_map();
    *((volatile unsigned int*) 0xffff0100) = 0xffffffff;
    test_trap();
#else
    test_context_switch();
#endif

    for (;;)
        ;
}

void thread_n_main(void)
{
    kprintf("%c", __builtin_nyuzi_read_control_reg(0) + 'A');
    for (;;)
        ;
}

