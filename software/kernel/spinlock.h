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

#include "trap.h"

typedef volatile int spinlock_t;

static inline void acquire_spinlock(spinlock_t *sp)
{
    do
    {
        // Wait while local copy of sp is locked, to avoid creating traffic on
        // the L2 interconnect.
        while (*sp)
            ;

        // Attempt to grab lock
    }
    while (!__sync_bool_compare_and_swap(sp, 0, 1));
}

// Disables interrupts before acquiring spinlock. Returns old CPU flags.
static inline int acquire_spinlock_int(spinlock_t *sp)
{
    int old_flags = disable_interrupts();
    acquire_spinlock(sp);
    return old_flags;
}

static inline void release_spinlock(spinlock_t *sp)
{
    *sp = 0;
    __sync_synchronize();
}

// Restores interrupts after erlaseing spinlock, takes flags returned by
// acquire_spinlock_int
static inline void release_spinlock_int(spinlock_t *sp, int old_flags)
{
    release_spinlock(sp);
    restore_interrupts(old_flags);
}
