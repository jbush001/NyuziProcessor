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

int main(int argc, const char *argv[])
{
	uint64_t a = 1;
	int64_t b = -1;

	for (int i = 0; i < 10; i++)
	{
		printf("a %08x%08x\n", (unsigned int)((a >> 32) & 0xffffffff), (unsigned int) (a & 0xffffffff));
		printf("b %08x%08x\n", (unsigned int)((b >> 32) & 0xffffffff), (unsigned int) (b & 0xffffffff));
		a = a * 13;
		b = b * 17;
	}
}

// CHECK: a 0000000000000001
// CHECK: b ffffffffffffffff
// CHECK: a 000000000000000d
// CHECK: b ffffffffffffffef
// CHECK: a 00000000000000a9
// CHECK: b fffffffffffffedf
// CHECK: a 0000000000000895
// CHECK: b ffffffffffffeccf
// CHECK: a 0000000000006f91
// CHECK: b fffffffffffeb9bf
// CHECK: a 000000000005aa5d
// CHECK: b ffffffffffea55af
// CHECK: a 000000000049a6b9
// CHECK: b fffffffffe8fb09f
// CHECK: a 0000000003bd7765
// CHECK: b ffffffffe78aba8f
// CHECK: a 00000000309f1021
// CHECK: b fffffffe6036637f
// CHECK: a 000000027813d1ad
// CHECK: b ffffffe4639c9b6f
	
	