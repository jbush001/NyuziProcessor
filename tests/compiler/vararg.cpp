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

void varArgFunc(int numParams, ...)
{
	__builtin_va_list ap;
	__builtin_va_start(ap, numParams);

	for (int i = 0; i < numParams; i++)
		printf("0x%08x", __builtin_va_arg(ap, int));
	
	__builtin_va_end(ap);
}

int main()
{
	varArgFunc(4, 0xaaaaaaaa, 0xbbbbbbbb, 0xcccccccc, 0xdddddddd);

	// CHECK: 0xaaaaaaaa
	// CHECK: 0xbbbbbbbb
	// CHECK: 0xcccccccc
	// CHECK: 0xdddddddd
}
 
