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
// Use duff's device to print a series of characters.  Verifies the switch statement
// is compiled properly.
//
void __attribute__ ((noinline)) printBs(int count)
{
	int n = (count + 7) / 8;
	switch (count & 7)
	{
        case 0: do {    putchar('B');
        case 7:         putchar('B'); 
        case 6:         putchar('B');
        case 5:         putchar('B');
        case 4:         putchar('B');
        case 3:         putchar('B');
        case 2:         putchar('B');
        case 1:         putchar('B');
                } while (--n > 0);
	}
}

int main()
{
	for (int i = 15; i >= 1; i--)
	{
		putchar('A');
		printBs(i);
		putchar('C');
		putchar('\n');
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
