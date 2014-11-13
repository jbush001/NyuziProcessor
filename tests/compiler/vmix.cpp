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
#include <stdint.h>

void printVector(veci16_t v)
{
	for (int lane = 0; lane < 16; lane++)
		printf("0x%08x ", v[lane]);
}

int main()
{
	veci16_t value = __builtin_nyuzi_makevectori(0);
	for (int mask = 0xffff; mask; mask >>= 1)
		value = __builtin_nyuzi_vector_mixi(mask, value + __builtin_nyuzi_makevectori(1), value);

	printVector(value);

	// CHECK: 0x00000001
	// CHECK: 0x00000002
	// CHECK: 0x00000003
	// CHECK: 0x00000004
	// CHECK: 0x00000005
	// CHECK: 0x00000006
	// CHECK: 0x00000007
	// CHECK: 0x00000008
	// CHECK: 0x00000009
	// CHECK: 0x0000000a
	// CHECK: 0x0000000b
	// CHECK: 0x0000000c
	// CHECK: 0x0000000d
	// CHECK: 0x0000000e
	// CHECK: 0x0000000f
	// CHECK: 0x00000010
}
