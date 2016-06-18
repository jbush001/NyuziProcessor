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

#pragma once

#include "list.h"

#define PAGE_STRUCTURES_SIZE(memory_size) (sizeof(struct vm_page) * (memory_size \
    / PAGE_SIZE))
#define PAGE_SIZE 0x1000
#define PAGE_ALIGN(x) (x & ~(PAGE_SIZE - 1))

#if 0
    #define VM_DEBUG(...) kprintf(__VA_ARGS__)
#else
    #define VM_DEBUG(...) do {} while(0)
#endif

//
// Each vm_page object represents a page frame of physical memory.
//

struct vm_page
{
    struct list_node list_entry;    // Object or free list
    struct list_node hash_entry;
    unsigned int cache_offset;
    struct vm_cache *cache;
    volatile int busy;
    int dirty;
    volatile int ref_count;
};

extern unsigned int memory_size;

void vm_page_init(unsigned int memory_size);
struct vm_page *vm_allocate_page(void);
void inc_page_ref(struct vm_page*);
void dec_page_ref(struct vm_page*);
struct vm_page *pa_to_page(unsigned int addr);
unsigned int page_to_pa(const struct vm_page*);
unsigned int allocate_contiguous_memory(unsigned int size);
