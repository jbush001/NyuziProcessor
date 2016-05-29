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

static unsigned int next_alloc_page;
static spinlock_t page_lock;
extern int boot_pages_used;

// Space is preallocated at the front of the kernel heap for page structures.
// This is necessary because of the circular dependency on page stuctures
// to grow the heap.
static struct vm_page *pages = (struct vm_page*) KERNEL_HEAP_BASE;
static struct vm_page *free_page_list;

void vm_page_init(void)
{
    int num_pages = MEMORY_SIZE / PAGE_SIZE;
    int pgidx;

    // Set up the free page list
    for (pgidx = boot_pages_used; pgidx < num_pages - 1; pgidx++)
        pages[pgidx].next = &pages[pgidx + 1];

    pages[num_pages - 1].next = 0;
    free_page_list = &pages[boot_pages_used];
}

unsigned int vm_allocate_page(void)
{
    struct vm_page *page;
    unsigned int pa;
    int old_flags;

    old_flags = disable_interrupts();
    acquire_spinlock(&page_lock);
    page = free_page_list;
    free_page_list = page->next;
    release_spinlock(&page_lock);
    restore_interrupts(old_flags);

    pa = (page - pages) * PAGE_SIZE;

    memset((void*) PA_TO_VA(pa), 0, PAGE_SIZE);

    return pa;
}

void vm_free_page(unsigned int addr)
{
    struct vm_page *page = &pages[addr / PAGE_SIZE];
    int old_flags;

    old_flags = disable_interrupts();
    acquire_spinlock(&page_lock);
    page->next = free_page_list;
    free_page_list = page;
    release_spinlock(&page_lock);
    restore_interrupts(old_flags);
}

struct vm_page *page_for_address(unsigned int addr)
{
    return &pages[addr / PAGE_SIZE];
}
