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

#include "mutex.h"
#include "thread.h"
#include "trap.h"

void init_mutex(struct mutex *m)
{
    m->spinlock = 0;
    m->locked = 0;
    list_init(&m->wait_list);
}

void acquire_mutex(struct mutex *m)
{
    int old_flags;
    struct thread *th = current_thread();

    old_flags = disable_interrupts();
    acquire_spinlock(&m->spinlock);
    if (m->locked)
    {
        th->state = THREAD_WAIT;
        list_add_tail(&m->wait_list, th);
        release_spinlock(&m->spinlock);
        reschedule();
        acquire_spinlock(&m->spinlock);
    }

    m->locked = 1;
    release_spinlock(&m->spinlock);
    restore_interrupts(old_flags);
}

void release_mutex(struct mutex *m)
{
    int old_flags;
    struct thread *th;

    old_flags = disable_interrupts();
    acquire_spinlock(&m->spinlock);

    // If there are no waiters, release the lock. If there is at least one
    // waiter, hand ownership directly to it by waiting it and keeping
    // locked set.
    if (list_is_empty(&m->wait_list))
        m->locked = 0;
    else
        make_thread_ready(list_remove_head(&m->wait_list, struct thread));

    release_spinlock(&m->spinlock);
    restore_interrupts(old_flags);
}

