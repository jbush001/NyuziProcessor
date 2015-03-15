// 
// Copyright 2011-2015 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 


#include <stdio.h>

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
	printf("derived1 0x%08x\n", value);
}

void Derived2::doOutput(int value)
{
	printf("derived2 0x%08x\n", value);
}
