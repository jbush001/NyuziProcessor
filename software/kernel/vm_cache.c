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
#include "slab.h"
#include "spinlock.h"
#include "thread.h"
#include "trap.h"
#include "vm_cache.h"

#define NUM_HASH_BUCKETS 37

static spinlock_t cache_lock;
static struct list_node hash_table[NUM_HASH_BUCKETS];
MAKE_SLAB(cache_slab, struct vm_cache)
static int debug_cache_lock_owner = -1;

void bootstrap_vm_cache(void)
{
    int i;

    for (i = 0; i < NUM_HASH_BUCKETS; i++)
        list_init(&hash_table[i]);
}

struct vm_cache *create_vm_cache(struct vm_cache *source)
{
    struct vm_cache *cache;

    cache = slab_alloc(&cache_slab);
    list_init(&cache->page_list);
    cache->ref_count = 1;
    cache->source = source;
    if (source)
        inc_cache_ref(source);

    return cache;
}

static unsigned int gen_hash(const struct vm_cache *cache, unsigned int offset)
{
	return (unsigned int) cache + (unsigned int) offset / PAGE_SIZE;
}

void lock_vm_cache(void)
{
    acquire_spinlock(&cache_lock);
    debug_cache_lock_owner = current_hw_thread();
}

void unlock_vm_cache(void)
{
    assert(debug_cache_lock_owner == current_hw_thread());
    debug_cache_lock_owner = -1;
    release_spinlock(&cache_lock);
}

void inc_cache_ref(struct vm_cache *cache)
{
    __sync_fetch_and_add(&cache->ref_count, 1);
}

void dec_cache_ref(struct vm_cache *cache)
{
    struct vm_page *page;
    int old_flags;

    assert(debug_cache_lock_owner != current_hw_thread());
    assert(cache->ref_count > 0);

    if (__sync_fetch_and_add(&cache->ref_count, -1) == 1)
    {
        if (cache->source)
            dec_cache_ref(cache->source);

        old_flags = disable_interrupts();
        lock_vm_cache();
        VM_DEBUG("destroying vm_cache %p\n", cache);

        // Free all pages owned by this cache
        while (!list_is_empty(&cache->page_list))
        {
            page = list_peek_head(&cache->page_list, struct vm_page);
            remove_cache_page(page);
            VM_DEBUG("dec page ref pa %08x\n", page_to_pa(page));
            dec_page_ref(page);
        }

        unlock_vm_cache();
        restore_interrupts(old_flags);
    }
}

void insert_cache_page(struct vm_cache *cache, unsigned int offset,
                       struct vm_page *page)
{
    unsigned int bucket;

    assert(debug_cache_lock_owner == current_hw_thread());

    offset = PAGE_ALIGN(offset);
    bucket = gen_hash(cache, offset) % NUM_HASH_BUCKETS;
    assert(page->cache == 0);
    page->cache = cache;
    page->cache_offset = offset;
    list_add_tail(&hash_table[bucket], &page->hash_entry);
    list_add_tail(&cache->page_list, &page->list_entry);
}

struct vm_page *lookup_cache_page(const struct vm_cache *cache, unsigned int offset)
{
    unsigned int bucket;
    struct vm_page *page;

    assert(debug_cache_lock_owner == current_hw_thread());

    offset = PAGE_ALIGN(offset);
    bucket = gen_hash(cache, offset) % NUM_HASH_BUCKETS;
    multilist_for_each(&hash_table[bucket], page, hash_entry, struct vm_page)
    {
        if (page->cache_offset == offset && page->cache == cache)
            return page;
    }

    return 0;
}

void remove_cache_page(struct vm_page *page)
{
    assert(debug_cache_lock_owner == current_hw_thread());

    list_remove_node(&page->list_entry);
    list_remove_node(&page->hash_entry);
}
