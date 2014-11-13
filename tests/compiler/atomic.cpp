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

volatile int foo = 0x5a5a5a5a;

int main()
{
	printf("0x%08x\n", __sync_fetch_and_add(&foo, 1));	// CHECK: 0x5a5a5a5a
	printf("0x%08x\n", __sync_add_and_fetch(&foo, 1));	// CHECK: 0x5a5a5a5c
	printf("0x%08x\n", __sync_add_and_fetch(&foo, 1));	// CHECK: 0x5a5a5a5d
	printf("0x%08x\n", __sync_fetch_and_add(&foo, 1));	// CHECK: 0x5a5a5a5d

	// Large constants.  Ensure all operations generate proper code (which must
	// load from constant pool)
	printf("0x%08x\n", __sync_add_and_fetch(&foo, 0x10000000));	// CHECK: 0x6a5a5a5e
	printf("0x%08x\n", __sync_sub_and_fetch(&foo, 0x20000000));	// CHECK: 0x4a5a5a5e
	printf("0x%08x\n", __sync_and_and_fetch(&foo, 0xf0ffffff));	// CHECK: 0x405a5a5e
	printf("0x%08x\n", __sync_or_and_fetch(&foo, 0x0f000000));	// CHECK: 0x4f5a5a5e
	printf("0x%08x\n", __sync_xor_and_fetch(&foo, 0x05000000));	// CHECK: 0x4a5a5a5e

	// Small constants.  These will generate immediate instructions.  Test for all forms.
	printf("0x%08x\n", __sync_sub_and_fetch(&foo, 1));	// CHECK: 0x4a5a5a5d
	printf("0x%08x\n", __sync_and_and_fetch(&foo, 1));	// CHECK: 0x00000001
	printf("0x%08x\n", __sync_or_and_fetch(&foo, 2));	// CHECK: 0x00000003
	printf("0x%08x\n", __sync_xor_and_fetch(&foo, 1));	// CHECK: 0x00000002

	// Compare and swap
	foo = 2;

	// successful
	printf("0x%08x\n", __sync_val_compare_and_swap(&foo, 2, 3));	// CHECK: 0x00000002
	printf("0x%08x\n", foo); // CHECK: 0x00000003

	// not successful
	printf("0x%08x\n", __sync_val_compare_and_swap(&foo, 2, 4));  // CHECK: 0x00000003
	printf("0x%08x\n", foo); // CHECK: 0x00000003

	// not successful
	printf("0x%08x\n", __sync_bool_compare_and_swap(&foo, 2, 10));  // CHECK: 0x00000000
	printf("0x%08x\n", foo); // CHECK: 0x00000003

	// successful
	printf("0x%08x\n", __sync_bool_compare_and_swap(&foo, 3, 10));  // CHECK: 0x00000001
	printf("0x%08x\n", foo); // CHECK: 0x0000000a
	
	return 0;
}
