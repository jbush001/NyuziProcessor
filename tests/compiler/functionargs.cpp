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

//
// Test call argument lowering
//

struct MyStruct
{
	int a;
	int b;
};

void __attribute__ ((noinline)) doIt(MyStruct s1, const MyStruct &s2, int a3, short a4, char a5, float a6)
{
	printf("s1a 0x%08x\n", s1.a); // CHECK: s1a 0x12345678
	printf("s1b 0x%08x\n", s1.b);	// CHECK: s1b 0x5ac37431
	printf("s2a 0x%08x\n", s2.a);	// CHECK: s2a 0x83759472
	printf("s2b 0x%08x\n", s2.b);	// CHECK: s2b 0x1634bcfe
	printf("a3 0x%08x\n", a3);		// CHECK: a3 0xdeadbeef
	printf("a4 0x%08x\n", a4);		// CHECK: a4 0x00001234
	printf("a5 %c\n", a5);		// CHECK: a5 q
	printf("a6 0x%08x\n", ((int)a6)); // CHECK: a6 0x000004d2
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
