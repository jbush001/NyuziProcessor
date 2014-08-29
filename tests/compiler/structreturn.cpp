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
// Struct as return value
//

struct MyStruct
{
	int a;
	int b;
};

Output output;

MyStruct doIt(int a, int b)
{
	MyStruct s1;
	s1.a = a;
	s1.b = b;
	return s1;
}

int main()
{
	MyStruct s1 = doIt(0x37523482, 0x10458422);

	output << "s1a " << s1.a << "\n";	// CHECK: s1a 0x37523482
	output << "s1b " << s1.b << "\n";	// CHECK: s1b 0x10458422

	return 0;
}
