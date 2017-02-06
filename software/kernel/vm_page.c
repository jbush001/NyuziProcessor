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

#include "libc.h"
#include "memory_map.h"
#include "spinlock.h"
#include "trap.h"
#include "vm_page.h"
#include "vm_translation_map.h"

static spinlock_t page_lock;
extern int boot_pages_used;

// Space is preallocated at the front of the kernel heap for page structures.
// This is necessary because of the circular dependency on page stuctures
// to grow the heap.
static struct vm_page *pages = (struct vm_page*) KERNEL_HEAP_BASE;
static struct list_node free_page_list;
unsigned int memory_size;

void vm_page_init(unsigned int memory)
{
    int num_pages = memory / PAGE_SIZE;
    int pgidx;

    memory_size = memory;

    // Set up the free page list
    list_init(&free_page_list);
    for (pgidx = boot_pages_used; pgidx < num_pages - 1; pgidx++)
    {
        pages[pgidx].busy = 0;
        pages[pgidx].cache = 0;
        list_add_tail(&free_page_list, &pages[pgidx]);
    }
}

struct vm_page *vm_allocate_page(void)
{
    struct vm_page *page;
    unsigned int pa;
    int old_flags;

    old_flags = disable_interrupts();
    acquire_spinlock(&page_lock);
    page = list_remove_head(&free_page_list, struct vm_page);
    if (page == 0)
        panic("Out of memory!");

    page->busy = 0;
    page->cache = 0;
    page->dirty = 0;
    page->ref_count = 1;
    release_spinlock_int(&page_lock, old_flags);

    pa = (page - pages) * PAGE_SIZE;

    memset((void*) PA_TO_VA(pa), 0, PAGE_SIZE);

    return page;
}

void inc_page_ref(struct vm_page *page)
{
    __sync_fetch_and_add(&page->ref_count, 1);
}

void dec_page_ref(struct vm_page *page)
{
    int old_flags;

    assert(page->ref_count > 0);
    if (__sync_fetch_and_add(&page->ref_count, -1) == 1)
    {
        VM_DEBUG("freeing page pa %08x\n", page_to_pa(page));
        old_flags = acquire_spinlock_int(&page_lock);
        list_add_head(&free_page_list, page);
        release_spinlock_int(&page_lock, old_flags);
    }
}

struct vm_page *pa_to_page(unsigned int addr)
{
    assert(addr < memory_size);
    return &pages[addr / PAGE_SIZE];
}

unsigned int page_to_pa(const struct vm_page *page)
{
    return (page - pages) * PAGE_SIZE;
}

unsigned int allocate_contiguous_memory(unsigned int size)
{
    const unsigned int page_count = (size + PAGE_SIZE - 1) / PAGE_SIZE;
    const unsigned int total_pages = memory_size / PAGE_SIZE;
    unsigned int base_index = 0;
    unsigned int page_offset;
    int found_run;
    int old_flags;

    old_flags = acquire_spinlock_int(&page_lock);

    // Find free range
    do
    {
        // Scan for first free page
        while (pages[base_index].ref_count > 0)
        {
            if (base_index == total_pages - page_count)
            {
                release_spinlock_int(&page_lock, old_flags);
                return 0xffffffff;  // No free range
            }

            base_index++;
        }

        // Check if range is free
        found_run = 1;
        for (page_offset = 1; page_offset < page_count; page_offset++)
        {
            if (pages[base_index + page_offset].ref_count > 0)
            {
                base_index += page_offset + 1;
                found_run = 0;
                break;
            }
        }
    }
    while (!found_run);

    // Mark range as allocated
    for (page_offset = 0; page_offset < page_count; page_offset++)
    {
        pages[base_index + page_offset].ref_count = 1;
        list_remove_node(&pages[base_index + page_offset]);
    }

    release_spinlock_int(&page_lock, old_flags);

    return base_index * PAGE_SIZE;
}
