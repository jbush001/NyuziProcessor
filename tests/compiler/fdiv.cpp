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

void __attribute__ ((noinline)) printVal(float f)
{
	int foo;
	*((float*) &foo) = f;
	printf("0x%08x\n", foo);
}

float a = 123.0;
float b = 11.1;
float c = 1.0;

int main()
{
	printVal(1.0f / a);		// CHECK: 0x3c053408
	printVal(1235.0f / b);	// CHECK: 0x42de85c5
	printVal(c / 0.4f);	// CHECK: 0x40200000
}
