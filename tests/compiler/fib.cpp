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

//
// Simple fibonacci sum
//

void printChar(char c)
{
	*((volatile unsigned int*) 0xFFFF0004) = c;
}

int fib(int n)
{
	if (n < 2)
		return n;
	else 
		return fib(n - 1) + fib(n - 2);
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

	printChar('\n');
}

int main()
{
	printHex(fib(8));	// CHECK: 00000015
	return 0;
}
