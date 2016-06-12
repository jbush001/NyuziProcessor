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

//
// This benchmark tests raw memory transfer speeds for reads, writes, and copies.
// It attempts to saturate the memory interface by using vector wide transfers and
// splitting the copy between multiple hardware threads to hide memory latency.
//

#include <nyuzi.h>
#include <schedule.h>
#include <stdint.h>
#include <stdio.h>

#define NUM_THREADS 4
#define LOOP_UNROLL 16

const int TRANSFER_SIZE = 0x200000;
void * const region_1_base = (void*) 0x200000;
void * const region_2_base = (void*) (0x200000 + TRANSFER_SIZE);
volatile int active_thread_count = 0;

void start_parallel(void)
{
    start_all_threads();
    __sync_fetch_and_add(&active_thread_count, 1);
}

void end_parallel(void)
{
    __sync_fetch_and_add(&active_thread_count, -1);
    while (active_thread_count > 0)
        ;

    if (get_current_thread_id() == 0)
    {
        // Stop all but me
        *((unsigned int*) 0xffff0104) = ~1;
    }
}

void copy_test(void)
{
    veci16_t *dest = (veci16_t*) region_1_base + get_current_thread_id() * LOOP_UNROLL;
    veci16_t *src = (veci16_t*) region_2_base + get_current_thread_id() * LOOP_UNROLL;
    int transfer_count = TRANSFER_SIZE / (64 * NUM_THREADS * LOOP_UNROLL);
    int unroll_count;

    int start_time = get_cycle_count();
    start_parallel();
    do
    {
        // The compiler will automatically unroll this
        for (unroll_count = 0; unroll_count < LOOP_UNROLL; unroll_count++)
            dest[unroll_count] = src[unroll_count];

        dest += NUM_THREADS * LOOP_UNROLL;
        src += NUM_THREADS * LOOP_UNROLL;
    }
    while (--transfer_count);
    end_parallel();
    if (get_current_thread_id() == 0)
    {
        int end_time = get_cycle_count();
        printf("copy: %g bytes/cycle\n", (float) TRANSFER_SIZE / (end_time - start_time));
    }
}

void read_test()
{
    // Because src is volatile, the loads below will not be optimized away
    volatile veci16_t *src = (veci16_t*) region_1_base + get_current_thread_id() * LOOP_UNROLL;
    veci16_t result;
    int transfer_count = TRANSFER_SIZE / (64 * NUM_THREADS * LOOP_UNROLL);
    int unroll_count;

    int start_time = get_cycle_count();
    start_parallel();
    do
    {
        // The compiler will automatically unroll this
        for (unroll_count = 0; unroll_count < LOOP_UNROLL; unroll_count++)
            result = src[unroll_count];

        src += NUM_THREADS * LOOP_UNROLL;
    }
    while (--transfer_count);
    end_parallel();
    if (get_current_thread_id() == 0)
    {
        int end_time = get_cycle_count();
        printf("read: %g bytes/cycle\n", (float) TRANSFER_SIZE / (end_time - start_time));
    }
}

void write_test()
{
    veci16_t *dest = (veci16_t*) region_1_base + get_current_thread_id() * LOOP_UNROLL;
    const veci16_t values = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 11, 14, 15 };
    int transfer_count = TRANSFER_SIZE / (64 * NUM_THREADS * LOOP_UNROLL);
    int unroll_count;

    int start_time = get_cycle_count();
    start_parallel();
    do
    {
        // The compiler will automatically unroll this
        for (unroll_count = 0; unroll_count < LOOP_UNROLL; unroll_count++)
            dest[unroll_count] = values;

        dest += NUM_THREADS * LOOP_UNROLL;
    }
    while (--transfer_count);
    end_parallel();
    if (get_current_thread_id() == 0)
    {
        int end_time = get_cycle_count();
        printf("write: %g bytes/cycle\n", (float) TRANSFER_SIZE / (end_time - start_time));
    }
}

void io_read_test()
{
    volatile uint32_t * const io_base = (volatile uint32_t*) 0xffff0004;
    int transfer_count;
    int start_time;
    int end_time;
    int total = 0;

    start_time = get_cycle_count();
    start_parallel();
    for (transfer_count = 0; transfer_count < 1024; transfer_count += 8)
    {
        total += *io_base;
        total += *io_base;
        total += *io_base;
        total += *io_base;
        total += *io_base;
        total += *io_base;
        total += *io_base;
        total += *io_base;
    }
    end_parallel();

    (void) total;

    if (get_current_thread_id() == 0)
    {
        end_time = get_cycle_count();
        printf("io_read: %g cycles/transfer\n", (float)(end_time - start_time)
               / (transfer_count * NUM_THREADS));
    }
}

void io_write_test()
{
    volatile uint32_t * const io_base = (volatile uint32_t*) 0xffff0004;
    int transfer_count;
    int start_time;
    int end_time;
    int total = 0;

    start_time = get_cycle_count();
    start_parallel();
    for (transfer_count = 0; transfer_count < 1024; transfer_count += 8)
    {
        *io_base = 0;
        *io_base = 0;
        *io_base = 0;
        *io_base = 0;
        *io_base = 0;
        *io_base = 0;
        *io_base = 0;
        *io_base = 0;
    }
    end_parallel();

    (void) total;

    if (get_current_thread_id() == 0)
    {
        end_time = get_cycle_count();
        printf("io_write: %g cycles/transfer\n", (float)(end_time - start_time)
               / (transfer_count * NUM_THREADS));
    }
}

int main(void)
{
    copy_test();
    read_test();
    write_test();
    io_read_test();
    io_write_test();

    return 0;
}


