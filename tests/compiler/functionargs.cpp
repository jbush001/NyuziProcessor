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


#include "output.h"

//
// Test call argument lowering
//

struct MyStruct
{
	int a;
	int b;
};

Output output;

void doIt(MyStruct s1, const MyStruct &s2, int a3, short a4, char a5, float a6)
{
	output << "s1a " << s1.a << "\n";	// CHECK: s1a 0x12345678
	output << "s1b " << s1.b << "\n";	// CHECK: s1b 0x5ac37431
	output << "s2a " << s2.a << "\n";	// CHECK: s2a 0x83759472
	output << "s2b " << s2.b << "\n";	// CHECK: s2b 0x1634bcfe
	output << "a3 " << a3 << "\n";		// CHECK: a3 0xdeadbeef
	output << "a4 " << a4 << "\n";		// CHECK: a4 0x00001234
	output << "a5 " << a5 << "\n";		// CHECK: a5 q
	output << "a6 " << ((int)a6) << "\n"; // CHECK: a6 0x000004d2
}

int main()
{
	MyStruct s1;
	MyStruct s2;
	
	s1.a = 0x12345678;
	s1.b = 0x5ac37431;
	s2.a = 0x83759472;
	s2.b = 0x1634bcfe;
	
	doIt(s1, s2, 0xdeadbeef, 0x1234, 'q', 1234.0);

	return 0;
}
