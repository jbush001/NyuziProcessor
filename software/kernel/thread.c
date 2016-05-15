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

#include "asm.h"
#include "libc.h"
#include "slab.h"
#include "spinlock.h"
#include "thread.h"

struct thread *cur_thread[MAX_CORES];
static struct thread_queue ready_q;
static spinlock_t thread_q_lock;

MAKE_SLAB(thread_slab, struct thread);

void boot_init_thread(struct vm_translation_map *map)
{
    struct thread *th = slab_alloc(&thread_slab);
    th->map = map;
    cur_thread[__builtin_nyuzi_read_control_reg(CR_CURRENT_THREAD)] = th;
}

struct thread *current_thread(void)
{
    int core = __builtin_nyuzi_read_control_reg(CR_CURRENT_THREAD);
    return cur_thread[core];
}

void enqueue_thread(struct thread_queue *q, struct thread *th)
{
    if (q->head == 0)
        q->head = q->tail = th;
    else
    {
        q->tail->queue_next = th;
        q->tail = th;
    }

    th->queue_next = 0;
}

struct thread *dequeue_thread(struct thread_queue *q)
{
    struct thread *th = q->head;
    q->head = th->queue_next;
    if (q->head == 0)
        q->tail = 0;

    return th;
}

// Execution of a new thread starts here, called from context_switch.
// Need to release thread lock.
static void thread_start(void)
{
    struct thread *th = current_thread();
    release_spinlock(&thread_q_lock);
    th->start_function(th->param);
}

struct thread *spawn_thread(struct vm_translation_map *map,
                            void (*start_function)(void *param),
                            void *param)
{
    struct thread *th = slab_alloc(&thread_slab);
    th->kernel_stack = (unsigned char*) kmalloc(0x2000) + 0x2000;
    th->current_stack = (unsigned char*) th->kernel_stack - 0x840;
    th->map = map;
    ((unsigned int*) th->current_stack)[0x814 / 4] = (unsigned int) thread_start;
    th->start_function = start_function;
    th->param = param;

    acquire_spinlock(&thread_q_lock);
    enqueue_thread(&ready_q, th);
    release_spinlock(&thread_q_lock);
}

void reschedule(void)
{
    int hwthread = __builtin_nyuzi_read_control_reg(CR_CURRENT_THREAD);
    struct thread *old_thread;
    struct thread *next_thread;

    // Put current thread back on ready queue

    acquire_spinlock(&thread_q_lock);
    old_thread = cur_thread[hwthread];
    enqueue_thread(&ready_q, old_thread);
    next_thread = dequeue_thread(&ready_q);
    if (old_thread != next_thread)
    {
        cur_thread[hwthread] = next_thread;
        context_switch(&old_thread->current_stack,
            next_thread->current_stack,
            next_thread->map->page_dir,
            next_thread->map->asid);
    }

    release_spinlock(&thread_q_lock);
}


