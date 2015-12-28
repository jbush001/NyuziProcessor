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

//
// Cosimulation runs as follows:
// 1. The main loop (runCosimulation) reads and parses the next instruction
//    side effect from the Verilator model (piped to this process via stdin).
//    It stores the value in the gExpectedXXX global variables.
// 2. It then calls runUntilNextEvent, which calls into the emulator core to
//    single step until...
// 3. When the emulator core updates a register or performs a memory write,
//    it calls back into this module, one of the cosimCheckXXX functions.
//    The check functions compare the local side effect to the values saved
//    by step 1. If there is a mismatch, they flag an error, otherwise...
// 4. Loop back to step 1
//

static void printCosimExpected(void);
static int runUntilNextEvent(Core*, uint32_t threadId);
static int compareMasked(uint32_t mask, const uint32_t *values1, const uint32_t *values2);

static enum
{
	EVENT_NONE,
	EVENT_MEM_STORE,
	EVENT_VECTOR_WRITEBACK,
	EVENT_SCALAR_WRITEBACK
} gExpectedEvent;
static uint32_t gExpectedRegister;
static uint32_t gExpectedAddress;
static uint64_t gExpectedMask;
static uint32_t gExpectedValues[NUM_VECTOR_LANES];
static uint32_t gExpectedPc;
static uint32_t gExpectedThread;
static bool gError;
static bool gEventTriggered;

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
			{
				printf("Error parsing cosimulation event\n");
				return -1;
			}

			gExpectedEvent = EVENT_MEM_STORE;
			gExpectedPc = pc;
			gExpectedThread = threadId;
			gExpectedAddress = address;
			gExpectedMask = writeMask;
			memcpy(gExpectedValues, vectorValues, sizeof(uint32_t) * NUM_VECTOR_LANES);
			if (!runUntilNextEvent(core, threadId))
				return -1;
		}
		else if (sscanf(line, "vwriteback %x %x %x %" PRIx64 " %s", &pc, &threadId, &reg, &writeMask, valueStr) == 5)
		{
			// Vector writeback
			if (parseHexVector(valueStr, vectorValues, false) < 0)
			{
				printf("Error parsing cosimulation event\n");
				return -1;
			}

			gExpectedEvent = EVENT_VECTOR_WRITEBACK;
			gExpectedPc = pc;
			gExpectedThread = threadId;
			gExpectedRegister = reg;
			gExpectedMask = writeMask;
			memcpy(gExpectedValues, vectorValues, sizeof(uint32_t) * NUM_VECTOR_LANES);
			if (!runUntilNextEvent(core, threadId))
				return -1;
		}
		else if (sscanf(line, "swriteback %x %x %x %x", &pc, &threadId, &reg, &scalarValue) == 4)
		{
			// Scalar Writeback
			gExpectedEvent = EVENT_SCALAR_WRITEBACK;
			gExpectedPc = pc;
			gExpectedThread = threadId;
			gExpectedRegister = reg;
			gExpectedValues[0] = scalarValue;
			if (!runUntilNextEvent(core, threadId))
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
	// gError will be flagged.
	gEventTriggered = false;
	gExpectedEvent = EVENT_NONE;
	while (!coreHalted(core))
	{
		executeInstructions(core, ALL_THREADS, 1);
		if (gError)
			return -1;
	}

	return 0;
}

void cosimCheckSetScalarReg(Core *core, uint32_t pc, uint32_t reg, uint32_t value)
{
	gEventTriggered = true;
	if (gExpectedEvent != EVENT_SCALAR_WRITEBACK
		|| gExpectedPc != pc
		|| gExpectedRegister != reg
		|| gExpectedValues[0] != value)
	{
		gError = true;
		printRegisters(core, gExpectedThread);
		printf("COSIM MISMATCH, thread %d\n", gExpectedThread);
		printf("Reference: %08x s%d <= %08x\n", pc, reg, value);
		printf("Hardware:  ");
		printCosimExpected();
		return;
	}
}

