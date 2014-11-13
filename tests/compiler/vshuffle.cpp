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

const veci16_t kSourceVec = { 0xa, 0xb, 0xc, 0xd, 0xe, 0xf, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19 };
const veci16_t kIndexVec = { 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 };

void printVector(veci16_t v)
{
	for (int lane = 0; lane < 16; lane++)
		printf("0x%08x ", v[lane]);
}

int main()
{
	printVector(__builtin_nyuzi_vector_mixi(0xaaaa, __builtin_nyuzi_shufflei(kSourceVec, kIndexVec), 
		kSourceVec));

	// CHECK: 0x00000019
	// CHECK: 0x0000000b
	// CHECK: 0x00000017
	// CHECK: 0x0000000d
	// CHECK: 0x00000015
	// CHECK: 0x0000000f
	// CHECK: 0x00000013
	// CHECK: 0x00000011
	// CHECK: 0x00000011
	// CHECK: 0x00000013
	// CHECK: 0x0000000f
	// CHECK: 0x00000015
	// CHECK: 0x0000000d
	// CHECK: 0x00000017
	// CHECK: 0x0000000b
	// CHECK: 0x00000019
}
