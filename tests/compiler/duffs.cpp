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

#include <libc.h>

#define outch(ch) *((volatile unsigned int*) 0xFFFF0000) = ch;

//
// Use duff's device to print a series of characters.  Verifies the switch statement
// is compiled properly.
//
void printBs(int count)
{
	int n = (count + 7) / 8;
	switch (count & 7)
	{
        case 0: do {    outch('B');
        case 7:         outch('B'); 
        case 6:         outch('B');
        case 5:         outch('B');
        case 4:         outch('B');
        case 3:         outch('B');
        case 2:         outch('B');
        case 1:         outch('B');
                } while (--n > 0);
	}
}

int main()
{
	for (int i = 15; i >= 1; i--)
	{
		outch('A')
		printBs(i);
		outch('C');
		outch('\n');
	}
	
	// CHECK: ABBBBBBBBBBBBBBBC
	// CHECK: ABBBBBBBBBBBBBBC
	// CHECK: ABBBBBBBBBBBBBC
	// CHECK: ABBBBBBBBBBBBC
	// CHECK: ABBBBBBBBBBBC
	// CHECK: ABBBBBBBBBBC
	// CHECK: ABBBBBBBBBC
	// CHECK: ABBBBBBBBC
	// CHECK: ABBBBBBBC
	// CHECK: ABBBBBBC
	// CHECK: ABBBBBC
	// CHECK: ABBBBC
	// CHECK: ABBBC
	// CHECK: ABBC
	// CHECK: ABC
}
