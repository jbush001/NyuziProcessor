//
// Copyright 2011-2015 Jeff Bush
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

#include <stdio.h>
#include "registers.h"
#include "schedule.h"

static parallel_func_t current_func;
static volatile int current_index;
static volatile int max_index;
static volatile int active_jobs;
static void * volatile context;

static int dispatch_job(void)
{
    int this_index;

    do
    {
        this_index = current_index;
        if (this_index == max_index)
            return 0;	// No more jobs in this batch
    }
    while (!__sync_bool_compare_and_swap(&current_index, this_index, this_index + 1));

    current_func(context, this_index);

    return 1;
}

void parallel_execute(parallel_func_t func, void *_context, int num_elements)
{
    current_func = func;
    context = _context;
    current_index = 0;
    max_index = num_elements;

    while (current_index != max_index)
        dispatch_job();

    while (active_jobs)
        ; // Wait for threads to finish
}

void worker_thread(void)
{
    while (1)
    {
        while (current_index == max_index)
            ;

        __sync_fetch_and_add(&active_jobs, 1);
        dispatch_job();
        __sync_fetch_and_add(&active_jobs, -1);
    }
}

void start_all_threads(void)
{
    REGISTERS[REG_THREAD_RESUME] = 0xffffffff;
}
