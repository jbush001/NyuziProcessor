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
#include <string.h>
#include "core.h"
#include "util.h"

static void printCosimExpected(void);
static int cosimStep(Core *core, int threadId);
static int compareMasked(uint32_t mask, const uint32_t values1[16],
	const uint32_t values2[16]);

static enum 
{
	kEventNone,
	kEventMemStore,
	kEventVectorWriteback,
	kEventScalarWriteback
} cosimCheckEvent;
static int cosimCheckRegister;
static uint32_t cosimCheckAddress;
static uint64_t cosimCheckMask;
static uint32_t cosimCheckValues[16];
static int cosimError;
static uint32_t cosimCheckPc;
static int cosimEventTriggered;
static int cosimCheckThread;

// Read events from standard in.  Step each emulator thread in lockstep
// and ensure the side effects match.
// Returns 1 if successful, 0 if there was an error
int runCosim(Core *core, int verbose)
{
	char line[1024];
	int threadId;
	uint32_t address;
	uint32_t pc;
	uint64_t writeMask;
	uint32_t vectorValues[16];
	char valueStr[256];
	int reg;
	uint32_t scalarValue;
	int verilogModelHalted = 0;
	int len;

	enableCosim(core, 1);
	if (verbose)
		enableTracing(core);

	while (fgets(line, sizeof(line), stdin))
	{
		if (verbose)
			printf("%s", line);

		len = strlen(line);
		if (len > 0)
			line[len - 1] = '\0';	// Strip off newline

		if (sscanf(line, "store %x %x %x %llx %s", &pc, &threadId, &address, &writeMask, valueStr) == 5)
		{
			// Memory Store
			if (!parseHexVector(valueStr, vectorValues, 1))
				return 0;

			cosimCheckEvent = kEventMemStore;
			cosimCheckPc = pc;
			cosimCheckThread = threadId;
			cosimCheckAddress = address;
			cosimCheckMask = writeMask;
			memcpy(cosimCheckValues, vectorValues, sizeof(uint32_t) * 16);
	
			if (!cosimStep(core, threadId))
				return 0;
		} 
		else if (sscanf(line, "vwriteback %x %x %x %llx %s", &pc, &threadId, &reg, &writeMask, valueStr) == 5)
		{
			// Vector writeback
			if (!parseHexVector(valueStr, vectorValues, 0))
			{
				printf("test failed\n");
				return 0;
			}

			cosimCheckEvent = kEventVectorWriteback;
			cosimCheckPc = pc;
			cosimCheckThread = threadId;
			cosimCheckRegister = reg;
			cosimCheckMask = writeMask;
			memcpy(cosimCheckValues, vectorValues, sizeof(uint32_t) * 16);
	
			if (!cosimStep(core, threadId))
				return 0;
		}
		else if (sscanf(line, "swriteback %x %x %x %x", &pc, &threadId, &reg, &scalarValue) == 4)
		{
			// Scalar Writeback
			cosimCheckEvent = kEventScalarWriteback;
			cosimCheckPc = pc;
			cosimCheckThread = threadId;
			cosimCheckRegister = reg;
			cosimCheckValues[0] = scalarValue;

			if (!cosimStep(core, threadId))
				return 0;
		}
		else if (strcmp(line, "***HALTED***") == 0)
		{
			// Note: we don't check that the reference model is actually verilogModelHalted
			verilogModelHalted = 1;
			break;
		}
		else if (sscanf(line, "interrupt %d %x", &threadId, &pc) == 2)
			cosimInterrupt(core, threadId, pc);
		else if (!verbose)
			printf("%s\n", line);	// Echo unrecognized lines to stdout (verbose already does this for all lines)
	}

	if (!verilogModelHalted)
	{
		printf("program did not finish normally\n");
		printf("%s\n", line);	// Print error (if any)
		return 0;
	}

	// Ensure emulator is also halted. If it executes any more instructions
	// cosimError will be flagged.
	cosimEventTriggered = 0;
	cosimCheckEvent = kEventNone;
	while (!coreHalted(core))
	{
		executeInstructions(core, -1, 1);
		if (cosimError)
			return 0;
	}

	return 1;
}

void cosimSetScalarReg(Core *core, uint32_t pc, int reg, uint32_t value)
{
	cosimEventTriggered = 1;
	if (cosimCheckEvent != kEventScalarWriteback
		|| cosimCheckPc != pc
		|| cosimCheckRegister != reg
		|| cosimCheckValues[0] != value)
	{
		cosimError = 1;
		printRegisters(core, cosimCheckThread);
		printf("COSIM MISMATCH, thread %d\n", cosimCheckThread);
		printf("Reference: %08x s%d <= %08x\n", pc, reg, value);
		printf("Hardware:  ");
		printCosimExpected();
		return;
	}	
}

