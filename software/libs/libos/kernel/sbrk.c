//
// Copyright 2011-2015 Jeff Bush
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

#include <stdio.h>
#include <stdlib.h>
#include "syscall.h"

#define HEAP_SIZE 0x300000

static volatile unsigned int lock;
unsigned int next_alloc;
unsigned int heap_base;

void *sbrk(ptrdiff_t size)
{
    unsigned int chunk;

    while (__sync_lock_test_and_set(&lock, 1))
        ;

    if (next_alloc == 0)
        heap_base = next_alloc = __syscall(SYS_create_area, 0, HEAP_SIZE, 2, (int) "heap", 2);

    if (next_alloc + size - heap_base > HEAP_SIZE)
    {
        // XXX should grow heap region
        printf("out of heap space\n");
        exit(1);
    }

    chunk = next_alloc;
    next_alloc += size;
    __sync_lock_release(&lock);

    return (void*) chunk;
}

