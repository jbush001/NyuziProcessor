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

Output output;

float a = 123.0;
int b = 79;
unsigned int c = 24;
unsigned int f = 0x81234000;

int main()
{
	float d = b;
	float e = c;
	float g = f;
	
	output << (int) a;			// CHECK: 0x0000007b
	output << (unsigned int) a;	// CHECK: 0x0000007b
	output << (int) d;			// CHECK: 0x0000004f
	output << (int) e;			// CHECK: 0x00000018
	output << (unsigned int) g;	// CHECK: 0x81234000
}
