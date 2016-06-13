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
#include "vm_page.h"

//
// The OS treats physical memory as a cache for some backing store. Each
// vm_cache is an independent collection of memory pages.
//

struct vm_cache
{
    struct list_node page_list;
    struct file_handle *file;
    volatile int ref_count;
    struct vm_cache *source;
};

void bootstrap_vm_cache(void);

void lock_vm_cache(void);
void unlock_vm_cache(void);

// These should not be called with vm_cache lock held. They may acquire it as
// a side effect.
void inc_cache_ref(struct vm_cache *cache);
void dec_cache_ref(struct vm_cache *cache);

// All of these must be called with the vm_cache lock held.
struct vm_cache *create_vm_cache(struct vm_cache *source);
void insert_cache_page(struct vm_cache *, unsigned int offset,  struct vm_page*);
struct vm_page *lookup_cache_page(const struct vm_cache*, unsigned int offset);
void remove_cache_page(struct vm_page *page);
