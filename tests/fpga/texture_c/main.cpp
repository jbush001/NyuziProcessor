// 
// Copyright 2011-2013 Jeff Bush
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

typedef int veci16 __attribute__((ext_vector_type(16)));
typedef float vecf16 __attribute__((ext_vector_type(16)));

veci16* const kFrameBufferAddress = (veci16*) 0x10000000;
const vecf16 kXOffsets = { 0.0f, 1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 
	8.0f, 9.0f, 10.0f, 11.0f, 12.0f, 13.0f, 14.0f, 15.0f };
extern unsigned int kImage[];

// A B
// C D

class Matrix
{
public:
	Matrix()
		: 	a(1.0), b(0.0), c(0.0), d(1.0)
	{}
	
	Matrix(float _a, float _b, float _c, float _d)
		:	a(_a), b(_b), c(_c), d(_d)
	{}

	Matrix operator*(const Matrix &rhs) const
	{
		return Matrix(
			(a * rhs.a + b * rhs.c), (a * rhs.b + b * rhs.d),
			(c * rhs.a + d * rhs.c), (c * rhs.b + d * rhs.d));
	}

	float a;
	float b;
	float c;
	float d;
};

int main()
{
	Matrix displayMatrix;

	// 1/64 step rotation
	Matrix stepMatrix(
		0.9987954562, -0.04906767432,
		0.04906767432, 0.9987954562);

	// Strands work on interleaved chunks of pixels.  The strand ID determines
	// the starting point.
	int myStrandId = __builtin_vp_get_current_strand();
	while (true)
	{
		unsigned int imageBase = (unsigned int) kImage;
		veci16 *outputPtr = kFrameBufferAddress + myStrandId;
		for (int y = 0; y < 480; y++)
		{
			for (int x = myStrandId * 16; x < 640; x += 64)
			{
				vecf16 xv = kXOffsets + __builtin_vp_makevectorf((float) x);
				vecf16 yv = __builtin_vp_makevectorf((float) y);
				vecf16 u = xv * __builtin_vp_makevectorf(displayMatrix.a)
					 + yv * __builtin_vp_makevectorf(displayMatrix.b);
				vecf16 v = xv * __builtin_vp_makevectorf(displayMatrix.c) 
					+ yv * __builtin_vp_makevectorf(displayMatrix.d);
				
				veci16 tx = (__builtin_vp_vftoi(u) & __builtin_vp_makevectori(15)) 
					* __builtin_vp_makevectori(4);
				veci16 ty = (__builtin_vp_vftoi(v) & __builtin_vp_makevectori(15)) 
					* __builtin_vp_makevectori(4);
				veci16 pixelPtrs = ty * __builtin_vp_makevectori(16) + tx 
					+ __builtin_vp_makevectori(imageBase);
				*outputPtr = __builtin_vp_gather_loadi(pixelPtrs);
				outputPtr += 4;	// Skip over four chunks because there are four threads.
			}
		}
		
		displayMatrix = displayMatrix * stepMatrix;
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
