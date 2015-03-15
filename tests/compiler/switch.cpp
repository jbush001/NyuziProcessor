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

int __attribute__ ((noinline)) lookupSwitch(int x, int y)
{
	switch (x)
	{
		case 0:	// Falls through
		case 1:
			return y + 1;

		case 2:
			return y | 9;

		case 3:
			return y ^ 2;
		
		case 4:
		case 5:	
			return y * y;	
			
		default:
			return y;
	}
}

int main()
{
	int j = 0;
	
	for (int i = 0; i < 10; i++)
		j = lookupSwitch(i, j);

	printf("0x%08x\n", (unsigned) j);	// CHECK: 0x000019a1
}
