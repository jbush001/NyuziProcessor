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
#include "util.h"

int parseHexVector(const char *str, uint32_t vectorValues[16], int endianSwap)
{
	const char *c = str;
	int lane;
	int digit;
	uint32_t laneValue;
	
	for (lane = 15; lane >= 0 && *c; lane--)
	{
		laneValue = 0;
		for (digit = 0; digit < 8; digit++)
		{
			if (*c >= '0' && *c <= '9')
				laneValue = (laneValue << 4) | (*c - '0');
			else if (*c >= 'a' && *c <= 'f')
				laneValue = (laneValue << 4) | (*c - 'a' + 10);
			else if (*c >= 'A' && *c <= 'F')
				laneValue = (laneValue << 4) | (*c - 'A' + 10);
			else
			{
				printf("bad character %c in hex vector\n", *c);
				return 0;
			}

			if (*c == '\0')
			{
				printf("Error parsing hex vector\n");
				break;
			}
			else
				c++;
		}
		
		vectorValues[lane] = endianSwap ? endianSwap32(laneValue) : laneValue;
	}

	return 1;
}
