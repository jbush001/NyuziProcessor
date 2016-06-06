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
#include "rwlock.h"
#include "registers.h"
#include "slab.h"
#include "thread.h"
#include "trap.h"
#include "vm_area_map.h"
#include "vm_cache.h"
#include "vm_page.h"
#include "vm_translation_map.h"
#include "vm_address_space.h"

#define TIMER_INTERVAL 500000

void start_timer(void)
{
    REGISTERS[REG_TIMER_INTERVAL] = TIMER_INTERVAL;
}

void timer_tick(void)
{
    REGISTERS[REG_TIMER_INTERVAL] = TIMER_INTERVAL;

    // XXX will this prevent the interrupt in some cases from being
    // delivered to other processes?
    ack_interrupt(1);
    reschedule();
}

void kernel_main(unsigned int memory_size)
{
    struct vm_translation_map *init_map;

    vm_page_init(memory_size);
    init_map = vm_translation_map_init();
    boot_init_heap((char*) KERNEL_HEAP_BASE + PAGE_STRUCTURES_SIZE(memory_size));
    vm_address_space_init(init_map);
    bootstrap_vm_cache();
    bool_init_kernel_process();
    boot_init_thread();

    register_interrupt_handler(1, timer_tick);
    start_timer();

    // Start other threads
    REGISTERS[REG_THREAD_RESUME] = 0xffffffff;

    // Enable timer interrupt on other hardware threads
    REGISTERS[REG_INT_MASK0 + 1] = 2;
    REGISTERS[REG_INT_MASK0 + 2] = 2;
    REGISTERS[REG_INT_MASK0 + 3] = 2;

    spawn_kernel_thread("Grim Reaper", grim_reaper, 0);

    exec_program("program.elf");

    // Idle task
    for (;;)
        reschedule();
}

void thread_n_main(void)
{
    boot_init_thread();

    // Idle task
    for (;;)
        reschedule();
}

