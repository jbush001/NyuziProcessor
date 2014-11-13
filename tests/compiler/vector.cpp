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

const veci16 kInc = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };

int main()
{
	veci16 a = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
	for (int i = 0; i < 10; i++)
		a += kInc;

	for (int i = 0; i < 16; i++)
		printf("0x%08x\n", a[i]);
	
	// CHECK: 0000000a
	// CHECK: 00000014
	// CHECK: 0000001e
	// CHECK: 00000028
	// CHECK: 00000032
	// CHECK: 0000003c
	// CHECK: 00000046
	// CHECK: 00000050
	// CHECK: 0000005a
	// CHECK: 00000064
	// CHECK: 0000006e
	// CHECK: 00000078
	// CHECK: 00000082
	// CHECK: 0000008c
	// CHECK: 00000096
	// CHECK: 000000a0

	return 0;
}
