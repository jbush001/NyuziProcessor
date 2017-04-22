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
extern void start_timer(void);
extern void context_switch(unsigned int **old_stack_ptr_ptr,
                           unsigned int *new_stack_ptr);
static void timer_tick(void);

struct thread *cur_thread[MAX_HW_THREADS];
static int disable_preempt_count[MAX_HW_THREADS];
static spinlock_t thread_q_lock;
static struct list_node ready_q;
static struct list_node dead_q;
static int next_thread_id;
static int next_process_id;
static struct process *kernel_proc;
static struct list_node process_list;
static spinlock_t process_list_lock;

// Used by fault handler when it performs stack switch
unsigned int trap_kernel_stack[MAX_HW_THREADS];

MAKE_SLAB(thread_slab, struct thread)
MAKE_SLAB(process_slab, struct process)

void bool_init_kernel_process(void)
{
    list_init(&ready_q);
    list_init(&dead_q);
    list_init(&process_list);

    kernel_proc = slab_alloc(&process_slab);
    list_init(&kernel_proc->thread_list);
    kernel_proc->space = get_kernel_address_space();
    kernel_proc->id = 0;
    kernel_proc->lock = 0;
    list_add_tail(&process_list, kernel_proc);
    next_process_id = 1;
}

void boot_init_thread(void)
{
    int old_flags;
    struct thread *th;

    th = slab_alloc(&thread_slab);
    th->state = THREAD_RUNNING;
    th->proc = kernel_proc;
    th->id = __sync_fetch_and_add(&next_thread_id, 1);
    strlcpy(th->name, "idle_thread", sizeof(th->name));

    cur_thread[current_hw_thread()] = th;
    old_flags = acquire_spinlock_int(&kernel_proc->lock);
    list_add_tail(&kernel_proc->thread_list, &th->process_entry);
    release_spinlock_int(&kernel_proc->lock, old_flags);

    register_interrupt_handler(1, timer_tick);
    start_timer();
}

struct thread *current_thread(void)
{
    return cur_thread[current_hw_thread()];
}

struct thread *spawn_thread_internal(const char *name,
                                     struct process *proc,
                                     void (*init_func)(),
                                     thread_start_func_t start_func,
                                     void *param,
                                     int kernel_only)
{
    int old_flags;
    struct thread *th;

    th = slab_alloc(&thread_slab);
    strlcpy(th->name, name, sizeof(th->name));
    th->kernel_stack_area = create_area(get_kernel_address_space(),
                                        0xffffffff, KERNEL_STACK_SIZE,
                                        PLACE_SEARCH_DOWN, "kernel stack",
                                        AREA_WIRED | AREA_WRITABLE, 0, 0);
    th->kernel_stack_ptr = (unsigned int*) (th->kernel_stack_area->high_address + 1);
    th->current_stack = (unsigned int*) ((unsigned char*) th->kernel_stack_ptr - 0x840);
    th->proc = proc;
    ((unsigned int*) th->current_stack)[0x818 / 4] = (unsigned int) init_func;
    th->start_func = start_func;
    th->param = param;
    th->id = __sync_fetch_and_add(&next_thread_id, 1);
    th->state = THREAD_READY;
    if (!kernel_only)
    {
        th->user_stack_area = create_area(proc->space, 0xffffffff, 0x10000,
                                          PLACE_SEARCH_DOWN, "user stack",
                                          AREA_WRITABLE, 0, 0);
    }
    else
        th->user_stack_area = 0;

    old_flags = disable_interrupts();

    // Stick in process list
    acquire_spinlock(&proc->lock);
    list_add_tail(&proc->thread_list, &th->process_entry);
    release_spinlock(&proc->lock);

    // Put into ready queue
    acquire_spinlock(&thread_q_lock);
    list_add_tail(&ready_q, th);
    release_spinlock(&thread_q_lock);
    restore_interrupts(old_flags);

    return th;
}

static void timer_tick(void)
{
    start_timer();
    ack_interrupt(1);
    if (disable_preempt_count[current_hw_thread()] == 0)
        reschedule();
}

static void destroy_thread(struct thread *th)
{
    struct process *proc = th->proc;
    int old_flags;

    VM_DEBUG("cleaning up thread %d (%s)\n", th->id, th->name);

    assert(th->state == THREAD_DEAD);

    old_flags = acquire_spinlock_int(&proc->lock);
    list_remove_node(&th->process_entry);
    release_spinlock_int(&proc->lock, old_flags);

    // A thread cannot clean itself up. The kernel stack would go away and
    // crash.
    assert(th != current_thread());

    if (th->user_stack_area)
    {
        VM_DEBUG("free user stack\n");
        destroy_area(th->proc->space, th->user_stack_area);
    }

    VM_DEBUG("free kernel stack\n");
    destroy_area(th->proc->space, th->kernel_stack_area);
    slab_free(&thread_slab, th);
    dec_proc_ref(proc);
}

void dec_proc_ref(struct process *proc)
{
    int old_flags;

    assert(current_thread()->proc != proc);

    if (__sync_add_and_fetch(&proc->ref_count, -1) == 0)
    {
        VM_DEBUG("destroying process %d\n", proc->id);
        assert(list_is_empty(&proc->thread_list));

        old_flags = acquire_spinlock_int(&process_list_lock);
        list_remove_node(proc);
        release_spinlock_int(&process_list_lock, old_flags);

        destroy_address_space(proc->space);
        slab_free(&process_slab, proc);
    }
}

