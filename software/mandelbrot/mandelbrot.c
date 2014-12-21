// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 

#include <stdint.h>

#define splatf __builtin_nyuzi_makevectorf
#define splati __builtin_nyuzi_makevectori

const int kNumThreads = 4;
const int kScreenWidth = 640;
const int kScreenHeight = 480;
const float kXStep = 2.5 / kScreenWidth;
const float kYStep = 2.0 / kScreenHeight;
const int kVectorLanes = 16;

// Flush a data cache line from both L1 and L2.
inline void dflush(unsigned int address)
{
	asm("dflush %0" : : "s" (address));
}

int main()
{
	int myThreadId = __builtin_nyuzi_read_control_reg(0);
	vecf16_t kInitialX0 = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
	kInitialX0 = kInitialX0 * splatf(kXStep) - splatf(2.0);

	for (int row = myThreadId; row < kScreenHeight; row += kNumThreads)
	{
		veci16_t *ptr = (veci16_t*)(0x200000 + row * kScreenWidth * 4);
		vecf16_t x0 = kInitialX0;
		float y0 = kYStep * row - 1.0;
		for (int col = 0; col < kScreenWidth; col += kVectorLanes)
		{
			vecf16_t x = splatf(0.0);
			vecf16_t y = splatf(0.0);
			veci16_t iteration = splati(0);
			int activeLanes = 0xffff;
	
			// Escape loop
			while (1)
			{
				vecf16_t xSquared = x * x;
				vecf16_t ySquared = y * y;
				activeLanes &= __builtin_nyuzi_mask_cmpf_lt(xSquared + ySquared,
					splatf(4.0));
				activeLanes &= __builtin_nyuzi_mask_cmpi_ult(iteration, splati(255));
				if (!activeLanes)
					break;
		
				y = x * y * splatf(2.0) + splatf(y0);
				x = xSquared - ySquared + x0;
				iteration = __builtin_nyuzi_vector_mixi(activeLanes, iteration 
					+ splati(1), iteration);
			}

			// Set pixels inside set black and increase contrast
			*ptr = __builtin_nyuzi_vector_mixi(__builtin_nyuzi_mask_cmpi_uge(iteration, splati(255)), 
				splati(0), (iteration << splati(2)) + splati(80));
			dflush(ptr++);
			x0 += splatf(kXStep * kVectorLanes);
		}
	}
}
