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

struct thread *cur_thread[MAX_CORES];
static struct thread_queue ready_q;
static spinlock_t thread_q_lock;
static int next_thread_id;

// Used by fault handler when it performs stack switch
unsigned int trap_kernel_stack[MAX_CORES];

MAKE_SLAB(thread_slab, struct thread);

void boot_init_thread()
{
    struct thread *th = slab_alloc(&thread_slab);
    th->space = get_kernel_address_space();
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

struct thread *spawn_thread_internal(struct vm_address_space *space,
                            void (*kernel_start)(),
                            void (*real_start)(void *param),
                            void *param,
                            int kernel_only)
{
    int old_flags;
    struct thread *th;

    th = slab_alloc(&thread_slab);
    th->kernel_stack_area = create_area(get_kernel_address_space(),
        0xffffffff, 0x2000, PLACE_SEARCH_DOWN, "kernel stack", AREA_WIRED
        | AREA_WRITABLE, 0);
    th->kernel_stack_ptr = (unsigned int*) (th->kernel_stack_area->high_address + 1);
    th->current_stack = (unsigned int*) ((unsigned char*) th->kernel_stack_ptr - 0x840);
    th->space = space;
    ((unsigned int*) th->current_stack)[0x814 / 4] = (unsigned int) kernel_start;
    th->start_func = real_start;
    th->param = param;
    th->id = __sync_fetch_and_add(&next_thread_id, 1);
    if (!kernel_only)
    {
        th->user_stack_area = create_area(space, 0xffffffff, 0x10000,
            PLACE_SEARCH_DOWN, "user stack", AREA_WRITABLE, 0);
    }

    old_flags = disable_interrupts();
    acquire_spinlock(&thread_q_lock);
    enqueue_thread(&ready_q, th);
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

struct thread *spawn_user_thread(struct vm_address_space *space,
                            void (*start_function)(void *param),
                            void *param)
{
    return spawn_thread_internal(space, user_thread_kernel_start,
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
}

struct thread *spawn_kernel_thread(struct vm_address_space *space,
                            void (*start_function)(void *param),
                            void *param)
{
    return spawn_thread_internal(space, kernel_thread_kernel_start,
        start_function, param, 1);
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
        trap_kernel_stack[hwthread] = (unsigned int) next_thread->kernel_stack_ptr;
        context_switch(&old_thread->current_stack,
                       next_thread->current_stack,
                       next_thread->space->translation_map->page_dir,
                       next_thread->space->translation_map->asid);
    }

    release_spinlock(&thread_q_lock);
    restore_interrupts(old_flags);
}

static void loader_thread_start()
{
    unsigned int entry_point;
    int page_index;
    struct thread *th = current_thread();
    struct vm_address_space *space = th->space;

    // We will branch here from within reschedule, after context_switch.
    // Need to release the lock acquired at the beginning of that function.
    release_spinlock(&thread_q_lock);
    restore_interrupts(FLAG_INTERRUPT_EN | FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

    kprintf("Loading %s\n", (char*) th->param);
    if (load_program((char*) th->param, &entry_point) < 0)
    {
        kprintf("load_program failed\n");
        return;
    }

    dump_area_map(&th->space->area_map);
    kprintf("About to jump to user start 0x%08x\n", entry_point);
    jump_to_user_mode(0, 0, entry_point, th->user_stack_area->high_address + 1);
}

void exec_program(const char *filename)
{
    struct vm_address_space *space = create_address_space();
    char *filename_copy = kmalloc(PAGE_SIZE);   // XXX hack
    strncpy(filename_copy, filename, PAGE_SIZE);
    filename_copy[PAGE_SIZE - 1] = '\0';
    spawn_thread_internal(space, loader_thread_start, 0, filename_copy, 0);
    reschedule();
}