int grim_reaper(void *ignore)
{
    struct thread *th;
    int old_flags;

    (void) ignore;

    // Pull off dead thread list
    // call destroy_thread
    for (;;)
    {
        // Dequeue a thread to kill
        old_flags = acquire_spinlock_int(&thread_q_lock);
        th = list_remove_head(&dead_q, struct thread);
        release_spinlock_int(&thread_q_lock, old_flags);

        if (th == 0)
        {
            reschedule();   // XXX currently no way to wait
            continue;
        }

        VM_DEBUG("grim_reaper harvesting thread %d (%s)\n", th->id, th->name);
        destroy_thread(th);
        VM_DEBUG("it is done\n");
    }
}

static void __attribute__((noreturn)) user_thread_kernel_start(void)
{
    struct thread *th = current_thread();

    // We will branch here from within reschedule, after context_switch.
    // Need to release the lock acquired at the beginning of that function.
    release_spinlock(&thread_q_lock);
    restore_interrupts(FLAG_INTERRUPT_EN | FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

    jump_to_user_mode(0, 0, (unsigned int) th->start_func,
                      th->user_stack_area->high_address + 1);
}

struct thread *spawn_user_thread(const char *name, struct process *proc,
                                 unsigned int start_address,
                                 void *param)
{
    (void) param;

    return spawn_thread_internal(name, proc, user_thread_kernel_start,
                                 (thread_start_func_t) start_address, 0, 0);
}

static void __attribute__((noreturn)) kernel_thread_kernel_start(void)
{
    struct thread *th = current_thread();

    // We will branch here from within reschedule, after context_switch.
    // Need to release the lock acquired at the beginning of that function.
    release_spinlock(&thread_q_lock);
    restore_interrupts(FLAG_INTERRUPT_EN | FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

    th->start_func(th->param);

    thread_exit(1);
}

struct thread *spawn_kernel_thread(const char *name,
                                   thread_start_func_t start_func,
                                   void *param)
{
    return spawn_thread_internal(name, kernel_proc, kernel_thread_kernel_start,
                                 start_func, param, 1);
}

void reschedule(void)
{
    int hwthread = current_hw_thread();
    struct thread *old_thread;
    struct thread *next_thread;
    int old_flags;

    assert(!disable_preempt_count[hwthread]);

    // Put current thread back on ready queue

    old_flags = acquire_spinlock_int(&thread_q_lock);
    old_thread = cur_thread[hwthread];
    assert(old_thread->state != THREAD_READY);

    if (old_thread->state == THREAD_RUNNING)
    {
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
        switch_to_translation_map(next_thread->proc->space->translation_map);
        context_switch(&old_thread->current_stack, next_thread->current_stack);
    }

    release_spinlock_int(&thread_q_lock, old_flags);
}

void disable_preempt(void)
{
    __sync_fetch_and_add(&disable_preempt_count[current_hw_thread()], 1);
}

void enable_preempt(void)
{
    __sync_fetch_and_add(&disable_preempt_count[current_hw_thread()], -1);
}

static void __attribute__((noreturn)) new_process_start(void)
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
    int old_flags;

    proc = slab_alloc(&process_slab);
    proc->id = __sync_fetch_and_add(&next_process_id, 1);
    proc->space = create_address_space();
    proc->lock = 0;
    proc->ref_count = 2; // one ref for thread, one for returned pointer
    list_init(&proc->thread_list);

    old_flags = disable_interrupts();
    acquire_spinlock(&process_list_lock);
    list_add_tail(&process_list, proc);
    release_spinlock(&process_list_lock);
    restore_interrupts(old_flags);

    if (load_program(proc, filename, &entry_point) < 0)
    {
        // XXX cleanup
        kprintf("load_program failed\n");
        return 0;
    }

    spawn_thread_internal("user_thread", proc, new_process_start,
        (thread_start_func_t) entry_point, 0, 0);
    return proc;
}

void thread_exit(int retcode)
{
    struct thread *th = current_thread();
    (void) retcode;

    VM_DEBUG("thread %d (%s) exited\n", th->id, th->name);

    // Disable pre-emption
    disable_interrupts();

    acquire_spinlock(&thread_q_lock);
    list_add_tail(&dead_q, th);
    release_spinlock(&thread_q_lock);
    th->state = THREAD_DEAD;
    reschedule();

    // Never will return...

    panic("dead thread was rescheduled!");
}

void make_thread_ready(struct thread *th)
{
    int old_flags;

    assert(th->state != THREAD_READY);
    assert(th->state != THREAD_RUNNING);
    assert(th->state != THREAD_DEAD);

    old_flags = acquire_spinlock_int(&thread_q_lock);
    th->state = THREAD_READY;
    list_add_tail(&ready_q, th);
    release_spinlock_int(&thread_q_lock, old_flags);
}

void dump_process_list(void)
{
    int old_flags;
    struct process *proc;
    struct thread *th;

    kprintf("process list\n");
    old_flags = acquire_spinlock_int(&process_list_lock);
    list_for_each(&process_list, proc, struct process)
    {
        kprintf("process %d\n", proc->id);
        acquire_spinlock(&proc->lock);
        multilist_for_each(&proc->thread_list, th, process_entry, struct thread)
            kprintf("  thread %d %p %s\n", th->id, th, th->name);

        release_spinlock(&proc->lock);
    }

    release_spinlock_int(&process_list_lock, old_flags);
}

