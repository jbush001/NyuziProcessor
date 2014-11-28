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

int __attribute__((noinline)) FixedMul(int a, int b)
{
	return ((long long) a * (long long) b) >> 16;
}

int main(int argc, const char *argv[])
{
	uint64_t a = 1;
	int64_t b = -1;
	int64_t c = -1;

	for (int i = 0; i < 3; i++)
	{
		printf("a %08x%08x\n", (unsigned int)((a >> 32) & 0xffffffff), (unsigned int) (a & 0xffffffff));
		printf("b %08x%08x\n", (unsigned int)((b >> 32) & 0xffffffff), (unsigned int) (b & 0xffffffff));
		a = a * 13;
		b = b * 17;
		c = a * b;
		printf("c %08x%08x\n", (unsigned int)((c >> 32) & 0xffffffff), (unsigned int) (c & 0xffffffff));
	}

	printf("FixedMul %08x\n", FixedMul(0x009fe0c6, 0xfc4a8634));
}

// CHECK: a 0000000000000001
// CHECK: b ffffffffffffffff
// CHECK: c ffffffffffffff23
// CHECK: a 000000000000000d
// CHECK: b ffffffffffffffef
// CHECK: c ffffffffffff4137
// CHECK: a 00000000000000a9
// CHECK: b fffffffffffffedf
// CHECK: c ffffffffff5b4c7b
// CHECK: FixedMul af07b15d


	
	