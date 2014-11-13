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

//
// Simple fibonacci sum
//

int fib(int n)
{
	if (n < 2)
		return n;
	else 
		return fib(n - 1) + fib(n - 2);
}

int main()
{
	for (int i = 0; i < 10; i++)
		printf("0x%08x\n", fib(i));	
		
	// CHECK: 0x00000000
	// CHECK: 0x00000001
	// CHECK: 0x00000001
	// CHECK: 0x00000002
	// CHECK: 0x00000003
	// CHECK: 0x00000005
	// CHECK: 0x00000008
	// CHECK: 0x0000000d
	// CHECK: 0x00000015
	
	return 0;
}
