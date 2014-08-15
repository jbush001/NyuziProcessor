// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 

#include <stdio.h>
#include <string.h>
#include "core.h"

static unsigned int swapEndian(unsigned int value)
{
	return ((value & 0xff) << 24)
		| ((value & 0xff00) << 8)
		| ((value & 0xff0000) >> 8)
		| ((value & 0xff000000) >> 24);
}

static int parseHexVector(const char *str, unsigned int vectorValues[16], int endianSwap)
{
	const char *c = str;
	int lane;
	int digit;
	unsigned int laneValue;
	
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
		
		vectorValues[lane] = endianSwap ? swapEndian(laneValue) : laneValue;
	}

	return 1;
}

// Returns 1 if successful, 0 if there was an error
int runCosim(Core *core, int verbose)
{
	char line[1024];
	int strandId;
	unsigned int address;
	unsigned int pc;
	unsigned long long int writeMask;
	unsigned int vectorValues[16];
	char valueStr[256];
	int reg;
	unsigned int scalarValue;
	int totalEvents = 0;
	int halted = 0;
	int len;

	if (verbose)
		enableTracing(core);

	while (fgets(line, sizeof(line), stdin))
	{
		len = strlen(line);
		if (len > 0)
			line[len - 1] = '\0';	// Strip off newline
		
		if (verbose)
			printf("%s", line);

		if (sscanf(line, "store %x %x %x %llx %s", &pc, &strandId, &address, &writeMask, valueStr) == 5)
		{
			// Memory Store
			totalEvents++;
			if (!parseHexVector(valueStr, vectorValues, 1)
				|| !cosimMemoryStore(core, strandId, pc, address, writeMask, vectorValues))
			{
				printf("test failed\n");
				return 0;
			}
		} 
		else if (sscanf(line, "vwriteback %x %x %x %llx %s", &pc, &strandId, &reg, &writeMask, valueStr) == 5)
		{
			// Vector writeback
			totalEvents++;
			if (!parseHexVector(valueStr, vectorValues, 0)
				|| !cosimVectorWriteback(core, strandId, pc, reg, writeMask, vectorValues))
			{
				printf("test failed\n");
				return 0;
			}
		}
		else if (sscanf(line, "swriteback %x %x %x %x", &pc, &strandId, &reg, &scalarValue) == 4)
		{
			// Scalar Writeback
			totalEvents++;
			if (!cosimScalarWriteback(core, strandId, pc, reg, scalarValue))
			{
				printf("test failed\n");
				return 0;
			}
		}
		else if (strcmp(line, "***HALTED***\n") == 0)
		{
			// Note: we don't check that the reference model is actually halted
			halted = 1;
			break;
		}
		else if (!verbose)
			printf("%s\n", line);	// Echo unrecognized lines to stdout (verbose already does this for all lines)
	}

	if (halted)
		printf("Processed %d events\n", totalEvents);
	else
	{
		printf("program did not finish normally\n");
		printf("%s\n", line);	// Print error (if any)
		return 0;
	}
	
	// XXX does not check that programs terminated at the same point.
	// if the verilog simulator terminated early, this would pass.

	return 1;
}
