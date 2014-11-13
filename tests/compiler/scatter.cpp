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

#include <stdio.h>

typedef int veci16 __attribute__((__vector_size__(16 * sizeof(int))));

volatile unsigned int foo[16];

int main()
{
	veci16 ptrs;
	veci16 values = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };

	for (int i = 0; i < 16; i++)
		ptrs[i] = (unsigned int) &foo[15 - i];

	__builtin_nyuzi_scatter_storei_masked(ptrs, values, 0xffff);
	
	for (int i = 0; i < 16; i++)
		printf("0x%08x\n", foo[i]);

	// CHECK: 0x0000000f
	// CHECK: 0x0000000e
	// CHECK: 0x0000000d
	// CHECK: 0x0000000c
	// CHECK: 0x0000000b
	// CHECK: 0x0000000a
	// CHECK: 0x00000009
	// CHECK: 0x00000008
	// CHECK: 0x00000007
	// CHECK: 0x00000006
	// CHECK: 0x00000005
	// CHECK: 0x00000004
	// CHECK: 0x00000003
	// CHECK: 0x00000002
	// CHECK: 0x00000001
	// CHECK: 0x00000000
}
