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


#include <stdint.h>

#define makevectorf __builtin_nyuzi_makevectorf
#define makevectori __builtin_nyuzi_makevectori
#define mask_cmpf_lt __builtin_nyuzi_mask_cmpf_lt
#define mask_cmpi_ult __builtin_nyuzi_mask_cmpi_ult
#define mask_cmpi_uge __builtin_nyuzi_mask_cmpi_uge
#define vector_mixi __builtin_nyuzi_vector_mixi

const int kMaxIterations = 255;
const int kScreenWidth = 640;
const int kScreenHeight = 480;
const char *kFbBase = (const char*) 0x200000;
const float kXStep = 2.5 / kScreenWidth;
const float kYStep = 2.0 / kScreenHeight;
const int kNumThreads = 4;
const int kVectorLanes = 16;

// All threads start execution here.
int main()
{
	__builtin_nyuzi_write_control_reg(30, 0xffffffff);

	int myThreadId = __builtin_nyuzi_read_control_reg(0);
	vecf16_t kInitialX0 = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
	kInitialX0 = kInitialX0 * makevectorf(kXStep) - makevectorf(2.0);

	// Stagger row access by thread ID
	for (int row = myThreadId; row < kScreenHeight; row += kNumThreads)
	{
		veci16_t *ptr = (veci16_t*)(kFbBase + row * kScreenWidth * 4);
		vecf16_t x0 = kInitialX0;
		float y0 = kYStep * row - 1.0;
		for (int col = 0; col < kScreenWidth; col += kVectorLanes)
		{
			// Compute colors for 16 pixels
			vecf16_t x = makevectorf(0.0);
			vecf16_t y = makevectorf(0.0);
			veci16_t iteration = makevectori(0);
			int activeLanes = 0xffff;
	
			// Escape loop
			while (1)
			{
				vecf16_t xSquared = x * x;
				vecf16_t ySquared = y * y;
				activeLanes &= mask_cmpf_lt(xSquared + ySquared, makevectorf(4.0));
				activeLanes &= mask_cmpi_ult(iteration, makevectori(kMaxIterations));
				if (!activeLanes)
					break;
		
				y = x * y * makevectorf(2.0) + makevectorf(y0);
				x = xSquared - ySquared + x0;
				iteration = vector_mixi(activeLanes, iteration + makevectori(1), iteration);
			}

			// Set pixels inside set black and increase contrast
			*ptr = vector_mixi(mask_cmpi_uge(iteration, makevectori(255)), 
				makevectori(0), (iteration << makevectori(2)) + makevectori(80));
			asm("dflush %0" : : "s" (ptr++));
			x0 += makevectorf(kXStep * kVectorLanes);
		}
	}
}
