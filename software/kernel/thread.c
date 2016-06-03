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
#include "kernel_heap.h"
#include "libc.h"
#include "loader.h"
#include "slab.h"
#include "spinlock.h"
#include "thread.h"
#include "trap.h"
#include "vm_page.h"

extern __attribute__((noreturn)) void  jump_to_user_mode(
    int argc,
    void *argv,
    unsigned int inital_pc,
    unsigned int user_stack_ptr);
extern void context_switch(unsigned int **old_stack_ptr_ptr,
                           unsigned int *new_stack_ptr,
                           unsigned int new_page_dir_addr,
                           unsigned int new_address_space_id);

struct thread *cur_thread[MAX_HW_THREADS];
static struct list_node ready_q;
static spinlock_t thread_q_lock;
static int next_thread_id;
static int next_process_id;
static struct process *kernel_proc;

// Used by fault handler when it performs stack switch
unsigned int trap_kernel_stack[MAX_HW_THREADS];

MAKE_SLAB(thread_slab, struct thread);
MAKE_SLAB(process_slab, struct process);

void bool_init_kernel_process(void)
{
    list_init(&ready_q);

    kernel_proc = slab_alloc(&process_slab);
    list_init(&kernel_proc->thread_list);
    kernel_proc->space = get_kernel_address_space();
    kernel_proc->id = 0;
    kernel_proc->lock = 0;
    next_process_id = 1;
}

void boot_init_thread(void)
{
    int old_flags;
    struct thread *th;

    th = slab_alloc(&thread_slab);
    th->state = THREAD_RUNNING;
    th->proc = kernel_proc;
    cur_thread[current_hw_thread()] = th;
    old_flags = disable_interrupts();
    acquire_spinlock(&kernel_proc->lock);
    list_add_tail(&kernel_proc->thread_list, &th->process_entry);
    release_spinlock(&kernel_proc->lock);
    restore_interrupts(old_flags);
}

struct thread *current_thread(void)
{
    return cur_thread[current_hw_thread()];
}

struct thread *spawn_thread_internal(struct process *proc,
                                     void (*kernel_start)(),
                                     void (*real_start)(void *param),
                                     void *param,
                                     int kernel_only)
{
    int old_flags;
    struct thread *th;

    th = slab_alloc(&thread_slab);
    th->kernel_stack_area = create_area(get_kernel_address_space(),
                                        0xffffffff, KERNEL_STACK_SIZE,
                                        PLACE_SEARCH_DOWN, "kernel stack",
                                        AREA_WIRED | AREA_WRITABLE, 0);
    th->kernel_stack_ptr = (unsigned int*) (th->kernel_stack_area->high_address + 1);
    th->current_stack = (unsigned int*) ((unsigned char*) th->kernel_stack_ptr - 0x840);
    th->proc = proc;
    ((unsigned int*) th->current_stack)[0x814 / 4] = (unsigned int) kernel_start;
    th->start_func = real_start;
    th->param = param;
    th->id = __sync_fetch_and_add(&next_thread_id, 1);
    th->state = THREAD_READY;
    if (!kernel_only)
    {
        th->user_stack_area = create_area(proc->space, 0xffffffff, 0x10000,
                                          PLACE_SEARCH_DOWN, "user stack",
                                          AREA_WRITABLE, 0);
    }

    old_flags = disable_interrupts();

    // Stick in process list
    acquire_spinlock(&proc->lock);
    list_add_tail(&kernel_proc->thread_list, &th->process_entry);
    release_spinlock(&proc->lock);

    // Put into ready queue
    acquire_spinlock(&thread_q_lock);
    list_add_tail(&ready_q, th);
    release_spinlock(&thread_q_lock);
    restore_interrupts(old_flags);

    return th;
}

static void user_thread_kernel_start(void)
{
    struct thread *th = current_thread();

    // We will branch here from within reschedule, after context_switch.
    // Need to release the lock acquired at the beginning of that function.
    release_spinlock(&thread_q_lock);
    restore_interrupts(FLAG_INTERRUPT_EN | FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

    jump_to_user_mode(0, 0, (unsigned int) th->start_func,
                      th->user_stack_area->high_address + 1);
}

struct thread *spawn_user_thread(struct process *proc,
                                 void (*start_function)(void *param),
                                 void *param)
{
    return spawn_thread_internal(proc, user_thread_kernel_start,
                                 start_function, 0, 0);
}

static void kernel_thread_kernel_start(void)
{
    struct thread *th = current_thread();

    // We will branch here from within reschedule, after context_switch.
    // Need to release the lock acquired at the beginning of that function.
    release_spinlock(&thread_q_lock);
    restore_interrupts(FLAG_INTERRUPT_EN | FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

    th->start_func(th->param);

    thread_exit(1);
}

struct thread *spawn_kernel_thread(void (*start_function)(void *param),
                                   void *param)
{
    return spawn_thread_internal(kernel_proc,
                                 kernel_thread_kernel_start,
                                 start_function, param, 1);
}

void reschedule(void)
{
    int hwthread = current_hw_thread();
    struct thread *old_thread;
    struct thread *next_thread;
    int old_flags;

    // Put current thread back on ready queue

    old_flags = disable_interrupts();
    acquire_spinlock(&thread_q_lock);
    old_thread = cur_thread[hwthread];
    assert(old_thread->state != THREAD_READY);

    if (old_thread->state == THREAD_RUNNING)
    {
        // If this thread is not running (blocked or dead),
        // don't add back to ready queue.
        old_thread->state = THREAD_READY;
        list_add_tail(&ready_q, old_thread);
    }

    next_thread = list_remove_head(&ready_q, struct thread);
    assert(next_thread);
    next_thread->state = THREAD_RUNNING;

    if (old_thread != next_thread)
    {
        cur_thread[hwthread] = next_thread;
        trap_kernel_stack[hwthread] = (unsigned int) next_thread->kernel_stack_ptr;
        context_switch(&old_thread->current_stack,
                       next_thread->current_stack,
                       next_thread->proc->space->translation_map->page_dir,
                       next_thread->proc->space->translation_map->asid);
    }

    release_spinlock(&thread_q_lock);
    restore_interrupts(old_flags);
}

static void new_process_start(void)
{
    struct thread *th = current_thread();

    // We will branch here from within reschedule, after context_switch.
    // Need to release the lock acquired at the beginning of that function.
    release_spinlock(&thread_q_lock);
    restore_interrupts(FLAG_INTERRUPT_EN | FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

    // XXX could pass argument information here.
    jump_to_user_mode(0, 0, (unsigned int) th->start_func,
                      th->user_stack_area->high_address + 1);
}

struct process *exec_program(const char *filename)
{
    struct process *proc;
    unsigned int entry_point;

    proc = slab_alloc(&process_slab);
    proc->id = __sync_fetch_and_add(&next_process_id, 1);
    proc->space = create_address_space();
    proc->lock = 0;

    if (load_program(proc, filename, &entry_point) < 0)
    {
        // XXX cleanup
        kprintf("load_program failed\n");
        return 0;
    }

    spawn_thread_internal(proc, new_process_start, entry_point, 0, 0);
    return proc;
}

void thread_exit(int retcode)
{
    (void) retcode;

    // XXX need to reap this threads resources
    current_thread()->state = THREAD_DEAD;
    reschedule();

    panic("dead thread was rescheduled!");
}

