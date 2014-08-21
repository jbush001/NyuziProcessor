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

#define outch(ch) *((volatile unsigned int*) 0xFFFF0000) = ch;

//
// Use duff's device to print a series of characters.  Verifies the switch statement
// is compiled properly.
//
void printBs(int count)
{
	int n = (count + 7) / 8;
	switch (count & 7)
	{
        case 0: do {    outch('B');
        case 7:         outch('B'); 
        case 6:         outch('B');
        case 5:         outch('B');
        case 4:         outch('B');
        case 3:         outch('B');
        case 2:         outch('B');
        case 1:         outch('B');
                } while (--n > 0);
	}
}

int main()
{
	for (int i = 15; i >= 1; i--)
	{
		outch('A')
		printBs(i);
		outch('C');
		outch('\n');
	}
	
	// CHECK: ABBBBBBBBBBBBBBBC
	// CHECK: ABBBBBBBBBBBBBBC
	// CHECK: ABBBBBBBBBBBBBC
	// CHECK: ABBBBBBBBBBBBC
	// CHECK: ABBBBBBBBBBBC
	// CHECK: ABBBBBBBBBBC
	// CHECK: ABBBBBBBBBC
	// CHECK: ABBBBBBBBC
	// CHECK: ABBBBBBBC
	// CHECK: ABBBBBBC
	// CHECK: ABBBBBC
	// CHECK: ABBBBC
	// CHECK: ABBBC
	// CHECK: ABBC
	// CHECK: ABC
}
