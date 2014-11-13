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

float a = 123.0;
int b = 79;
unsigned int c = 24;
unsigned int f = 0x81234000;

int main()
{
	float d = b;
	float e = c;
	float g = f;
	
	printf("0x%08x\n", (int) a);			// CHECK: 0x0000007b
	printf("0x%08x\n", (unsigned int) a);	// CHECK: 0x0000007b
	printf("0x%08x\n", (int) d);			// CHECK: 0x0000004f
	printf("0x%08x\n", (int) e);			// CHECK: 0x00000018
	printf("0x%08x\n", (unsigned int) g);	// CHECK: 0x81234000
}
