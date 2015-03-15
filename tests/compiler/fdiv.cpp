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

void __attribute__ ((noinline)) printVal(float f)
{
	int foo;
	*((float*) &foo) = f;
	printf("0x%08x\n", foo);
}

float a = 123.0;
float b = 11.1;
float c = 1.0;

int main()
{
	printVal(1.0f / a);		// CHECK: 0x3c053408
	printVal(1235.0f / b);	// CHECK: 0x42de85c5
	printVal(c / 0.4f);	// CHECK: 0x40200000
}