void cosimCheckSetVectorReg(Core *core, uint32_t pc, uint32_t reg, uint32_t mask,
	const uint32_t *values)
{
	int lane;

	gEventTriggered = true;
	if (gExpectedEvent != EVENT_VECTOR_WRITEBACK
		|| gExpectedPc != pc
		|| gExpectedRegister != reg
		|| !compareMasked(mask, gExpectedValues, values)
		|| gExpectedMask != (mask & 0xffff))
	{
		gError = true;
		printRegisters(core, gExpectedThread);
		printf("COSIM MISMATCH, thread %d\n", gExpectedThread);
		printf("Reference: %08x v%d{%04x} <= ", pc, reg, mask & 0xffff);
		for (lane = NUM_VECTOR_LANES - 1; lane >= 0; lane--)
			printf("%08x ", values[lane]);

		printf("\n");
		printf("Hardware:  ");
		printCosimExpected();
		return;
	}
}

void cosimCheckVectorStore(Core *core, uint32_t pc, uint32_t address, uint32_t mask,
	const uint32_t *values)
{
	uint64_t byteMask;
	int lane;

	byteMask = 0;
	for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
	{
		if (mask & (1 << lane))
			byteMask |= 0xfull << (lane * 4);
	}

	gEventTriggered = true;
	if (gExpectedEvent != EVENT_MEM_STORE
		|| gExpectedPc != pc
		|| gExpectedAddress != (address & ~(NUM_VECTOR_LANES * 4u - 1))
		|| gExpectedMask != byteMask
		|| !compareMasked(mask, gExpectedValues, values))
	{
		gError = true;
		printRegisters(core, gExpectedThread);
		printf("COSIM MISMATCH, thread %d\n", gExpectedThread);
		printf("Reference: %08x memory[%x]{%016" PRIx64 "} <= ", pc, address, byteMask);
		for (lane = NUM_VECTOR_LANES - 1; lane >= 0; lane--)
			printf("%08x ", values[lane]);

		printf("\nHardware:  ");
		printCosimExpected();
		return;
	}
}

void cosimCheckScalarStore(Core *core, uint32_t pc, uint32_t address, uint32_t size,
	uint32_t value)
{
	uint32_t hardwareValue;
	uint64_t referenceMask;

	hardwareValue = gExpectedValues[(address & CACHE_LINE_MASK) / 4];
	if (size < 4)
	{
		uint32_t mask = (1 << (size * 8)) - 1;
		hardwareValue &= mask;
		value &= mask;
	}

	referenceMask = ((1ull << size) - 1ull) << (CACHE_LINE_MASK - (address & CACHE_LINE_MASK) - (size - 1));
	gEventTriggered = true;
	if (gExpectedEvent != EVENT_MEM_STORE
		|| gExpectedPc != pc
		|| gExpectedAddress != (address & ~CACHE_LINE_MASK)
		|| gExpectedMask != referenceMask
		|| hardwareValue != value)
	{
		gError = true;
		printRegisters(core, gExpectedThread);
		printf("COSIM MISMATCH, thread %d\n", gExpectedThread);
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

	printf("%08x ", gExpectedPc);

	switch (gExpectedEvent)
	{
		case EVENT_NONE:
			printf(" HALTED\n");
			break;

		case EVENT_MEM_STORE:
			printf("memory[%x]{%016" PRIx64 "} <= ", gExpectedAddress, gExpectedMask);
			for (lane = NUM_VECTOR_LANES - 1; lane >= 0; lane--)
				printf("%08x ", gExpectedValues[lane]);

			printf("\n");
			break;

		case EVENT_VECTOR_WRITEBACK:
			printf("v%d{%04x} <= ", gExpectedRegister, (uint32_t)
				gExpectedMask & 0xffff);
			for (lane = NUM_VECTOR_LANES - 1; lane >= 0; lane--)
				printf("%08x ", gExpectedValues[lane]);

			printf("\n");
			break;

		case EVENT_SCALAR_WRITEBACK:
			printf("s%d <= %08x\n", gExpectedRegister, gExpectedValues[0]);
			break;
	}
}

// Returns 1 if the event matched, 0 if it did not.
static int runUntilNextEvent(Core *core, uint32_t threadId)
{
	int count = 0;

	gError = false;
	gEventTriggered = false;
	for (count = 0; count < 500 && !gEventTriggered; count++)
		singleStep(core, threadId);

	if (!gEventTriggered)
	{
		printf("Simulator program in infinite loop? No event occurred.  Was expecting:\n");
		printCosimExpected();
	}

	return gEventTriggered && !gError;
}

// Returns 1 if the masked values match, 0 otherwise
static int compareMasked(uint32_t mask, const uint32_t *values1, const uint32_t *values2)
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
