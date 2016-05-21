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
#include "spinlock.h"
#include "vm_page.h"
#include "vm_translation_map.h"

#define MEMORY_SIZE 0x1000000

static unsigned int next_alloc_page;
static spinlock_t page_lock;
extern int boot_pages_used;

void vm_page_init(void)
{
    next_alloc_page = boot_pages_used;
}

// XXX hack
unsigned int vm_allocate_page(void)
{
    unsigned int pa;

    acquire_spinlock(&page_lock);
    pa = next_alloc_page;
    next_alloc_page += PAGE_SIZE;
    release_spinlock(&page_lock);

    memset((void*) PA_TO_VA(pa), 0, PAGE_SIZE);

    return pa;
}

void vm_free_page(unsigned int addr)
{
    // XXX implement me
}

