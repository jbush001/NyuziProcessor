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
#include "loader.h"
#include "slab.h"
#include "spinlock.h"
#include "thread.h"
#include "vm_page.h"

extern __attribute__((noreturn)) void  jump_to_user_mode(
                              unsigned int inital_pc,
                              unsigned int user_stack_ptr,
                              int argc,
                              void *argv);

struct thread *cur_thread[MAX_CORES];
static struct thread_queue ready_q;
static spinlock_t thread_q_lock;
unsigned int kernel_stack_addr[MAX_CORES];

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

    // We will branch here from within reschedule, after context_switch.
    // Need to release the lock acquired at the beginning of that function.
    release_spinlock(&thread_q_lock);
    restore_interrupts(FLAG_INTERRUPT_EN | FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

    th->start_function(th->param);
}

struct thread *spawn_thread(struct vm_translation_map *map,
                            void (*start_function)(void *param),
                            void *param)
{
    int old_flags;
    struct thread *th;

    th = slab_alloc(&thread_slab);
    th->kernel_stack = (unsigned char*) kmalloc(0x2000) + 0x2000;
    th->current_stack = (unsigned char*) th->kernel_stack - 0x840;
    th->map = map;
    ((unsigned int*) th->current_stack)[0x814 / 4] = (unsigned int) thread_start;
    th->start_function = start_function;
    th->param = param;

    old_flags = disable_interrupts();
    acquire_spinlock(&thread_q_lock);
    enqueue_thread(&ready_q, th);
    release_spinlock(&thread_q_lock);
    restore_interrupts(old_flags);
}

void reschedule(void)
{
    int hwthread = __builtin_nyuzi_read_control_reg(CR_CURRENT_THREAD);
    struct thread *old_thread;
    struct thread *next_thread;
    int old_flags;

    // Put current thread back on ready queue

    old_flags = disable_interrupts();
    acquire_spinlock(&thread_q_lock);
    old_thread = cur_thread[hwthread];
    enqueue_thread(&ready_q, old_thread);
    next_thread = dequeue_thread(&ready_q);
    if (old_thread != next_thread)
    {
        cur_thread[hwthread] = next_thread;
        kernel_stack_addr[hwthread] = next_thread->kernel_stack;
        context_switch(&old_thread->current_stack,
            next_thread->current_stack,
            next_thread->map->page_dir,
            next_thread->map->asid);
    }

    release_spinlock(&thread_q_lock);
    restore_interrupts(old_flags);
}

// Kernel thread running in new address space starts here.
static void program_thread_start(void *data)
{
    unsigned int entry_point;
    int page_index;
    struct vm_translation_map *map = current_thread()->map;

    kprintf("Loading %s\n", (char*) data);
    if (load_program((char*) data, &entry_point) < 0)
        return;

    // Map 32k stack
    for (page_index = 0; page_index < 8; page_index++)
    {
        vm_map_page(map, 0xc0000000 - (page_index + 1) * PAGE_SIZE,
                    vm_allocate_page() | PAGE_WRITABLE | PAGE_PRESENT);
    }

    kprintf("About to jump to user start 0x%08x\n", entry_point);
    jump_to_user_mode(0, 0, entry_point, 0xc0000000);
}

void exec_program(const char *filename)
{
    struct vm_translation_map *map = new_translation_map();
    char *filename_copy = kmalloc(PAGE_SIZE);   // XXX hack
    strncpy(filename_copy, filename, PAGE_SIZE);
    filename_copy[PAGE_SIZE - 1] = '\0';
    spawn_thread(map, program_thread_start, filename_copy);
}
