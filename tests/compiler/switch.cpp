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

int __attribute__ ((noinline)) lookupSwitch(int x, int y)
{
	switch (x)
	{
		case 0:	// Falls through
		case 1:
			return y + 1;

		case 2:
			return y | 9;

		case 3:
			return y ^ 2;
		
		case 4:
		case 5:	
			return y * y;	
			
		default:
			return y;
	}
}

int main()
{
	int j = 0;
	
	for (int i = 0; i < 10; i++)
		j = lookupSwitch(i, j);

	printf("0x%08x\n", (unsigned) j);	// CHECK: 0x000019a1
}
