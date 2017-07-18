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
// Parallel mandelbrot set renderer. The screen is divided between threads
// by scanline. Each thread uses its vector unit to compute the values of
// 16 values at a time. This means there are 64 pixels being computed at any
// time.
//

#include <nyuzi.h>
#include <schedule.h>
#include <stdint.h>
#include <stdio.h>
#include <vga.h>

#define mask_cmpf_lt __builtin_nyuzi_mask_cmpf_lt
#define mask_cmpi_ult __builtin_nyuzi_mask_cmpi_ult
#define mask_cmpi_uge __builtin_nyuzi_mask_cmpi_uge
#define vector_mixi __builtin_nyuzi_vector_mixi

const int MAX_ITERATIONS = 255;
const int SCREEN_WIDTH = 640;
const int SCREEN_HEIGHT = 480;
const float X_STEP = 2.5 / SCREEN_WIDTH;
const float Y_STEP = 2.0 / SCREEN_HEIGHT;
const int NUM_THREADS = 4;
const int VECTOR_LANES = 16;
volatile int stop_count = 0;
char *fb_base;
volatile int next_thread_id = 0;

// All threads start execution here.
int main()
{
    int my_thread_id = __sync_fetch_and_add(&next_thread_id, 1);
    if (my_thread_id == 0)
    {
        fb_base = init_vga(VGA_MODE_640x480);
        start_all_threads();
    }

    vecf16_t initial_x0 = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
    initial_x0 = initial_x0 * X_STEP - 2.0;

    // Stagger row access by thread ID
    for (int row = my_thread_id; row < SCREEN_HEIGHT; row += NUM_THREADS)
    {
        veci16_t *ptr = (veci16_t*)(fb_base + row * SCREEN_WIDTH * 4);
        vecf16_t x0 = initial_x0;
        float y0 = Y_STEP * row - 1.0;
        for (int col = 0; col < SCREEN_WIDTH; col += VECTOR_LANES)
        {
            // Compute colors for 16 pixels
            vecf16_t x = 0.0;
            vecf16_t y = 0.0;
            veci16_t iteration = 0;
            int active_lanes = 0xffff;

            // Escape loop
            while (1)
            {
                vecf16_t x_squared = x * x;
                vecf16_t y_squared = y * y;
                active_lanes &= mask_cmpf_lt(x_squared + y_squared, (vecf16_t) 4.0);
                active_lanes &= mask_cmpi_ult(iteration, (veci16_t) MAX_ITERATIONS);
                if (!active_lanes)
                    break;

                y = x * y * 2.0 + y0;
                x = x_squared - y_squared + x0;
                iteration = vector_mixi(active_lanes, iteration + 1, iteration);
            }

            // Set pixels inside set black and increase contrast
            *ptr = vector_mixi(mask_cmpi_uge(iteration, (veci16_t) 255),
                               (veci16_t) 0, (iteration << 2) + 80) | (veci16_t) 0xff000000;
            asm("dflush %0" : : "s" (ptr++));
            x0 += X_STEP * VECTOR_LANES;
        }
    }

    // Wait for other threads, because returning from main will kill all of them.
    __sync_fetch_and_add(&stop_count, 1);
    while (stop_count != NUM_THREADS)
        ;
}
