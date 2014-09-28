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
