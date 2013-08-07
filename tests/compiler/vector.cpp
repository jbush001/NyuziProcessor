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


typedef int veci16 __attribute__((__vector_size__(16 * sizeof(int))));

void printChar(char c)
{
	*((volatile unsigned int*) 0xFFFF0004) = c;
}

void printHex(unsigned int value)
{
	for (int i = 0; i < 8; i++)
	{
		int digitVal = (value >> 28);
		value <<= 4;
		if (digitVal >= 10)
			printChar(digitVal - 10 + 'a');
		else
			printChar(digitVal + '0');
	}
}

void printVector(veci16 value)
{
	for (int i = 0; i < 16; i++)
	{
		printHex(value[i]);
		printChar(' ');
	}
	
	printChar('\n');
}

const veci16 kInc = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };

int main()
{
	veci16 a = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
	for (int i = 0; i < 10; i++)
		a += kInc;

	printVector(a);
	
	// CHECK: 000000a0
	// CHECK: 00000096
	// CHECK: 0000008c
	// CHECK: 00000082
	// CHECK: 00000078
	// CHECK: 0000006e
	// CHECK: 00000064
	// CHECK: 0000005a
	// CHECK: 00000050
	// CHECK: 00000046
	// CHECK: 0000003c
	// CHECK: 00000032
	// CHECK: 00000028
	// CHECK: 0000001e
	// CHECK: 00000014
	// CHECK: 0000000a

	return 0;
}
