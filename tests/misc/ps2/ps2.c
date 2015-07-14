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

static volatile unsigned int * const REGISTERS = (volatile unsigned int*) 0xffff0000;

int main()
{
	unsigned int value;
	
	for (unsigned int i = 0; i < 255; i++)
	{
		int timeout = 5000;
		while (REGISTERS[0x38 / 4] == 0 && timeout-- > 0)
			;

		if (timeout == 0)
		{
			printf("FAIL: Timeout waiting for keyboard character\n");
			break;
		}	

		value = REGISTERS[0x3c / 4];
		if (value != i)
		{
			printf("FAIL: mismatch: want %02x got %02x", i, value);
			break;
		}
		
		printf("%02x\n", value);
	}

	printf("PASS\n");

	return 0;
}
