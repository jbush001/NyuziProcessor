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

MAKE_SLAB(address_space_slab, struct vm_address_space)

static int soft_fault(struct vm_address_space *space,
                      const struct vm_area *area, unsigned int address,
                      int is_store);

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

    VM_DEBUG("destroy_address_space %p\n", space);
    while ((area = first_area(&space->area_map)) != 0)
    {
        VM_DEBUG("destroy area %s\n", area->name);
        if (area->cache)
            dec_cache_ref(area->cache);

        destroy_vm_area(area);
    }

    destroy_translation_map(space->translation_map);
}

struct vm_area *create_area(struct vm_address_space *space, unsigned int address,
                            unsigned int size, enum placement place,
                            const char *name, unsigned int flags,
                            struct vm_cache *cache, unsigned int cache_offset)
{
    struct vm_area *area;
    unsigned int fault_addr;

    // Anonymous area, create a cache if non is specified.
    if (cache == 0)
        cache = create_vm_cache(0);
    else
        inc_cache_ref(cache);

    rwlock_lock_write(&space->mut);
    area = create_vm_area(&space->area_map, address, size, place, name, flags);
    if (area == 0)
    {
        kprintf("create area failed\n");
        goto error1;
    }

    area->cache = cache;
    area->cache_offset = cache_offset;
    area->cache_length = size;
    if (flags & AREA_WIRED)
    {
        for (fault_addr = area->low_address; fault_addr < area->high_address;
                fault_addr += PAGE_SIZE)
        {
            if (!soft_fault(space, area, fault_addr, 1))
                panic("create_area: soft fault failed");
        }
    }

error1:
    rwlock_unlock_write(&space->mut);

    return area;
}

// This area is wired by default and does not take page faults.
// The pages for this area should already have been allocated: this will not
// mark them as such. The area created by this will not be backed by a
// vm_cache or vm_backing_store.
struct vm_area *map_contiguous_memory(struct vm_address_space *space, unsigned int address,
                                      unsigned int size, enum placement place,
                                      const char *name, unsigned int area_flags,
                                      unsigned int phys_addr)
{
    struct vm_area *area;
    unsigned int page_flags;
    unsigned int offset;

    area_flags |= AREA_WIRED;

    rwlock_lock_write(&space->mut);
    area = create_vm_area(&space->area_map, address, size, place, name, area_flags);
    if (area == 0)
    {
        kprintf("create area failed\n");
        goto error1;
    }

    area->cache = 0;

    page_flags = PAGE_PRESENT;

    // We do not do dirty page tracking on these areas, as this is expected to
    // be device memory. Mark pages writable by default if the area is writable.
    if ((area_flags & AREA_WRITABLE) != 0)
        page_flags |= PAGE_WRITABLE;

    if (area->flags & AREA_EXECUTABLE)
        page_flags |= PAGE_EXECUTABLE;

    if (space == &kernel_address_space)
        page_flags |= PAGE_SUPERVISOR | PAGE_GLOBAL;

    // Map the pages
    for (offset = 0; offset < size; offset += PAGE_SIZE)
    {
        vm_map_page(space->translation_map, area->low_address + offset,
                    (phys_addr + offset) | page_flags);
    }

error1:
    rwlock_unlock_write(&space->mut);

    return area;
}

void destroy_area(struct vm_address_space *space, struct vm_area *area)
{
    struct vm_cache *cache;
    unsigned int va;
    unsigned int ptentry;

    rwlock_lock_write(&space->mut);
    cache = area->cache;

    // Unmap all pages in this area
    for (va = area->low_address; va < area->high_address; va += PAGE_SIZE)
    {
        ptentry = query_translation_map(space->translation_map, va);
        if ((ptentry & PAGE_PRESENT) != 0)
        {
            VM_DEBUG("destroy_area: decrementing page ref for va %08x pa %08x\n",
                    va, PAGE_ALIGN(ptentry));
            dec_page_ref(pa_to_page(ptentry));
        }
    }

    destroy_vm_area(area);
    rwlock_unlock_write(&space->mut);
    if (cache)
        dec_cache_ref(cache);
}

int handle_page_fault(unsigned int address, int is_store)
{
    struct vm_address_space *space;
    const struct vm_area *area;
    int result = 0;

    if (address >= KERNEL_BASE)
        space = &kernel_address_space;
    else
        space = current_thread()->proc->space;

    rwlock_lock_read(&space->mut);
    area = lookup_area(&space->area_map, address);
    if (area == 0)
    {
        result = 0;
        goto error1;
    }

    result = soft_fault(space, area, address, is_store);

error1:
    rwlock_unlock_read(&space->mut);

    return result;
}

