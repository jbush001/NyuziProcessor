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
#include "slab.h"
#include "thread.h"
#include "trap.h"
#include "vm_address_space.h"
#include "vm_cache.h"
#include "vm_page.h"

static struct vm_address_space kernel_address_space;

MAKE_SLAB(address_space_slab, struct vm_address_space);

static int soft_fault(struct vm_address_space *space,
                      const struct vm_area *area, unsigned int address);

struct vm_address_space *get_kernel_address_space(void)
{
    return &kernel_address_space;
}

void vm_address_space_init(struct vm_translation_map *translation_map)
{
    int i;
    struct vm_area_map *amap = &kernel_address_space.area_map;

    kernel_address_space.translation_map = translation_map;
    init_rwlock(&kernel_address_space.mut);
    init_area_map(amap, KERNEL_BASE, 0xffffffff);
    create_vm_area(amap, KERNEL_BASE, KERNEL_END - KERNEL_BASE, PLACE_EXACT,
                   "kernel", AREA_WIRED | AREA_WRITABLE | AREA_EXECUTABLE);
    create_vm_area(amap, PHYS_MEM_ALIAS, memory_size, PLACE_EXACT,
                   "memory alias", AREA_WIRED | AREA_WRITABLE);
    create_vm_area(amap, KERNEL_HEAP_BASE, KERNEL_HEAP_SIZE, PLACE_EXACT,
                   "kernel_heap", AREA_WIRED | AREA_WRITABLE);
    create_vm_area(amap, DEVICE_REG_BASE, 0x10000, PLACE_EXACT,
                   "device registers", AREA_WIRED | AREA_WRITABLE);
    for (i = 0; i < 4; i++)
    {
        create_vm_area(amap, INITIAL_KERNEL_STACKS + i * KERNEL_STACK_SIZE,
                       KERNEL_STACK_SIZE, PLACE_EXACT, "kernel stack",
                       AREA_WIRED | AREA_WRITABLE);
    }
}

struct vm_address_space *create_address_space(void)
{
    struct vm_address_space *space;

    space = slab_alloc(&address_space_slab);
    init_area_map(&space->area_map, PAGE_SIZE, KERNEL_BASE - 1);
    space->translation_map = create_translation_map();
    init_rwlock(&space->mut);

    return space;
}

// No locking, because at this point only one thread (grim reaper) should
// be referecing this address space
void destroy_address_space(struct vm_address_space *space)
{
    struct vm_area *area;

    kprintf("destroy_address_space\n");
    while ((area = first_area(&space->area_map)) != 0)
    {
        kprintf("destroy area %s\n", area->name);
        dec_cache_ref(area->cache);
        destroy_vm_area(&space->area_map, area);
    }
}

struct vm_area *create_area(struct vm_address_space *space, unsigned int address,
                            unsigned int size, enum placement place,
                            const char *name, unsigned int flags,
                            struct vm_cache *cache, unsigned int cache_offset)
{
    struct vm_area *area;
    unsigned int fault_addr;
    int old_flags;

    // Anonymous area, create a cache if non is specified.
    if (cache == 0)
        cache = create_vm_cache();

    rwlock_lock_write(&space->mut);
    area = create_vm_area(&space->area_map, address, size, place, name, flags);
    if (area == 0)
    {
        kprintf("create area failed\n");
        goto error1;
    }

    area->cache = cache;
    area->cache_offset = cache_offset;
    if (flags & AREA_WIRED)
    {
        for (fault_addr = area->low_address; fault_addr < area->high_address;
                fault_addr += PAGE_SIZE)
        {
            if (!soft_fault(space, area, fault_addr))
                panic("create_area: soft fault failed");
        }
    }

error1:
    rwlock_unlock_write(&space->mut);

    return area;
}

void destroy_area(struct vm_address_space *space, struct vm_area *area)
{
    struct vm_cache *cache;
    rwlock_lock_write(&space->mut);
    cache = area->cache;

    // XXX Unmap all pages in this area

    destroy_vm_area(&space->area_map, area);
    rwlock_unlock_write(&space->mut);

    dec_cache_ref(cache);
}

int handle_page_fault(unsigned int address)
{
    struct vm_address_space *space = current_thread()->proc->space;
    const struct vm_area *area;
    int old_flags;
    int result = 0;

    rwlock_lock_read(&space->mut);

    if (address >= KERNEL_BASE)
        space = &kernel_address_space;
    else
        space = current_thread()->proc->space;

    area = lookup_area(&space->area_map, address);
    if (area == 0)
    {
        result = 0;
        goto error1;
    }

    result = soft_fault(space, area, address);

error1:
    rwlock_unlock_read(&space->mut);

    return result;
}

//
// This is always called with the address space lock held, so the
// area is guaranteed not to change.
//
static int soft_fault(struct vm_address_space *space, const struct vm_area *area,
                      unsigned int address)
{
    int got;
    int page_flags;
    struct vm_page *page;
    unsigned int pa;
    unsigned int cache_offset;
    struct vm_cache *cache = area->cache;
    int old_flags;

    cache_offset = PAGE_ALIGN(address - area->low_address + area->cache_offset);
    old_flags = disable_interrupts();
    lock_vm_cache();
    page = lookup_cache_page(cache, cache_offset);
    if (page == 0)
    {
        pa = vm_allocate_page();
        page = page_for_address(pa);

        // Insert the page first so, if a collided fault occurs, it will not
        // load a different page (the vm cache lock protects the busy bit)
        page->busy = 1;
        insert_cache_page(cache, cache_offset, page);

        if (cache->file)
        {
            unlock_vm_cache();
            restore_interrupts(old_flags);
            got = read_file(cache->file, cache_offset, (void*) PA_TO_VA(pa),
                            PAGE_SIZE);
            if (got < 0)
            {
                kprintf("failed to read from file\n");

                // XXX kill process?

                return 0;
            }

            disable_interrupts();
            lock_vm_cache();
        }

        page->busy = 0;
    }

    unlock_vm_cache();
    restore_interrupts(old_flags);

    // XXX busy way for page to finish loading
    while (page->busy)
        reschedule();

    // It's possible two threads will fault on the same VA and end up mapping
    // the page twice. This is fine, because the code above ensures it will
    // be the same page.
    page_flags = PAGE_PRESENT;
    if (area->flags & AREA_WRITABLE)
        page_flags |= PAGE_WRITABLE;

    if (area->flags & AREA_EXECUTABLE)
        page_flags |= PAGE_EXECUTABLE;

    if (space == &kernel_address_space)
        page_flags |= PAGE_SUPERVISOR | PAGE_GLOBAL;

    vm_map_page(space->translation_map, address, address_for_page(page)
        | page_flags);

    return 1;
}
