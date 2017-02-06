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
#include "rwlock.h"
#include "thread.h"
#include "trap.h"

//
// The following rules ensure fairness between readers and writers:
// 1. If a writer is waiting on the lock, no new readers will enter the lock.
// 2. When the last reader exits the critical section, it will wake one writer.
// 3. However, there are waiting readers when a writer exits the lock, they
//    will be unblocked and allowed to enter (subsequent readers will not enter
//    per rule 1)
//

void init_rwlock(struct rwlock *m)
{
    m->write_locked = 0;
    m->active_read_count = 0;
    list_init(&m->reader_wait_list);
    list_init(&m->writer_wait_list);
}

static void wait(struct rwlock *m)
{
    current_thread()->state = THREAD_WAITING;
    release_spinlock(&m->spinlock);
    reschedule();
    acquire_spinlock(&m->spinlock);
}

void rwlock_lock_read(struct rwlock *m)
{
    int old_flags;

    old_flags = acquire_spinlock_int(&m->spinlock);
    if (!list_is_empty(&m->writer_wait_list) || m->write_locked)
    {
        // Rule 1: Don't acquire lock if there are waiting writers.
        list_add_tail(&m->reader_wait_list, current_thread());
        wait(m);
    }
    else
        m->active_read_count++;

    assert(!m->write_locked);
    release_spinlock_int(&m->spinlock, old_flags);
}

void rwlock_unlock_read(struct rwlock *m)
{
    int old_flags;

    old_flags = acquire_spinlock_int(&m->spinlock);

    assert(!m->write_locked);
    assert(m->active_read_count > 0);

    // Rule 2: last reader to exit wakes one writer
    if (--m->active_read_count == 0 && !list_is_empty(&m->writer_wait_list))
    {
        m->write_locked = 1;
        make_thread_ready(list_remove_head(&m->writer_wait_list, struct thread));
    }

    release_spinlock_int(&m->spinlock, old_flags);
}

void rwlock_lock_write(struct rwlock *m)
{
    int old_flags;

    old_flags = acquire_spinlock_int(&m->spinlock);

    // Wait until all readers are out of the critical section.
    if (m->active_read_count > 0 || m->write_locked)
    {
        list_add_tail(&m->writer_wait_list, current_thread());
        wait(m);
    }

    assert(m->active_read_count == 0);
    m->write_locked = 1;
    release_spinlock_int(&m->spinlock, old_flags);
}

void rwlock_unlock_write(struct rwlock *m)
{
    int old_flags;

    old_flags = acquire_spinlock_int(&m->spinlock);

    assert(m->write_locked);
    assert(m->active_read_count == 0);

    if (!list_is_empty(&m->reader_wait_list))
    {
        // Rule 3: Wake all waiting readers when a writer exits.
        while (!list_is_empty(&m->reader_wait_list))
        {
            make_thread_ready(list_remove_head(&m->reader_wait_list, struct thread));
            m->active_read_count++;
        }

        m->write_locked = 0;
    }
    else if (!list_is_empty(&m->writer_wait_list))
    {
        // If only other writer(s) are waiting, wake one. Keep m_write_locked
        // set to 1.
        make_thread_ready(list_remove_head(&m->writer_wait_list, struct thread));
    }
    else
        m->write_locked = 0;

    release_spinlock_int(&m->spinlock, old_flags);
}

#if TEST_RWLOCK

struct rwlock mut;

int rwlock_test_reader_thread(void *ignore)
{
    for (;;)
    {
        rwlock_lock_read(&mut);
        kprintf("%d", current_thread()->id);
        rwlock_unlock_read(&mut);
    }
}


int rwlock_test_writer_thread(void *ignore)
{
    for (;;)
    {
        rwlock_lock_write(&mut);
        kprintf("\n<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n");
        kprintf("Writer %d\n", current_thread()->id);
        kprintf(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n");
        rwlock_unlock_write(&mut);
    }
}

//
// - Ensure readers never execute when the writer has exclusive access.
// - Ensure readers don't starve writers or vice versa
// Output should look like this:
//
// <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
// Writer 14
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
// 71123546891011
// <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
// Writer 15
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

void test_rwlock(void)
{
    init_rwlock(&mut);
    for (int i = 0; i < 10; i++)
        spawn_kernel_thread("reader", rwlock_test_reader_thread, 0);

    for (int i = 0; i < 2; i++)
        spawn_kernel_thread("writer", rwlock_test_writer_thread, 0);
}

#endif
