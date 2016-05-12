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
#include "spinlock.h"
#include "thread.h"

static struct thread *cur_thread[MAX_CORES];

void boot_init_thread(struct thread *th)
{
    cur_thread[__builtin_nyuzi_read_control_reg(CR_CURRENT_THREAD)] = th;
}

void switch_to_thread(struct thread *th)
{
    // Hardware threads are treated as cores here.
    int core = __builtin_nyuzi_read_control_reg(CR_CURRENT_THREAD);
    struct thread *old_thread;

    old_thread = cur_thread[core];
    cur_thread[core] = th;
    context_switch(&old_thread->current_stack,
        th->current_stack,
        th->map->page_dir,
        th->map->asid);
}

struct thread *current_thread(void)
{
    int core = __builtin_nyuzi_read_control_reg(CR_CURRENT_THREAD);
    return cur_thread[core];
}
