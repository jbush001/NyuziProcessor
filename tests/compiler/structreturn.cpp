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
// Struct as return value
//

struct MyStruct
{
	int a;
	int b;
};

MyStruct __attribute__ ((noinline)) doIt(int a, int b)
{
	MyStruct s1;
	s1.a = a;
	s1.b = b;
	return s1;
}

int main()
{
	MyStruct s1 = doIt(0x37523482, 0x10458422);

	printf("s1a 0x%08x\n", s1.a);	// CHECK: s1a 0x37523482
	printf("s1b 0x%08x\n", s1.b);	// CHECK: s1b 0x10458422

	return 0;
}
