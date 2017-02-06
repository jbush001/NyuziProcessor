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

#include "kernel_heap.h"
#include "libc.h"
#include "slab.h"
#include "trap.h"

void *slab_alloc(struct slab_allocator *sa)
{
    void *object = 0;
    int old_flags;

    old_flags = acquire_spinlock_int(&sa->lock);
    if (sa->free_list)
    {
        // Grab freed object
        object = sa->free_list;
        sa->free_list = *((void**) object);
    }
    else
    {
        // If there is no wilderness, or the slab is full, create a new
        // wilderness slab
        if (sa->wilderness_slab == 0
                || sa->wilderness_offset + sa->object_size > sa->slab_size)
        {
            sa->wilderness_slab = kmalloc(sa->slab_size);
            sa->wilderness_offset = 0;
        }

        object = (void*)((char*) sa->wilderness_slab + sa->wilderness_offset);
        sa->wilderness_offset += sa->object_size;
    }

    release_spinlock_int(&sa->lock, old_flags);

    return object;
}

void slab_free(struct slab_allocator *sa, void *object)
{
    int old_flags;

    old_flags = acquire_spinlock_int(&sa->lock);
    *((void**) object) = sa->free_list;
    sa->free_list = object;
    release_spinlock_int(&sa->lock, old_flags);
}

#ifdef TEST_SLAB

struct linked_node
{
    struct linked_node *next;
    int value;
    int stuff[16];
};

MAKE_SLAB(node_slab, struct linked_node);

void test_slab(void)
{
    int i;
    int j;
    struct linked_node *node;
    struct linked_node *list = 0;

    for (j = 1; j < 128; j++)
    {
        // Allocate a bunch of nodes
        for (i = 0; i < j; i++)
        {
            node = (struct linked_node*) slab_alloc(&node_slab);
            node->next = list;
            list = node;
            node->value = j;
        }

        // Free all but one
        for (i = 0; i < j - 1; i++)
        {
            node = list;
            list = list->next;
            slab_free(&node_slab, node);
        }
    }

    for (node = list; node; node = node->next)
        kprintf("%d ", node->value);

    kprintf("\n");
}

#endif
