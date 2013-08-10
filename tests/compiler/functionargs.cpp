// 
// Copyright 2013 Jeff Bush
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
