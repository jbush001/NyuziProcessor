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
#include <stdarg.h>

void __attribute__ ((noinline)) varArgFunc(int foo, ...)
{
	__builtin_va_list ap;
	__builtin_va_start(ap, foo);
	printf("foo = 0x%08x\n", foo);
	printf("0. 0x%08x\n", __builtin_va_arg(ap, int));
	printf("1. 0x%08x\n", __builtin_va_arg(ap, unsigned int));
	printf("2. 0x%08x\n", __builtin_va_arg(ap, short));
	printf("3. 0x%08x\n", __builtin_va_arg(ap, unsigned short));
	printf("4. 0x%08x\n", __builtin_va_arg(ap, char));
	printf("5. 0x%08x\n", __builtin_va_arg(ap, unsigned char));
	printf("6. %s\n", __builtin_va_arg(ap, const char*));
	__builtin_va_end(ap);
}

int main()
{
	varArgFunc(0x3659487d, 0x4f5b256, 0xacb0f292, 0x1f4d9c8d, 0xd5fc06d3, 
		0xb201c748, 0xb3f71cc2, "test string");

	// CHECK: foo = 0x3659487d
	// CHECK: 0. 0x04f5b256
	// CHECK: 1. 0xacb0f292
	// CHECK: 2. 0xffff9c8d
	// CHECK: 3. 0x000006d3
	// CHECK: 4. 0x00000048
	// CHECK: 5. 0x000000c2
	// CHECK: 6. test string
}
 