void cosimSetVectorReg(Core *core, uint32_t pc, int reg, int mask, const uint32_t values[16])
{
	int lane;
	
	cosimEventTriggered = 1;
	if (cosimCheckEvent != kEventVectorWriteback
		|| cosimCheckPc != pc
		|| cosimCheckRegister != reg
		|| !compareMasked(mask, cosimCheckValues, values)
		|| cosimCheckMask != (mask & 0xffff))
	{
		cosimError = 1;
		printRegisters(core, cosimCheckThread);
		printf("COSIM MISMATCH, thread %d\n", cosimCheckThread);
		printf("Reference: %08x v%d{%04x} <= ", pc, reg, mask & 0xffff);
		for (lane = 15; lane >= 0; lane--)
			printf("%08x ", values[lane]);

		printf("\n");
		printf("Hardware:  ");
		printCosimExpected();
		return;
	}
}

void cosimWriteBlock(Core *core, uint32_t pc, uint32_t address, int mask, const uint32_t values[16])
{
	uint64_t byteMask;
	int lane;
	
	byteMask = 0;
	for (lane = 0; lane < 16; lane++)
	{
		if (mask & (1 << lane))
			byteMask |= 0xfLL << (lane * 4);
	}

	cosimEventTriggered = 1;
	if (cosimCheckEvent != kEventMemStore
		|| cosimCheckPc != pc
		|| cosimCheckAddress != (address & ~63)
		|| cosimCheckMask != byteMask 
		|| !compareMasked(mask, cosimCheckValues, values))
	{
		cosimError = 1;
		printRegisters(core, cosimCheckThread);
		printf("COSIM MISMATCH, thread %d\n", cosimCheckThread);
		printf("Reference: %08x memory[%x]{%016llx} <= ", pc, address, byteMask);
		for (lane = 15; lane >= 0; lane--)
			printf("%08x ", values[lane]);

		printf("\nHardware:  ");
		printCosimExpected();
		return;
	}
}

void cosimWriteMemory(Core *core, uint32_t pc, uint32_t address, size_t size, uint32_t value)
{
	uint32_t hardwareValue;
	uint64_t referenceMask;
	
	hardwareValue = cosimCheckValues[(address % 63) / 4];
	if (size < 4)
	{
		uint32_t mask = (1 << (size * 8)) - 1;
		hardwareValue &= mask;
		value &= mask;
	}
	
	referenceMask = ((1ull << size) - 1ull) << (63 - (address & 63) - (size - 1));
	cosimEventTriggered = 1;
	if (cosimCheckEvent != kEventMemStore
		|| cosimCheckPc != pc
		|| cosimCheckAddress != (address & ~63)
		|| cosimCheckMask != referenceMask
		|| hardwareValue != value)
	{
		cosimError = 1;
		printRegisters(core, cosimCheckThread);
		printf("COSIM MISMATCH, thread %d\n", cosimCheckThread);
		printf("Reference: %08x memory[%x]{%016llx} <= %08x\n", pc, address & ~63, 
			referenceMask, value);
		printf("Hardware:  ");
		printCosimExpected();
		return;
	}
}

static void printCosimExpected(void)
{
	int lane;

	printf("%08x ", cosimCheckPc);
	
	switch (cosimCheckEvent)
	{
		case kEventNone:
			printf(" HALTED\n");
			break;
		
		case kEventMemStore:
			printf("memory[%x]{%016llx} <= ", cosimCheckAddress, cosimCheckMask);
			for (lane = 15; lane >= 0; lane--)
				printf("%08x ", cosimCheckValues[lane]);
				
			printf("\n");
			break;

		case kEventVectorWriteback:
			printf("v%d{%04x} <= ", cosimCheckRegister, (uint32_t) 
				cosimCheckMask & 0xffff);
			for (lane = 15; lane >= 0; lane--)
				printf("%08x ", cosimCheckValues[lane]);

			printf("\n");
			break;
			
		case kEventScalarWriteback:
			printf("s%d <= %08x\n", cosimCheckRegister, cosimCheckValues[0]);
			break;
	}
}

// Returns 1 if the event matched, 0 if it did not.
static int cosimStep(Core *core, int threadId)
{
	int count = 0;

	cosimError = 0;
	cosimEventTriggered = 0;
	for (count = 0; count < 500 && !cosimEventTriggered; count++)
		singleStep(core, threadId);

	if (!cosimEventTriggered)
	{
		printf("Simulator program in infinite loop? No event occurred.  Was expecting:\n");
		printCosimExpected();
	}
	
	return cosimEventTriggered && !cosimError;
}		

// Returns 1 if the masked values match, 0 otherwise
static int compareMasked(uint32_t mask, const uint32_t values1[16],
	const uint32_t values2[16])
{
	int lane;
	
	for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
	{
		if (mask & (1 << lane))
		{
			if (values1[lane] != values2[lane])
				return 0;
		}
	}

	return 1;
}