//
// This is always called with the address space lock held, so the area is
// guaranteed not to change. Returns 1 if it sucessfully satisfied the fault, 0
// if it failed for some reason.
//
static int soft_fault(struct vm_address_space *space, const struct vm_area *area,
                      unsigned int address, int is_store)
{
    int got;
    unsigned int page_flags;
    struct vm_page *source_page;
    struct vm_page *dummy_page = 0;
    unsigned int area_offset;
    unsigned int cache_offset;
    struct vm_cache *cache;
    int old_flags;
    int is_cow_page = 0;
    int size_to_read;

    VM_DEBUG("soft fault va %08x %s\n", address, is_store ? "store" : "load");

    // XXX check area protections and fail if this shouldn't be allowed
    if (is_store && (area->flags & AREA_WRITABLE) == 0)
    {
        kprintf("store to read only area %s @%08x\n", area->name, address);
        return 0;
    }

    area_offset = PAGE_ALIGN(address - area->low_address);
    cache_offset = PAGE_ALIGN(area_offset + area->cache_offset);
    old_flags = disable_interrupts();
    lock_vm_cache();
    assert(area->cache);

    for (cache = area->cache; cache; cache = cache->source)
    {
        VM_DEBUG("searching in cache %p\n", cache);
        source_page = lookup_cache_page(cache, cache_offset);
        if (source_page)
            break;

        if (cache->file)
        {
            VM_DEBUG("reading page from file\n");

            // Read the page from this cache.
            source_page = vm_allocate_page();

            // Insert the page first so, if a collided fault occurs, it will not
            // load a different page (the vm cache lock protects the busy bit)
            source_page->busy = 1;
            insert_cache_page(cache, cache_offset, source_page);
            unlock_vm_cache();
            restore_interrupts(old_flags);

            if (area->cache_length < area_offset
                || area->cache_length - area_offset < PAGE_SIZE)
                size_to_read = area->cache_length - area_offset;
            else
                size_to_read = PAGE_SIZE;

            if (size_to_read > 0)
            {
                got = read_file(cache->file, cache_offset,
                                (void*) PA_TO_VA(page_to_pa(source_page)), size_to_read);
                if (got < 0)
                {
                    kprintf("failed to read from file\n");
                    dec_page_ref(source_page);
                    if (dummy_page != 0)
                    {
                        disable_interrupts();
                        lock_vm_cache();
                        remove_cache_page(dummy_page);
                        unlock_vm_cache();
                        restore_interrupts(old_flags);
                        dec_page_ref(dummy_page);
                    }

                    return 0;
                }
            }
            else
                size_to_read = 0;

            // For BSS, clear out data past the end of the file
            if (size_to_read < PAGE_SIZE)
            {
                memset((char*) PA_TO_VA(page_to_pa(source_page)) + size_to_read, 0,
                       PAGE_SIZE - size_to_read);
            }

            disable_interrupts();
            lock_vm_cache();
            source_page->busy = 0;
            break;
        }

        // Otherwise scan the next cache
        is_cow_page = 1;

        if (cache == area->cache)
        {
            // Insert a dummy page in the top level cache to catch collided faults.
            dummy_page = vm_allocate_page();
            dummy_page->busy = 1;
            insert_cache_page(cache, cache_offset, dummy_page);
        }
    }

    if (source_page == 0)
    {
        assert(dummy_page != 0);

        VM_DEBUG("source page was not found, use empty page\n");

        // No page found, just use the dummy page
        dummy_page->busy = 0;
        source_page = dummy_page;
    }
    else if (is_cow_page)
    {
        // is_cow_page means source_page belongs to another cache.
        assert(dummy_page != 0);
        if (is_store)
        {
            // The dummy page have the contents of the source page copied into it,
            // and will be inserted into the top cache (it's not really a dummy page
            // any more).
            memcpy((void*) PA_TO_VA(page_to_pa(dummy_page)),
                (void*) PA_TO_VA(page_to_pa(source_page)),
                PAGE_SIZE);
            VM_DEBUG("write copy page va %08x dest pa %08x source pa %08x\n",
                address, page_to_pa(dummy_page), page_to_pa(source_page));
            source_page = dummy_page;
            dummy_page->busy = 0;
        }
        else
        {
            // We will map in the read-only page from the source cache.
            // Remove the dummy page from this cache (we do not insert
            // the page into this cache, because we don't own it page).
            remove_cache_page(dummy_page);
            dec_page_ref(dummy_page);

            VM_DEBUG("mapping read-only source page va %08x pa %08x\n", address,
                page_to_pa(source_page));
        }
    }

    assert(source_page != 0);

    // Grab a ref because we are going to map this page
    inc_page_ref(source_page);

    unlock_vm_cache();
    restore_interrupts(old_flags);

    // XXX busy wait for page to finish loading
    while (source_page->busy)
        reschedule();

    if (is_store)
        source_page->dirty = 1; // XXX Locking?

    // It's possible two threads will fault on the same VA and end up mapping
    // the page twice. This is fine, because the code above ensures it will
    // be the same page.
    page_flags = PAGE_PRESENT;

    // If the page is clean, we will mark it not writable. This will fault
    // on the next write, allowing us to update the dirty flag.
    if ((area->flags & AREA_WRITABLE) != 0 && (source_page->dirty || is_store))
        page_flags |= PAGE_WRITABLE;

    if (area->flags & AREA_EXECUTABLE)
        page_flags |= PAGE_EXECUTABLE;

    if (space == &kernel_address_space)
        page_flags |= PAGE_SUPERVISOR | PAGE_GLOBAL;

    vm_map_page(space->translation_map, address, page_to_pa(source_page)
        | page_flags);

    return 1;
}
