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

#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include "core.h"
#include "cosimulation.h"
#include "inttypes.h"
#include "util.h"

static void printCosimExpected(void);
static int cosimStep(Core *core, uint32_t threadId);
static int compareMasked(uint32_t mask, const uint32_t values1[NUM_VECTOR_LANES],
	const uint32_t values2[NUM_VECTOR_LANES]);

static enum 
{
	EVENT_NONE,
	EVENT_MEM_STORE,
	EVENT_VECTOR_WRITEBACK,
	EVENT_SCALAR_WRITEBACK
} cosimCheckEvent;
static uint32_t cosimCheckRegister;
static uint32_t cosimCheckAddress;
static uint64_t cosimCheckMask;
static uint32_t cosimCheckValues[NUM_VECTOR_LANES];
static bool cosimError;
static uint32_t cosimCheckPc;
static bool cosimEventTriggered;
static uint32_t cosimCheckThread;

// Read events from standard in.  Step each emulator thread in lockstep
// and ensure the side effects match.
int runCosimulation(Core *core, bool verbose)
{
	char line[1024];
	uint32_t threadId;
	uint32_t address;
	uint32_t pc;
	uint64_t writeMask;
	uint32_t vectorValues[NUM_VECTOR_LANES];
	char valueStr[256];
	uint32_t reg;
	uint32_t scalarValue;
	bool verilogModelHalted = false;
	unsigned long len;

	enableCosimulation(core);
	if (verbose)
		enableTracing(core);

	while (fgets(line, sizeof(line), stdin))
	{
		if (verbose)
			printf("%s", line);

		len = strlen(line);
		if (len > 0)
			line[len - 1] = '\0';	// Strip off newline

		if (sscanf(line, "store %x %x %x %" PRIx64 " %s", &pc, &threadId, &address, &writeMask, valueStr) == 5)
		{
			// Memory Store
			if (parseHexVector(valueStr, vectorValues, true) < 0)
				return 0;

			cosimCheckEvent = EVENT_MEM_STORE;
			cosimCheckPc = pc;
			cosimCheckThread = threadId;
			cosimCheckAddress = address;
			cosimCheckMask = writeMask;
			memcpy(cosimCheckValues, vectorValues, sizeof(uint32_t) * NUM_VECTOR_LANES);
	
			if (!cosimStep(core, threadId))
				return -1;
		} 
		else if (sscanf(line, "vwriteback %x %x %x %" PRIx64 " %s", &pc, &threadId, &reg, &writeMask, valueStr) == 5)
		{
			// Vector writeback
			if (parseHexVector(valueStr, vectorValues, false) < 0)
			{
				printf("test failed\n");
				return 0;
			}

			cosimCheckEvent = EVENT_VECTOR_WRITEBACK;
			cosimCheckPc = pc;
			cosimCheckThread = threadId;
			cosimCheckRegister = reg;
			cosimCheckMask = writeMask;
			memcpy(cosimCheckValues, vectorValues, sizeof(uint32_t) * NUM_VECTOR_LANES);
	
			if (!cosimStep(core, threadId))
				return -1;
		}
		else if (sscanf(line, "swriteback %x %x %x %x", &pc, &threadId, &reg, &scalarValue) == 4)
		{
			// Scalar Writeback
			cosimCheckEvent = EVENT_SCALAR_WRITEBACK;
			cosimCheckPc = pc;
			cosimCheckThread = threadId;
			cosimCheckRegister = reg;
			cosimCheckValues[0] = scalarValue;

			if (!cosimStep(core, threadId))
				return -1;
		}
		else if (strcmp(line, "***HALTED***") == 0)
		{
			verilogModelHalted = true;
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
		return -1;
	}

	// Ensure emulator is also halted. If it executes any more instructions
	// cosimError will be flagged.
	cosimEventTriggered = false;
	cosimCheckEvent = EVENT_NONE;
	while (!coreHalted(core))
	{
		executeInstructions(core, ALL_THREADS, 1);
		if (cosimError)
			return -1;
	}

	return 0;
}

void cosimSetScalarReg(Core *core, uint32_t pc, uint32_t reg, uint32_t value)
{
	cosimEventTriggered = true;
	if (cosimCheckEvent != EVENT_SCALAR_WRITEBACK
		|| cosimCheckPc != pc
		|| cosimCheckRegister != reg
		|| cosimCheckValues[0] != value)
	{
		cosimError = true;
		printRegisters(core, cosimCheckThread);
		printf("COSIM MISMATCH, thread %d\n", cosimCheckThread);
		printf("Reference: %08x s%d <= %08x\n", pc, reg, value);
		printf("Hardware:  ");
		printCosimExpected();
		return;
	}	
}

void cosimSetVectorReg(Core *core, uint32_t pc, uint32_t reg, uint32_t mask, 
	const uint32_t values[NUM_VECTOR_LANES])
{
	int lane;
	
	cosimEventTriggered = true;
	if (cosimCheckEvent != EVENT_VECTOR_WRITEBACK
		|| cosimCheckPc != pc
		|| cosimCheckRegister != reg
		|| !compareMasked(mask, cosimCheckValues, values)
		|| cosimCheckMask != (mask & 0xffff))
	{
		cosimError = true;
		printRegisters(core, cosimCheckThread);
		printf("COSIM MISMATCH, thread %d\n", cosimCheckThread);
		printf("Reference: %08x v%d{%04x} <= ", pc, reg, mask & 0xffff);
		for (lane = NUM_VECTOR_LANES - 1; lane >= 0; lane--)
			printf("%08x ", values[lane]);

		printf("\n");
		printf("Hardware:  ");
		printCosimExpected();
		return;
	}
}

void cosimWriteBlock(Core *core, uint32_t pc, uint32_t address, uint32_t mask, 
	const uint32_t values[NUM_VECTOR_LANES])
{
	uint64_t byteMask;
	int lane;
	
	byteMask = 0;
	for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
	{
		if (mask & (1 << lane))
			byteMask |= 0xfull << (lane * 4);
	}

	cosimEventTriggered = true;
	if (cosimCheckEvent != EVENT_MEM_STORE
		|| cosimCheckPc != pc
		|| cosimCheckAddress != (address & ~(NUM_VECTOR_LANES * 4u - 1))
		|| cosimCheckMask != byteMask 
		|| !compareMasked(mask, cosimCheckValues, values))
	{
		cosimError = true;
		printRegisters(core, cosimCheckThread);
		printf("COSIM MISMATCH, thread %d\n", cosimCheckThread);
		printf("Reference: %08x memory[%x]{%016" PRIx64 "} <= ", pc, address, byteMask);
		for (lane = NUM_VECTOR_LANES - 1; lane >= 0; lane--)
			printf("%08x ", values[lane]);

		printf("\nHardware:  ");
		printCosimExpected();
		return;
	}
}

void cosimWriteMemory(Core *core, uint32_t pc, uint32_t address, uint32_t size, uint32_t value)
{
	uint32_t hardwareValue;
	uint64_t referenceMask;
	
	hardwareValue = cosimCheckValues[(address & CACHE_LINE_MASK) / 4];
	if (size < 4)
	{
		uint32_t mask = (1 << (size * 8)) - 1;
		hardwareValue &= mask;
		value &= mask;
	}
	
	referenceMask = ((1ull << size) - 1ull) << (CACHE_LINE_MASK - (address & CACHE_LINE_MASK) - (size - 1));
	cosimEventTriggered = true;
	if (cosimCheckEvent != EVENT_MEM_STORE
		|| cosimCheckPc != pc
		|| cosimCheckAddress != (address & ~CACHE_LINE_MASK)
		|| cosimCheckMask != referenceMask
		|| hardwareValue != value)
	{
		cosimError = true;
		printRegisters(core, cosimCheckThread);
		printf("COSIM MISMATCH, thread %d\n", cosimCheckThread);
		printf("Reference: %08x memory[%x]{%016" PRIx64 "} <= %08x\n", pc, address & ~CACHE_LINE_MASK, 
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
		case EVENT_NONE:
			printf(" HALTED\n");
			break;
		
		case EVENT_MEM_STORE:
			printf("memory[%x]{%016" PRIx64 "} <= ", cosimCheckAddress, cosimCheckMask);
			for (lane = NUM_VECTOR_LANES - 1; lane >= 0; lane--)
				printf("%08x ", cosimCheckValues[lane]);
				
			printf("\n");
			break;

		case EVENT_VECTOR_WRITEBACK:
			printf("v%d{%04x} <= ", cosimCheckRegister, (uint32_t) 
				cosimCheckMask & 0xffff);
			for (lane = NUM_VECTOR_LANES - 1; lane >= 0; lane--)
				printf("%08x ", cosimCheckValues[lane]);

			printf("\n");
			break;
			
		case EVENT_SCALAR_WRITEBACK:
			printf("s%d <= %08x\n", cosimCheckRegister, cosimCheckValues[0]);
			break;
	}
}

// Returns 1 if the event matched, 0 if it did not.
static int cosimStep(Core *core, uint32_t threadId)
{
	int count = 0;

	cosimError = false;
	cosimEventTriggered = false;
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
static int compareMasked(uint32_t mask, const uint32_t values1[NUM_VECTOR_LANES],
	const uint32_t values2[NUM_VECTOR_LANES])
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


