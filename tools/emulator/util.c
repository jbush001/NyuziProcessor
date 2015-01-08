// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
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
