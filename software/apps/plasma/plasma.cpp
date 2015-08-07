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

vecf16_t fmodv(vecf16_t val1, vecf16_t val2)
{
	veci16_t whole = __builtin_convertvector(val1 / val2, veci16_t);
	return val1 - __builtin_convertvector(whole, vecf16_t) * val2;
}

//
// Use taylor series to approximate sine
//   x - x**3/3! + x**5/5! - x**7/7! ...
//

const int kNumTerms = 6;

const double denominators[] = {
	-0.166666666666667f,  // 1 / 3!
	0.008333333333333f,   // 1 / 5!
	-0.000198412698413f,  // 1 / 7!
	0.000002755731922f,	  // 1 / 9!
	-2.50521084e-8f,      // 1 / 11!
	1.6059044e-10f        // 1 / 13!
};

vecf16_t fsinv(vecf16_t angle)
{
	// The approximation begins to diverge past 0-pi/2. To prevent
	// discontinuities, mirror or flip this function for each portion of
	// the result
	angle = fmodv(angle, splatf(M_PI * 2));

	int resultSign = __builtin_nyuzi_mask_cmpf_lt(angle, splatf(0.0));

	angle = ((veci16_t)angle) & splati(0x7fffffff);	// fabs

	int cmp1 = __builtin_nyuzi_mask_cmpf_gt(angle, splatf(M_PI * 3 / 2));
	angle = __builtin_nyuzi_vector_mixf(cmp1, splatf(M_PI * 2) - angle, angle);
	resultSign ^= cmp1;

	int cmp2 = __builtin_nyuzi_mask_cmpf_gt(angle, splatf(M_PI));
	int mask2 = cmp2 & ~cmp1;
	angle = __builtin_nyuzi_vector_mixf(mask2, angle - splatf(M_PI), angle);
	resultSign ^= mask2;

	int cmp3 = __builtin_nyuzi_mask_cmpf_gt(angle, splatf(M_PI / 2));
	int mask3 = cmp3 & ~(cmp1 | cmp2);
	angle = __builtin_nyuzi_vector_mixf(mask3, splatf(M_PI) - angle, angle);

	vecf16_t angleSquared = angle * angle;
	vecf16_t numerator = angle;
	vecf16_t result = angle;

	for (int i = 0; i < kNumTerms; i++)
	{
		numerator *= angleSquared;
		result += numerator * splatf(denominators[i]);
	}

	return __builtin_nyuzi_vector_mixf(resultSign, -result, result);
}

inline vecf16_t sqrtfv(vecf16_t value)
{
	vecf16_t guess = value;
	for (int iteration = 0; iteration < 6; iteration++)
		guess = ((value / guess) + guess) / __builtin_nyuzi_makevectorf(2.0f);

	return guess;
}

volatile int gFrameNum = 0;
Barrier<4> gFrameBarrier;
uint32_t gPalette[256];


// All threads start here
int main()
{
	int myThreadId = __builtin_nyuzi_read_control_reg(0);
	
	if (myThreadId == 0)
	{
		for (int i = 0; i < 256; i++)
		{
			gPalette[i] = (uint32_t(128.0 + 127.0 * sin(M_PI * i / 32.0)) << 16)
				| (uint32_t(128.0 + 127.0 * sin(M_PI * i / 64.0)) << 8)
				| uint32_t(128.0 + 127.0 * sin(M_PI * i / 128.0));
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
				fintensity += fsinv(xv);
				fintensity += fsinv((yv + tv) * splatf(0.5));
				fintensity += fsinv((xv + yv * splatf(0.3) + tv) * splatf(0.5));
				fintensity += fsinv(sqrtfv(xv * xv + yv * yv) * splatf(0.2) + tv);

				*ptr = __builtin_nyuzi_gather_loadi((__builtin_convertvector(fintensity * splatf(31.0)
					+ splatf(128), veci16_t) << splati(2)) + splati((unsigned int) gPalette));
				asm("dflush %0" : : "s" (ptr));
				ptr++;
			}
		}

		if (myThreadId == 0)
			__sync_fetch_and_add(&gFrameNum, 1);

		gFrameBarrier.wait();
	}

	return 0;
}
