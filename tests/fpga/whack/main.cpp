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
// This program displays a moving pattern on the VGA display.
//

typedef int veci16 __attribute__((__vector_size__(16 * sizeof(int))));

veci16* const kFrameBufferAddress = (veci16*) 0x10000000;
const veci16 kXOffsets = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };

inline void dflush(void *address)
{
	asm("dflush %0" : : "s" (address));
}

int main()
{
	// Strands work on interleaved chunks of pixels.  The strand ID determines
	// the starting point.
	int myStrandId = __builtin_nyuzi_read_control_reg(0);
	for (int frameNum = 0; ; frameNum++)
	{
		veci16 *ptr = kFrameBufferAddress + myStrandId;
		for (int y = 0; y < 480; y++)
		{
			for (int x = myStrandId * 16; x < 640; x += 64)
			{
				veci16 xv = kXOffsets + __builtin_nyuzi_makevectori(x);
				veci16 yv = __builtin_nyuzi_makevectori(y);
				veci16 fv = __builtin_nyuzi_makevectori(frameNum);

				*ptr = (xv+fv)+xv+(xv^(yv+fv))+fv;
				dflush(ptr);
				ptr += 4;	// Skip over four chunks because there are four threads.
			}
		}
	}

	return 0;
}
