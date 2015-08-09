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
#include <stdint.h>
#include <stdio.h>
#include "Barrier.h"

//
// Sum-of-sines demo style plasma effect
//

veci16_t* const kFrameBufferAddress = (veci16_t*) 0x200000;
const vecf16_t kXOffsets = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
const int kScreenWidth = 640;
const int kScreenHeight = 480;
const int kNumThreads = 4;

inline vecf16_t splatf(float f)
{
	return __builtin_nyuzi_makevectorf(f);
}

inline veci16_t splati(unsigned int i)
{
	return __builtin_nyuzi_makevectori(i);
}

inline vecf16_t absfv(vecf16_t value)
{
	return vecf16_t(veci16_t(value) & splati(0x7fffffff));
}

// Sine approximation using a polynomial
vecf16_t fast_sinfv(vecf16_t angle)
{
	const float B = 4.0 / M_PI;
	const float C = -4.0 / (M_PI * M_PI);
	
	// Wrap angle so it is in range -pi to pi (polynomial diverges outside 
	// this range).
	veci16_t whole = __builtin_convertvector(angle / splatf(M_PI), veci16_t);
	angle -= __builtin_convertvector(whole, vecf16_t) * splatf(M_PI);
	
	// Compute polynomial value
	vecf16_t result = angle * splatf(B) + angle * absfv(angle) * splatf(C);

	// Make the function flip properly if it is wrapped
	int resultSign = __builtin_nyuzi_mask_cmpi_ne(whole & splati(1), splati(0));
	return __builtin_nyuzi_vector_mixf(resultSign, -result, result);
}

inline vecf16_t fast_sqrtfv(vecf16_t number)
{
	// "Quake" fast square inverse root
	// https://en.wikipedia.org/wiki/Fast_inverse_square_root
	vecf16_t x2 = number * splatf(0.5f);
	vecf16_t y = vecf16_t(splati(0x5f3759df) - (veci16_t(number) >> splati(1))); 
	y = y * (splatf(1.5f) - (x2 * y * y));

	// y is now the inverse square root. Invert
	return splatf(1.0) / y;
}

vecf16_t sqrtfv(vecf16_t value)
{
	vecf16_t guess = value;
	for (int iteration = 0; iteration < 6; iteration++)
		guess = ((value / guess) + guess) / __builtin_nyuzi_makevectorf(2.0f);

	return guess;
}

#define NUM_PALETTE_ENTRIES 512

volatile int gFrameNum = 0;
Barrier<4> gFrameBarrier;
uint32_t gPalette[NUM_PALETTE_ENTRIES];
int lastCycleCount = 0;

// All threads start here
int main()
{
	int myThreadId = __builtin_nyuzi_read_control_reg(0);
	
	if (myThreadId == 0)
	{
		for (int i = 0; i < NUM_PALETTE_ENTRIES; i++)
		{
#ifdef STRIPES
			int j = (i >> 3) & 1 ? 0xff : 0;
			gPalette[i] = (j << 16) | (j << 8) | j;
#else
			gPalette[i] = (uint32_t(128 + 127 * sin(M_PI * i / (NUM_PALETTE_ENTRIES / 8))) << 16)
				| (uint32_t(128 + 127 * sin(M_PI * i / (NUM_PALETTE_ENTRIES / 4))) << 8)
				| uint32_t(128 + 127 * sin(M_PI * i / (NUM_PALETTE_ENTRIES / 2)));
#endif
		}

		__builtin_nyuzi_write_control_reg(30, 0xffffffff); // Start all threads
	}
	
	for (;;)
	{
		for (int y = myThreadId; y < kScreenHeight; y += kNumThreads)
		{
			veci16_t *ptr = kFrameBufferAddress + y * kScreenWidth / 16;
			for (int x = 0; x < kScreenWidth; x += 16)
			{
				vecf16_t xv = (splatf((float) x) + kXOffsets) / splatf(kScreenWidth / 7);
				vecf16_t yv = splatf((float) y) / splatf(kScreenHeight / 7);
				vecf16_t tv = splatf((float) gFrameNum / 15);

				vecf16_t fintensity = splatf(0.0);
				fintensity += fast_sinfv(xv + tv);
				fintensity += fast_sinfv((yv - tv) * splatf(0.5));
				fintensity += fast_sinfv((xv + yv * splatf(0.3) + tv) * splatf(0.5));
				fintensity += fast_sinfv(fast_sqrtfv(xv * xv + yv * yv) * splatf(0.2) + tv);

				// Assuming value is -4.0 to 4.0, convert to an index in the pallete table,
				// fetch the color value, and write to the framebuffer
				*ptr = __builtin_nyuzi_gather_loadi((__builtin_convertvector(fintensity * splatf(NUM_PALETTE_ENTRIES / 8)
					+ splatf(NUM_PALETTE_ENTRIES / 2), veci16_t) << splati(2)) + splati((unsigned int) gPalette));
				asm("dflush %0" : : "s" (ptr));
				ptr++;
			}
		}

		if (myThreadId == 0)
		{
			if ((gFrameNum++ & 15) == 0)
			{
				const float kClockRate = 50000000.0;
				volatile unsigned int * const REGISTERS = (volatile unsigned int*) 0xffff0000;
				unsigned int curCycleCount = __builtin_nyuzi_read_control_reg(6);
				if (lastCycleCount != 0)
				{
					// XXX this is only accurate in the hardware model, not emulator
					printf("%g fps\n", kClockRate * 16 / (curCycleCount - lastCycleCount));
				}

				lastCycleCount = curCycleCount;
			}
		}

		gFrameBarrier.wait();
	}

	return 0;
}
