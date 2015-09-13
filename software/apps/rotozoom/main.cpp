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

#include <schedule.h>
#include <stdio.h>
#include "Barrier.h"
#include "image.h"
#include "Matrix2x2.h"

typedef int veci16 __attribute__((ext_vector_type(16)));
typedef float vecf16 __attribute__((ext_vector_type(16)));

const int kNumThreads = 4;
const int kVectorLanes = 16;
veci16* const kFrameBufferAddress = (veci16*) 0x200000;
const vecf16 kXOffsets = { 0.0f, 1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 
	8.0f, 9.0f, 10.0f, 11.0f, 12.0f, 13.0f, 14.0f, 15.0f };
const int kBytesPerPixel = 4;
const int kScreenWidth = 640;
const int kScreenHeight = 480;

Barrier<4> gFrameBarrier;	
Matrix2x2 displayMatrix;

int main()
{
	int frameNum = 0;
	int lastCycleCount = 0;
	
	startAllThreads();

	int myThreadId = __builtin_nyuzi_read_control_reg(0);
	if (myThreadId == 0)
		displayMatrix = Matrix2x2();

	// 1/64 step rotation
	Matrix2x2 stepMatrix(
		0.9987954562, -0.04906767432,
		0.04906767432, 0.9987954562);

	// Scale slightly
	stepMatrix = stepMatrix * Matrix2x2(0.99, 0.0, 0.0, 0.99);	

	// Threads work on interleaved chunks of pixels.  The thread ID determines
	// the starting point.
	while (true)
	{
		unsigned int imageBase = (unsigned int) kImage;
		veci16 *outputPtr = kFrameBufferAddress + myThreadId;
		for (int y = 0; y < kScreenHeight; y++)
		{
			for (int x = myThreadId * kVectorLanes; x < kScreenWidth; x += kNumThreads * kVectorLanes)
			{
				vecf16 xv = kXOffsets + __builtin_nyuzi_makevectorf((float) x) 
					- __builtin_nyuzi_makevectorf(kScreenWidth / 2);
				vecf16 yv = __builtin_nyuzi_makevectorf((float) y) 
					- __builtin_nyuzi_makevectorf(kScreenHeight / 2);;
				vecf16 u = xv * __builtin_nyuzi_makevectorf(displayMatrix.a)
					 + yv * __builtin_nyuzi_makevectorf(displayMatrix.b);
				vecf16 v = xv * __builtin_nyuzi_makevectorf(displayMatrix.c) 
					+ yv * __builtin_nyuzi_makevectorf(displayMatrix.d);
				
				veci16 tx = (__builtin_convertvector(u, veci16) & __builtin_nyuzi_makevectori(kImageWidth - 1));
				veci16 ty = (__builtin_convertvector(v, veci16) & __builtin_nyuzi_makevectori(kImageHeight - 1));
				veci16 pixelPtrs = (ty * __builtin_nyuzi_makevectori(kImageWidth * kBytesPerPixel)) 
					+ (tx * __builtin_nyuzi_makevectori(kBytesPerPixel)) 
					+ __builtin_nyuzi_makevectori(imageBase);
				*outputPtr = __builtin_nyuzi_gather_loadi(pixelPtrs);
				__asm("dflush %0" : : "r" (outputPtr));
				outputPtr += kNumThreads;	
			}
		}

		if (myThreadId == 0)
		{
			displayMatrix = displayMatrix * stepMatrix;

			if ((frameNum++ & 15) == 0)
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


