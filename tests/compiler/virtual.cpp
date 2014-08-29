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
#include "cxx_runtime.h"

class Base
{
public:
	virtual void doOutput(int value) = 0;
};

class Derived1 : public Base
{
public:
	virtual void doOutput(int value);
};

class Derived2 : public Base
{
public:
	virtual void doOutput(int value);
};

Output output;

int main()
{
	Derived1 d1;
	Derived2 d2;

	Base *b1 = &d1;
	Base *b2 = &d2;
	
	b1->doOutput(0x12345678);	// CHECK: derived1 0x12345678
	b2->doOutput(0xabdef000);	// CHECK: derived2 0xabdef000

	return 0;
}

void Derived1::doOutput(int value)
{
	output << "derived1 " << value << "\n";
}

void Derived2::doOutput(int value)
{
	output << "derived2 " << value << "\n";
}
