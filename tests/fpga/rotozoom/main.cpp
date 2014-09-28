// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
// 



#include "Barrier.h"
#include "Matrix2x2.h"

typedef int veci16 __attribute__((ext_vector_type(16)));
typedef float vecf16 __attribute__((ext_vector_type(16)));

veci16* const kFrameBufferAddress = (veci16*) 0x10000000;
const vecf16 kXOffsets = { 0.0f, 1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 
	8.0f, 9.0f, 10.0f, 11.0f, 12.0f, 13.0f, 14.0f, 15.0f };
extern unsigned int kImage[];
const int kImageWidth = 16;
const int kImageHeight = 16;
const int kBytesPerPixel = 4;
const int kScreenWidth = 640;
const int kScreenHeight = 480;

void dflush(void *ptr)
{
	__asm("dflush %0" : : "r" (ptr));
}

Barrier<4> gFrameBarrier;	// We don't execute global ctors yet, but I know this is fine.
Matrix2x2 displayMatrix;

int main()
{
	int myStrandId = __builtin_nyuzi_read_control_reg(0);
	if (myStrandId == 0)
		displayMatrix = Matrix2x2();

	// 1/64 step rotation
	Matrix2x2 stepMatrix(
		0.9987954562, -0.04906767432,
		0.04906767432, 0.9987954562);
	stepMatrix = stepMatrix * Matrix2x2(0.99, 0.0, 0.0, 0.99);	// Scale slightly


	// Strands work on interleaved chunks of pixels.  The strand ID determines
	// the starting point.
	while (true)
	{
		unsigned int imageBase = (unsigned int) kImage;
		veci16 *outputPtr = kFrameBufferAddress + myStrandId;
		for (int y = 0; y < kScreenHeight; y++)
		{
			for (int x = myStrandId * 16; x < kScreenWidth; x += 64)
			{
				vecf16 xv = kXOffsets + __builtin_nyuzi_makevectorf((float) x) 
					- __builtin_nyuzi_makevectorf(kScreenWidth / 2);
				vecf16 yv = __builtin_nyuzi_makevectorf((float) y) 
					- __builtin_nyuzi_makevectorf(kScreenHeight / 2);;
				vecf16 u = xv * __builtin_nyuzi_makevectorf(displayMatrix.a)
					 + yv * __builtin_nyuzi_makevectorf(displayMatrix.b);
				vecf16 v = xv * __builtin_nyuzi_makevectorf(displayMatrix.c) 
					+ yv * __builtin_nyuzi_makevectorf(displayMatrix.d);
				
				veci16 tx = (__builtin_nyuzi_vftoi(u) & __builtin_nyuzi_makevectori(kImageWidth - 1));
				veci16 ty = (__builtin_nyuzi_vftoi(v) & __builtin_nyuzi_makevectori(kImageHeight - 1));
				veci16 pixelPtrs = (ty * __builtin_nyuzi_makevectori(kImageWidth * kBytesPerPixel)) 
					+ (tx * __builtin_nyuzi_makevectori(kBytesPerPixel)) 
					+ __builtin_nyuzi_makevectori(imageBase);
				*outputPtr = __builtin_nyuzi_gather_loadi(pixelPtrs);
				dflush(outputPtr);
				outputPtr += 4;	// Skip over four chunks because there are four threads.
			}
		}

		if (myStrandId == 0)
			displayMatrix = displayMatrix * stepMatrix;

		gFrameBarrier.wait();
	}

	return 0;
}

unsigned int kImage[] = {
	0xffffff,
	0xffffff,
	0xffffff,
	0xffffff,
	0xfffff8,
	0xc8ffeb,
	0x68ffe3,
	0x28ffdf,
	0x7ffdf,
	0x7ffe3,
	0x28ffeb,
	0x68fff8,
	0xc8ffff,
	0xffffff,
	0xffffff,
	0xffffff,
	0xffffff,
	0xffffff,
	0xffffff,
	0xffffeb,
	0x68ffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffeb,
	0x68ffff,
	0xffffff,
	0xffffff,
	0xffffff,
	0xffffff,
	0xffffe7,
	0x48ffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffe7,
	0x48ffff,
	0xffffff,
	0xffffff,
	0xffffeb,
	0x68ffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffeb,
	0x68ffff,
	0xfffff8,
	0xc8ffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xfff8,
	0xc8ffeb,
	0x68ffde,
	0xffde,
	0xffde,
	0x0,
	0x0,
	0xffde,
	0xffde,
	0xffde,
	0x0,
	0x0,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffeb,
	0x68ffe3,
	0x28ffde,
	0xffde,
	0xffde,
	0x0,
	0x0,
	0xffde,
	0xffde,
	0xffde,
	0x0,
	0x0,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffe3,
	0x28ffdf,
	0x7ffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffdf,
	0x7ffdf,
	0x7ffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffdf,
	0x7ffe3,
	0x28ffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffe3,
	0x28ffeb,
	0x68ffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0x0,
	0xffde,
	0xffde,
	0xffde,
	0xffeb,
	0x68fff8,
	0xc8ffde,
	0xffde,
	0x0,
	0x0,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0x0,
	0xffde,
	0xffde,
	0xffde,
	0xfff8,
	0xc8ffff,
	0xffffeb,
	0x68ffde,
	0xffde,
	0x0,
	0x0,
	0x0,
	0xffde,
	0xffde,
	0x0,
	0x0,
	0x0,
	0xffde,
	0xffde,
	0xffeb,
	0x68ffff,
	0xffffff,
	0xffffff,
	0xffffe7,
	0x48ffde,
	0xffde,
	0xffde,
	0x0,
	0x0,
	0x0,
	0x0,
	0xffde,
	0xffde,
	0xffde,
	0xffe7,
	0x48ffff,
	0xffffff,
	0xffffff,
	0xffffff,
	0xffffff,
	0xffffeb,
	0x68ffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffde,
	0xffeb,
	0x68ffff,
	0xffffff,
	0xffffff,
	0xffffff,
	0xffffff,
	0xffffff,
	0xffffff,
	0xfffff8,
	0xc8ffeb,
	0x68ffe3,
	0x28ffdf,
	0x7ffdf,
	0x7ffe3,
	0x28ffeb,
	0x68fff8,
	0xc8ffff,
	0xffffff,
	0xffffff,
	0xffffff
};
