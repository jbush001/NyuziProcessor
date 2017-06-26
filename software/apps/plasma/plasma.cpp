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

#include <math.h>
#include <nyuzi.h>
#include <stdint.h>
#include <stdio.h>
#include <schedule.h>
#include <time.h>
#include <vga.h>
#include "Barrier.h"

//
// Sum-of-sines demo style plasma effect
//

veci16_t* fb_address;
const vecf16_t kXOffsets = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
const int kScreenWidth = 640;
const int kScreenHeight = 480;
const int kNumThreads = 4;

inline vecf16_t absfv(vecf16_t value)
{
    return vecf16_t(veci16_t(value) & 0x7fffffff);
}


vecf16_t fmodv(vecf16_t val1, vecf16_t val2)
{
    veci16_t whole = __builtin_convertvector(val1 / val2, veci16_t);
    return val1 - __builtin_convertvector(whole, vecf16_t) * val2;
}

//
// Use taylor series to approximate sine
//   x - x**3/3! + x**5/5! - x**7/7! ...
//

const double kDenominators[] = {
    -0.166666666666667f,  // 1 / 3!
    0.008333333333333f,   // 1 / 5!
    -0.000198412698413f,  // 1 / 7!
    0.000002755731922f,   // 1 / 9!
    -2.50521084e-8f,      // 1 / 11!
    1.6059044e-10f        // 1 / 13!
};

vecf16_t slow_sinfv(vecf16_t angle)
{
    // The approximation begins to diverge past 0-pi/2. To prevent
    // discontinuities, mirror or flip this function for each portion of
    // the result
    angle = fmodv(angle, vecf16_t(M_PI * 2));

    int resultSign = __builtin_nyuzi_mask_cmpf_lt(angle, vecf16_t(0.0));

    angle = vecf16_t(veci16_t(angle) & 0x7fffffff); // fabs

    int cmp1 = __builtin_nyuzi_mask_cmpf_gt(angle, vecf16_t(M_PI * 3 / 2));
    angle = __builtin_nyuzi_vector_mixf(cmp1, vecf16_t(M_PI * 2) - angle, angle);
    resultSign ^= cmp1;

    int cmp2 = __builtin_nyuzi_mask_cmpf_gt(angle, vecf16_t(M_PI));
    int mask2 = cmp2 & ~cmp1;
    angle = __builtin_nyuzi_vector_mixf(mask2, angle - M_PI, angle);
    resultSign ^= mask2;

    int cmp3 = __builtin_nyuzi_mask_cmpf_gt(angle, vecf16_t(M_PI / 2));
    int mask3 = cmp3 & ~(cmp1 | cmp2);
    angle = __builtin_nyuzi_vector_mixf(mask3, vecf16_t(M_PI) - angle, angle);

    vecf16_t angleSquared = angle * angle;
    vecf16_t numerator = angle;
    vecf16_t result = angle;

    for (auto denominator : kDenominators)
    {
        numerator *= angleSquared;
        result += numerator * denominator;
    }

    return __builtin_nyuzi_vector_mixf(resultSign, -result, result);
}

// Sine approximation using a polynomial
vecf16_t fast_sinfv(vecf16_t angle)
{
    const float B = 4.0 / M_PI;
    const float C = -4.0 / (M_PI * M_PI);

    // Wrap angle so it is in range -pi to pi (polynomial diverges outside
    // this range).
    veci16_t whole = __builtin_convertvector(angle / M_PI, veci16_t);
    angle -= __builtin_convertvector(whole, vecf16_t) * M_PI;

    // Compute polynomial value
    vecf16_t result = angle * B + angle * absfv(angle) * C;

    // Make the function flip properly if it is wrapped
    int resultSign = __builtin_nyuzi_mask_cmpi_ne(whole & 1, veci16_t(0));
    return __builtin_nyuzi_vector_mixf(resultSign, -result, result);
}

inline vecf16_t fast_sqrtfv(vecf16_t number)
{
    // "Quake" fast square inverse root
    // https://en.wikipedia.org/wiki/Fast_inverse_square_root
    vecf16_t x2 = number * 0.5f;
    vecf16_t y = vecf16_t(0x5f3759df - (veci16_t(number) >> 1));
    y = y * (1.5f - (x2 * y * y));

    // y is the inverse square root. Invert again to get the square root.
    return 1.0 / y;
}

vecf16_t slow_sqrtfv(vecf16_t value)
{
    vecf16_t guess = value;
    for (int iteration = 0; iteration < 6; iteration++)
        guess = ((value / guess) + guess) / 2.0f;

    return guess;
}

#define NUM_PALETTE_ENTRIES 512

int gFrameNum = 0;
Barrier<4> gFrameBarrier;
uint32_t gPalette[NUM_PALETTE_ENTRIES];
volatile int gThreadId = 0;

// All threads start here
int main()
{
    int myThreadId = __sync_fetch_and_add(&gThreadId, 1);
    clock_t lastTime = 0;

    if (myThreadId == 0)
    {
        fb_address = (veci16_t*) init_vga(VGA_MODE_640x480);
        for (int i = 0; i < NUM_PALETTE_ENTRIES; i++)
        {
#ifdef STRIPES
            int j = ((i >> 3) & 1) != 0 ? 0xff : 0;
            gPalette[i] = (j << 16) | (j << 8) | j;
#else
            gPalette[i] = (uint32_t(128 + 127 * sin(M_PI * i / (NUM_PALETTE_ENTRIES / 8))) << 16)
                          | (uint32_t(128 + 127 * sin(M_PI * i / (NUM_PALETTE_ENTRIES / 4))) << 8)
                          | uint32_t(128 + 127 * sin(M_PI * i / (NUM_PALETTE_ENTRIES / 2)));
#endif
        }

        start_all_threads();
    }

    for (;;)
    {
        for (int y = myThreadId; y < kScreenHeight; y += kNumThreads)
        {
            veci16_t *ptr = fb_address + y * kScreenWidth / 16;
            for (int x = 0; x < kScreenWidth; x += 16)
            {
                vecf16_t xv = (kXOffsets + float(x)) / (kScreenWidth / 7);
                vecf16_t yv = float(y) / (kScreenHeight / 7);
                vecf16_t tv = float(gFrameNum) / 15.0;

                vecf16_t fintensity = 0.0;
                fintensity += fast_sinfv(xv + tv);
                fintensity += fast_sinfv((yv - tv) * 0.5);
                fintensity += fast_sinfv((xv + yv * 0.3 + tv) * 0.5);
                fintensity += fast_sinfv(fast_sqrtfv(xv * xv + yv * yv) * 0.2 + tv);

                // Assuming value is -4.0 to 4.0, convert to an index in the pallete table,
                // fetch the color value, and write to the framebuffer
                *ptr = __builtin_nyuzi_gather_loadi((__builtin_convertvector(fintensity * (NUM_PALETTE_ENTRIES / 8)
                                                     + (NUM_PALETTE_ENTRIES / 2), veci16_t) << 2) + (unsigned int) gPalette);
                asm("dflush %0" : : "s" (ptr));
                ptr++;
            }
        }

        if (myThreadId == 0)
        {
            if ((gFrameNum++ & 15) == 0)
            {
                unsigned int currentTime = clock();
                if (lastTime != 0)
                {
                    float deltaTime = (float)(currentTime - lastTime) / CLOCKS_PER_SEC;
                    printf("%g fps\n", (float) 16 / deltaTime);
                }

                lastTime = currentTime;
            }
        }

        gFrameBarrier.wait();
    }

    return 0;
}
