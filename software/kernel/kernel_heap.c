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

#include "vm_translation_map.h"
#include "vm_page.h"
#include "kernel_heap.h"
#include "libc.h"
#include "spinlock.h"
#include "trap.h"

struct free_range
{
    struct free_range *next;
    unsigned int size;
};

static void insert_free_range(struct free_range *range);

static struct free_range *free_list;
static spinlock_t heap_lock;
static unsigned int wilderness_ptr;

void boot_init_heap(const char *base_address)
{
    wilderness_ptr = (unsigned int) base_address;
}

void *kmalloc(unsigned int size)
{
    struct free_range **prev_ptr;
    struct free_range *candidate;
    struct free_range *new_range;
    unsigned int grow_size;
    void *result = 0;
    unsigned int va;
    int old_flags;

    old_flags = acquire_spinlock_int(&heap_lock);

    // Walk ranges in order to find one that is big enough
    for (prev_ptr = &free_list; *prev_ptr; prev_ptr = &(*prev_ptr)->next)
    {
        candidate = *prev_ptr;
        if (candidate->size == size)
        {
            // Remove this free range entirely
            *prev_ptr = candidate->next;
            result = (void*) candidate;
            break;
        }
        else if (candidate->size > size)
        {
            // Lop a slice off the front of this range
            new_range = (struct free_range*) (((char*) candidate) + size);
            new_range->next = candidate->next;
            *prev_ptr = new_range;
            result = (void*) candidate;
            break;
        }
    }

    if (result == 0)
    {
        // No ranges are large enough, grow heap.
        grow_size = size * 2;
        if (grow_size < 0x10000)
            grow_size = 0x10000;

        // Wire in pages
        for (va = wilderness_ptr; va < wilderness_ptr + grow_size; va += PAGE_SIZE)
        {
            vm_map_page(0, va, page_to_pa(vm_allocate_page())
                        | PAGE_PRESENT | PAGE_WRITABLE | PAGE_SUPERVISOR
                        | PAGE_GLOBAL);
        }

        result = (void*) wilderness_ptr;
        new_range = (struct free_range*) (wilderness_ptr + size);
        new_range->size = grow_size - size;
        wilderness_ptr += grow_size;
        insert_free_range(new_range);
    }

    release_spinlock_int(&heap_lock, old_flags);

    return result;
}

void kfree(void *ptr, unsigned int size)
{
    struct free_range *new_range = (struct free_range*) ptr;
    int old_flags;

    new_range->size = size;

    old_flags = acquire_spinlock_int(&heap_lock);
    insert_free_range(new_range);
    release_spinlock_int(&heap_lock, old_flags);
}

static void insert_free_range(struct free_range *new_range)
{
    struct free_range *prev_range;
    if (free_list == 0 || new_range < free_list)
    {
        // Insert as first element in list
        new_range->next = free_list;
        free_list = new_range;
        prev_range = 0;
    }
    else
    {
        // Walk heap and insert in proper place
        for (prev_range = free_list; prev_range; prev_range = prev_range->next)
        {
            if (prev_range->next == 0 || (new_range > prev_range
                                          && new_range < prev_range->next))
            {
                new_range->next = prev_range->next;
                prev_range->next = new_range;
                break;
            }
        }
    }

    // Try to merge with next block
    if (new_range->next != 0
            && ((char*) new_range + new_range->size == (char*) new_range->next))
    {
        new_range->size += new_range->next->size;
        new_range->next = new_range->next->next;
    }

    // Try to merge with previous block
    if (prev_range != 0
            && (char*) prev_range + prev_range->size == (char*) new_range)
    {
        prev_range->next = new_range->next;
        prev_range->size += new_range->size;
    }
}
