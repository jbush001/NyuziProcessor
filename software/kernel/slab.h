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

#include "spinlock.h"

//
// Simple chunking allocator. This sits on top of the kernel heap allocator.
// Unlike 'real' slab allocators, this doesn't defer object destruction. It
// also never releases memory back to the system.
//

struct slab_allocator
{
    spinlock_t lock;
    unsigned int object_size;
    void *free_list;
    void *wilderness_slab;
    unsigned int wilderness_offset;
    unsigned int slab_size;
};

#define MAKE_SLAB(name, object) \
    static struct slab_allocator name = { 0, sizeof(object), 0, 0, 0, PAGE_SIZE };

void *slab_alloc(struct slab_allocator*);
void slab_free(struct slab_allocator*, void *object);
