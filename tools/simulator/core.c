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



//
// Simulates instruction execution on a single core
//

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <math.h>
#include <assert.h>
#include <fenv.h>
#include "core.h"

#define MIN(a, b) ((a) < (b) ? (a) : (b))
#define LINK_REG 30
#define PC_REG 31

// This is used to signal an instruction that may be a breakpoint.  We use
// a special instruction to avoid a breakpoint lookup on every instruction cycle.
// This is an invalid instruction because it uses a reserved format type
#define BREAKPOINT_OP 0xc07fffff

typedef struct Thread Thread;

typedef enum {
	CR_THREAD_ID = 0,
	CR_FAULT_HANDLER = 1,
	CR_FAULT_PC = 2,
	CR_FAULT_REASON = 3,
	CR_INTERRUPT_ENABLE = 4,
	CR_FAULT_ADDRESS = 5,
	CR_HALT_THREAD = 29,
	CR_THREAD_ENABLE = 30,
	CR_HALT = 31
} ControlRegister;

typedef enum {
	FR_RESET,
	FR_ILLEGAL_INSTRUCTION,
	FR_INVALID_ACCESS,
	FR_INTERRUPT
} FaultReason;

struct Thread
{
	int id;
	Core *core;
	unsigned int linkedAddress;		// Cache line (/ 64)
	unsigned int currentPc;
	unsigned int scalarReg[NUM_REGISTERS - 1];	// 31 is PC, which is special
	unsigned int vectorReg[NUM_REGISTERS][NUM_VECTOR_LANES];
	int multiCycleTransferActive;
	int multiCycleTransferLane;
	FaultReason lastFaultReason;
	unsigned int lastFaultPc;
	unsigned int lastFaultAddress;
	int interruptEnable;
};

struct Core
{
	Thread threads[THREADS_PER_CORE];
	unsigned int *memory;
	unsigned int memorySize;
	struct Breakpoint *breakpoints;
	int singleStepping;
	int threadEnableMask;
	int halt;
	int enableTracing;
	int cosimEnable;
	int cosimEventTriggered;
	int totalInstructionCount;
	enum 
	{
		kMemStore,
		kVectorWriteback,
		kScalarWriteback
	} cosimCheckEvent;
	int cosimCheckRegister;
	unsigned int cosimCheckAddress;
	unsigned long long int cosimCheckMask;
	unsigned int cosimCheckValues[16];
	int cosimError;
	unsigned int cosimCheckPc;
	unsigned int faultHandlerPc;
};

struct Breakpoint
{
	struct Breakpoint *next;
	unsigned int address;
	unsigned int originalInstruction;
	unsigned int restart;
};

int retireInstruction(Thread *thread);

Core *initCore(int memsize)
{
	int i;
	Core *core;

	core = (Core*) calloc(sizeof(Core), 1);
	core->memorySize = memsize;
	core->memory = (unsigned int*) malloc(core->memorySize);
	for (i = 0; i < THREADS_PER_CORE; i++)
	{
		core->threads[i].core = core;
		core->threads[i].id = i;
		core->threads[i].lastFaultReason = FR_RESET;
		core->threads[i].lastFaultPc = 0;
		core->threads[i].interruptEnable = 0;
	}
	
	core->threadEnableMask = 1;
	core->halt = 0;
	core->enableTracing = 0;
	core->totalInstructionCount = 0;
	core->faultHandlerPc = 0;

	return core;
}

int getTotalInstructionCount(const Core *core)
{
	return core->totalInstructionCount;
}

void enableTracing(Core *core)
{
	core->enableTracing = 1;
}

void *getCoreFb(Core *core)
{
	return ((unsigned char*) core->memory) + 0x100000;
}

static void printRegisters(Thread *thread)
{
	int reg;
	int lane;
	
	printf("REGISTERS\n");
	for (reg = 0; reg < 31; reg++)
	{
		if (reg < 10)
			printf(" ");
			
		printf("r%d %08x ", reg, thread->scalarReg[reg]);
		if (reg % 8 == 7)
			printf("\n");
	}

	printf("r31 %08x\n\n", thread->currentPc - 4);
	for (reg = 0; reg < 32; reg++)
	{
		if (reg < 10)
			printf(" ");
			
		printf("v%d ", reg);
		for (lane = 15; lane >= 0; lane--)
			printf("%08x", thread->vectorReg[reg][lane]);
			
		printf("\n");
	}
}

static void printVector(const unsigned int values[16])
{
	int lane;

	for (lane = 15; lane >= 0; lane--)
		printf("%08x ", values[lane]);
}

static void printCosimExpected(const Core *core)
{
	int lane;

	printf("%08x ", core->cosimCheckPc);
	
	switch (core->cosimCheckEvent)
	{
		case kMemStore:
			printf("MEM[%x]{%016llx} <= ", core->cosimCheckAddress, core->cosimCheckMask);
			for (lane = 15; lane >= 0; lane--)
				printf("%08x ", core->cosimCheckValues[lane]);
				
			printf("\n");
			break;

		case kVectorWriteback:
			printf("v%d{%04x} <= ", core->cosimCheckRegister, (unsigned int) 
				core->cosimCheckMask & 0xffff);
			printVector(core->cosimCheckValues);
			printf("\n");
			break;
			
		case kScalarWriteback:
			printf("s%d <= %08x\n", core->cosimCheckRegister, core->cosimCheckValues[0]);
			break;
	}
}

int bitField(unsigned int word, int lowBitOffset, int size)
{
	return (word >> lowBitOffset) & ((1 << size) - 1);
}

int signedBitField(unsigned int word, int lowBitOffset, int size)
{
	unsigned int mask = (1 << size) - 1;
	int value = (word >> lowBitOffset) & mask;
	if (value & (1 << (size - 1)))
		value |= ~mask;	// Sign extend

	return value;
}

unsigned int swap(unsigned int value)
{
	return ((value & 0x000000ff) << 24)
		| ((value & 0x0000ff00) << 8)
		| ((value & 0x00ff0000) >> 8)
		| ((value & 0xff000000) >> 24);
}

int getThreadScalarReg(const Thread *thread, int reg)
{
	if (reg == PC_REG)
		return thread->currentPc;
	else
		return thread->scalarReg[reg];
}

// Returns 1 if the masked values match, 0 otherwise
static int compareMasked(unsigned int mask, const unsigned int values1[16],
	const unsigned int values2[16])
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

void setScalarReg(Thread *thread, int reg, unsigned int value)
{
	if (thread->core->enableTracing)
		printf("%08x [st %d] s%d <= %08x\n", thread->currentPc - 4, thread->id, reg, value);

	thread->core->cosimEventTriggered = 1;
	if (thread->core->cosimEnable
		&& (thread->core->cosimCheckEvent != kScalarWriteback
		|| thread->core->cosimCheckPc != thread->currentPc - 4
		|| thread->core->cosimCheckRegister != reg
		|| thread->core->cosimCheckValues[0] != value))
	{
		thread->core->cosimError = 1;
		printRegisters(thread);
		printf("COSIM MISMATCH, thread %d instruction %x\n", thread->id, thread->core->memory[
			(thread->currentPc / 4) - 1]);
		printf("Reference: %08x s%d <= %08x\n", thread->currentPc - 4, reg, value);
		printf("Hardware:  ");
		printCosimExpected(thread->core);
		return;
	}

	if (reg == PC_REG)
		thread->currentPc = value;
	else
		thread->scalarReg[reg] = value;
}

void setVectorReg(Thread *thread, int reg, int mask, unsigned int values[NUM_VECTOR_LANES])
{
	int lane;

	if (thread->core->enableTracing)
	{
		printf("%08x [st %d] v%d{%04x} <= ", thread->currentPc - 4, thread->id, reg, 
			mask & 0xffff);
		printVector(values);
		printf("\n");
	}

	thread->core->cosimEventTriggered = 1;
	if (thread->core->cosimEnable)
	{
		if (thread->core->cosimCheckEvent != kVectorWriteback
			|| thread->core->cosimCheckPc != thread->currentPc - 4
			|| thread->core->cosimCheckRegister != reg
			|| !compareMasked(mask, thread->core->cosimCheckValues, values)
			|| thread->core->cosimCheckMask != (mask & 0xffff))
		{
			thread->core->cosimError = 1;
			printRegisters(thread);
			printf("COSIM MISMATCH, thread %d instruction %x\n", thread->id, thread->core->memory[
				(thread->currentPc / 4) - 1]);
			printf("Reference: %08x v%d{%04x} <= ", thread->currentPc - 4, reg, mask & 0xffff);
			printVector(values);
			printf("\n");
			printf("Hardware:  ");
			printCosimExpected(thread->core);
			return;
		}
	}

	for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
	{
		if (mask & (1 << lane))
			thread->vectorReg[reg][lane] = values[lane];
	}
}

void invalidateSyncAddress(Core *core, unsigned int address)
{
	int stid;
	
	for (stid = 0; stid < THREADS_PER_CORE; stid++)
	{
		if (core->threads[stid].linkedAddress == address / 64)
		{
			// Invalidate
			core->threads[stid].linkedAddress = 0xffffffff;
		}
	}
}

void memoryAccessFault(Thread *thread, unsigned int address)
{
	thread->lastFaultPc = thread->currentPc - 4;
	thread->currentPc = thread->core->faultHandlerPc;
	thread->lastFaultReason = FR_INVALID_ACCESS;
	thread->interruptEnable = 0;
	thread->lastFaultAddress = address;
}

void writeMemBlock(Thread *thread, unsigned int address, int mask, unsigned int values[16])
{
	int lane;
	unsigned long long int byteMask;

	if ((mask & 0xffff) == 0)
		return;	// Hardware ignores block stores with a mask of zero

	if ((address & 63) != 0)
	{
		memoryAccessFault(thread, address);
		return;
	}

	if (thread->core->enableTracing)
	{
		printf("%08x [st %d] writeMemBlock %08x\n", thread->currentPc - 4, thread->id,
			address);
	}
	
	byteMask = 0;
	for (lane = 0; lane < 16; lane++)
	{
		if (mask & (1 << lane))
			byteMask |= 0xfLL << (lane * 4);
	}
	
	thread->core->cosimEventTriggered = 1;
	if (thread->core->cosimEnable
		&& (thread->core->cosimCheckEvent != kMemStore
		|| thread->core->cosimCheckPc != thread->currentPc - 4
		|| thread->core->cosimCheckAddress != (address & ~63)
		|| thread->core->cosimCheckMask != byteMask 
		|| !compareMasked(mask, thread->core->cosimCheckValues, values)))
	{
		thread->core->cosimError = 1;
		printRegisters(thread);
		printf("COSIM MISMATCH, thread %d instruction %x\n", thread->id, thread->core->memory[
			(thread->currentPc / 4) - 1]);
		printf("Reference: %08x MEM[%x]{%016llx} <= ", thread->currentPc - 4, 
			address, byteMask);
		for (lane = 15; lane >= 0; lane--)
			printf("%08x ", values[lane]);

		printf("\nHardware:  ");
		printCosimExpected(thread->core);
		return;
	}

	for (lane = 15; lane >= 0; lane--)
	{
		if (mask & (1 << lane))
			thread->core->memory[(address / 4) + (15 - lane)] = values[lane];
	}

	invalidateSyncAddress(thread->core, address);
}

void writeMemWord(Thread *thread, unsigned int address, unsigned int value)
{
	if ((address & 0xFFFF0000) == 0xFFFF0000)
	{
		// IO address range
		
		if (address == 0xffff0000)
			printf("%c", value & 0xff); // Console

		return;
	}

	if ((address & 3) != 0)
	{
		memoryAccessFault(thread, address);
		return;
	}

	if (thread->core->enableTracing)
	{
		printf("%08x [st %d] writeMemWord %08x %08x\n", thread->currentPc - 4, thread->id, 
			address, value);
	}
	
	thread->core->cosimEventTriggered = 1;
	if (thread->core->cosimEnable
		&& (thread->core->cosimCheckEvent != kMemStore
		|| thread->core->cosimCheckPc != thread->currentPc - 4
		|| thread->core->cosimCheckAddress != (address & ~63)
		|| thread->core->cosimCheckMask != (0xfLL << (60 - (address & 60)))
		|| thread->core->cosimCheckValues[15 - ((address & 63) / 4)] != value))
	{
		thread->core->cosimError = 1;
		printRegisters(thread);
		printf("COSIM MISMATCH, thread %d instruction %x\n", thread->id, thread->core->memory[
			(thread->currentPc / 4) - 1]);
		printf("Reference: %08x writeMemWord %08x %08x\n", thread->currentPc - 4, address, value);
		printf("Hardware:  ");
		printCosimExpected(thread->core);
		return;
	}

	thread->core->memory[address / 4] = value;
	invalidateSyncAddress(thread->core, address);
}

void writeMemShort(Thread *thread, unsigned int address, unsigned int valueToStore)
{
	if ((address & 1) != 0)
	{
		memoryAccessFault(thread, address);
		return;
	}

	if (thread->core->enableTracing)
	{
		printf("%08x [st %d] writeMemShort %08x %04x\n", thread->currentPc - 4, thread->id,
			address, valueToStore);
	}

	thread->core->cosimEventTriggered = 1;
	if (thread->core->cosimEnable
		&& (thread->core->cosimCheckEvent != kMemStore
		|| thread->core->cosimCheckAddress != (address & ~63)
		|| thread->core->cosimCheckPc != thread->currentPc - 4
		|| thread->core->cosimCheckMask != (0x3LL << (62 - (address & 62)))))
	{
		// XXX !!! does not check value !!!
		thread->core->cosimError = 1;
		printRegisters(thread);
		printf("COSIM MISMATCH, thread %d instruction %x\n", thread->id, thread->core->memory[
			(thread->currentPc / 4) - 1]);
		printf("Reference: %08x writeMemShort %08x %04x\n", thread->currentPc - 4, address, valueToStore);
		printf("Hardware: ");
		printCosimExpected(thread->core);
		return;
	}

	((unsigned short*)thread->core->memory)[address / 2] = valueToStore & 0xffff;
	invalidateSyncAddress(thread->core, address);
}

void writeMemByte(Thread *thread, unsigned int address, unsigned int valueToStore)
{
	if (thread->core->enableTracing)
	{
		printf("%08x [st %d] writeMemByte %08x %02x\n", thread->currentPc - 4, thread->id,
			address, valueToStore);
	}

	thread->core->cosimEventTriggered = 1;
	if (thread->core->cosimEnable
		&& (thread->core->cosimCheckEvent != kMemStore
		|| thread->core->cosimCheckAddress != (address & ~63)
		|| thread->core->cosimCheckPc != thread->currentPc - 4
		|| thread->core->cosimCheckMask != (0x1LL << (63 - (address & 63)))))
	{
		// XXX !!! does not check value !!!
		thread->core->cosimError = 1;
		printRegisters(thread);
		printf("COSIM MISMATCH, thread %d instruction %x\n", thread->id, thread->core->memory[
			(thread->currentPc / 4) - 1]);
		printf("Reference: %08x writeMemByte %08x %02x\n", thread->currentPc - 4, address, valueToStore);
		printf("Hardware: ");
		printCosimExpected(thread->core);
		return;
	}

	((unsigned char*)thread->core->memory)[address] = valueToStore & 0xff;
	invalidateSyncAddress(thread->core, address);
}

void doHalt(Core *core)
{
	core->halt = 1;
}

unsigned int readMemoryWord(const Thread *thread, unsigned int address)
{
	if ((address & 0xffff0000) == 0xffff0000)
	{
		// These dummy values match ones hard coded in the verilog testbench.
		// Used for validating I/O transactions in cosimulation.
		if (address == 0xffff0004)
			return 0x12345678;
		else if (address == 0xffff0008)
			return 0xabcdef9b;
				
		return 0;
	}
	
	if (address >= thread->core->memorySize)
	{
		printf("Read Access Violation %08x, pc %08x\n", address, thread->currentPc - 4);
		printRegisters(thread);
		thread->core->halt = 1;	// XXX Perhaps should stop some other way...
		return 0;
	}

	return thread->core->memory[address / 4];
}

int loadHexFile(Core *core, const char *filename)
{
	FILE *file;
	char line[64];
	unsigned int *memptr = core->memory;

	file = fopen(filename, "r");
	if (file == NULL)
	{
		perror("Error opening hex memory file");
		return -1;
	}

	while (fgets(line, sizeof(line), file))
	{
		*memptr++ = swap(strtoul(line, NULL, 16));
		if ((memptr - core->memory) * 4 >= core->memorySize)
		{
			fprintf(stderr, "code was too bit to fit in memory\n");
			return -1;
		}
	}
	
	fclose(file);

	return 0;
}

void writeMemoryToFile(Core *core, const char *filename, unsigned int baseAddress, 
	int length)
{
	FILE *file;

	file = fopen(filename, "wb+");
	if (file == NULL)
	{
		perror("Error opening memory dump file");
		return;
	}

	if (fwrite((const char*) core->memory + baseAddress, MIN(core->memorySize, length), 1, file) <= 0)
	{
		perror("Error writing memory dump");
		return;
	}
	
	fclose(file);
}

unsigned int getPc(Core *core, int threadId)
{
	return core->threads[threadId].currentPc;
}

int getScalarRegister(Core *core, int threadId, int index)
{
	return getThreadScalarReg(&core->threads[threadId], index);
}

int getVectorRegister(Core *core, int threadId, int index, int lane)
{
	return core->threads[threadId].vectorReg[index][lane];
}

// Returns 1 if the event matched, 0 if it did not.
static int cosimStep(Thread *thread)
{
	int count = 0;

#if 0

	// This doesn't quite work yet because we don't receive events from threads
	// that do control register transfers and therefore don't catch starting
	// the thread right away.
	if (!(thread->core->threadEnableMask & (1 << thread->id)))
	{
		printf("COSIM MISMATCH, thread %d instruction %x\n", thread->id, thread->core->memory[
			(thread->currentPc / 4) - 1]);
		printf("Reference is halted\n");
		printf("Hardware: ");
		printCosimExpected(thread->core);
		return 0;
	}
#endif

	thread->core->cosimEnable = 1;
	thread->core->cosimError = 0;
	thread->core->cosimEventTriggered = 0;
	for (count = 0; count < 500 && !thread->core->cosimEventTriggered; count++)
		retireInstruction(thread);

	if (!thread->core->cosimEventTriggered)
	{
		printf("Simulator program in infinite loop? No event occurred.  Was expecting:\n");
		printCosimExpected(thread->core);
	}
	
	return thread->core->cosimEventTriggered && !thread->core->cosimError;
}		

int cosimMemoryStore(Core *core, int threadId, unsigned int pc, unsigned int address, unsigned long long int mask,
	const unsigned int values[16])
{
	core->cosimCheckEvent = kMemStore;
	core->cosimCheckPc = pc;
	core->cosimCheckAddress = address;
	core->cosimCheckMask = mask;
	memcpy(core->cosimCheckValues, values, sizeof(unsigned int) * 16);
	
	return cosimStep(&core->threads[threadId]);
}

int cosimVectorWriteback(Core *core, int threadId, unsigned int pc, int reg, 
	unsigned int mask, const unsigned int values[16])
{
	core->cosimCheckEvent = kVectorWriteback;
	core->cosimCheckPc = pc;
	core->cosimCheckRegister = reg;
	core->cosimCheckMask = mask;
	memcpy(core->cosimCheckValues, values, sizeof(unsigned int) * 16);
	
	return cosimStep(&core->threads[threadId]);
}

int cosimScalarWriteback(Core *core, int threadId, unsigned int pc, int reg, 
	unsigned int value)
{
	core->cosimCheckEvent = kScalarWriteback;
	core->cosimCheckPc = pc;
	core->cosimCheckRegister = reg;
	core->cosimCheckValues[0] = value;

	return cosimStep(&core->threads[threadId]);
}

int cosimHalt(Core *core)
{
	return core->halt;
}

void cosimInterrupt(Core *core, int threadId, unsigned int pc)
{
	Thread *thread = &core->threads[threadId];
	
	thread->lastFaultPc = pc;
	thread->currentPc = thread->core->faultHandlerPc;
	thread->lastFaultReason = FR_INTERRUPT;
	thread->interruptEnable = 0;
	thread->multiCycleTransferActive = 0;
}

int runQuantum(Core *core, int threadId, int instructions)
{
	int i;
	int thread;
	
	core->singleStepping = 0;
	for (i = 0; i < instructions; i++)
	{
		if (core->threadEnableMask == 0)
		{
			printf("* Thread enable mask is now zero\n");
			return 0;
		}
	
		if (core->halt)
			return 0;

		if (threadId == -1)
		{
			for (thread = 0; thread < THREADS_PER_CORE; thread++)
			{
				if (core->threadEnableMask & (1 << thread))
				{
					if (!retireInstruction(&core->threads[thread]))
						return 0;	// Hit breakpoint
				}
			}
		}
		else
		{
			if (!retireInstruction(&core->threads[threadId]))
				return 0;	// Hit breakpoint
		}
	}

	return 1;
}

void singleStep(Core *core, int threadId)
{
	core->singleStepping = 1;
	retireInstruction(&core->threads[threadId]);	
}

int readMemoryByte(Core *core, unsigned int addr)
{
	return ((unsigned char*) core->memory)[addr];
}

float valueAsFloat(unsigned int value)
{
	return *((float*) &value);
}

unsigned int valueAsInt(float value)
{
	unsigned int ival = *((unsigned int*) &value);

	// The contents of the significand of a NaN result is not fully determined
	// in the spec.  For simplicity, convert to a common form when it is detected.
	if (((ival >> 23) & 0xff) == 0xff && (ival & 0x7fffff) != 0)
		return 0x7fffffff;
	
	return ival;
}

float frac(float value)
{
	return value - (int) value;
}

unsigned int doOp(int operation, unsigned int value1, unsigned int value2)
{
	switch (operation)
	{
		case 0: return value1 | value2;
		case 1: return value1 & value2;
		case 3: return value1 ^ value2;
		case 5: return value1 + value2;
		case 6: return value1 - value2;
		case 7: return value1 * value2;
		case 9:	return ((int)value1) >> (value2 & 31);
		case 10: return value1 >> (value2 & 31);
		case 11: return value1 << (value2 & 31);
		case 12: return value2 == 0 ? 32 : __builtin_clz(value2);
		case 14: return value2 == 0 ? 32 : __builtin_ctz(value2);
		case 15: return value2;
		case 16: return value1 == value2;
		case 17: return value1 != value2;
		case 18: return (int) value1 > (int) value2;
		case 19: return (int) value1 >= (int) value2;
		case 20: return (int) value1 < (int) value2;
		case 21: return (int) value1 <= (int) value2;
		case 22: return value1 > value2;
		case 23: return value1 >= value2;
		case 24: return value1 < value2;
		case 25: return value1 <= value2;
		case 27: return (int) valueAsFloat(value2); // ftoi
		case 28:
		{
			// Reciprocal only has 6 bits of accuracy
			unsigned int result = valueAsInt(1.0 / valueAsFloat(value2 & 0xfffe0000)); 
			if (((result >> 23) & 0xff) != 0xff || (result & 0x7fffff) == 0)
				result &= 0xfffe0000;	// Truncate, but only if not NaN

			return result;
		}
		case 29: return (value2 & 0x80) ? (value2 | 0xffffff00) : value2;
		case 30: return (value2 & 0x8000) ? (value2 | 0xffff0000) : value2;
		case 32: return valueAsInt(valueAsFloat(value1) + valueAsFloat(value2));
		case 33: return valueAsInt(valueAsFloat(value1) - valueAsFloat(value2));
		case 34: return valueAsInt(valueAsFloat(value1) * valueAsFloat(value2));
		case 42: return valueAsInt((float)((int)value2)); // itof
		case 44: return valueAsFloat(value1) > valueAsFloat(value2);
		case 45: return valueAsFloat(value1) >= valueAsFloat(value2);
		case 46: return valueAsFloat(value1) < valueAsFloat(value2);
		case 47: return valueAsFloat(value1) <= valueAsFloat(value2);
		default: return 0;
	}
}

int isCompareOp(int op)
{
	return (op >= 16 && op <= 25) || (op >= 44 && op <= 47);
}

void executeAInstruction(Thread *thread, unsigned int instr)
{
	// A operation
	int fmt = bitField(instr, 26, 3);
	int op = bitField(instr, 20, 6);
	int op1reg = bitField(instr, 0, 5);
	int op2reg = bitField(instr, 15, 5);
	int destreg = bitField(instr, 5, 5);
	int maskreg = bitField(instr, 10, 5);
	int lane;

	if (op == 26)
	{
		// getlane		
		setScalarReg(thread, destreg, thread->vectorReg[op1reg][15 - (getThreadScalarReg(
			thread, op2reg) & 0xf)]);
	}
	else if (isCompareOp(op))
	{
		int result = 0;
		
		if (fmt == 0)
		{
			// Scalar
			result = doOp(op, getThreadScalarReg(thread, op1reg), getThreadScalarReg(thread, 
				op2reg)) ? 0xffff : 0;
		}
		else if (fmt < 4)
		{
			// Vector compares work a little differently than other arithmetic
			// operations: the results are packed together in the 16 low
			// bits of a scalar register

			// Vector/Scalar operation
			int scalarValue = getThreadScalarReg(thread, op2reg);
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
			{
				result >>= 1;
				result |= doOp(op, thread->vectorReg[op1reg][lane],
					scalarValue) ? 0x8000 : 0;
			}
		}
		else
		{
			// Vector/Vector operation
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
			{
				result >>= 1;
				result |= doOp(op, thread->vectorReg[op1reg][lane],
					thread->vectorReg[op2reg][lane]) ? 0x8000 : 0;
			}
		}		
		
		setScalarReg(thread, destreg, result);			
	} 
	else if (fmt == 0)
	{
		int result = doOp(op, getThreadScalarReg(thread, op1reg),
			getThreadScalarReg(thread, op2reg));
		setScalarReg(thread, destreg, result);			
	}
	else
	{
		// Vector arithmetic...
		int result[NUM_VECTOR_LANES];
		int mask;

		switch (fmt)
		{
			case 1: 
			case 4:
				mask = 0xffff; 
				break;
				
			case 2:
			case 5:
				mask = getThreadScalarReg(thread, maskreg); 
				break;
		}
	
		if (op == 13)
		{
			// Shuffle
			unsigned int *src1 = thread->vectorReg[op1reg];
			const unsigned int *src2 = thread->vectorReg[op2reg];
			
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
				result[lane] = src1[15 - (src2[lane] & 0xf)];
		}
		else if (fmt < 4)
		{
			// Vector/Scalar operation
			int scalarValue = getThreadScalarReg(thread, op2reg);
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
			{
				result[lane] = doOp(op, thread->vectorReg[op1reg][lane],
					scalarValue);
			}
		}
		else
		{
			// Vector/Vector operation
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
			{
				result[lane] = doOp(op, thread->vectorReg[op1reg][lane],
					thread->vectorReg[op2reg][lane]);
			}
		}

		setVectorReg(thread, destreg, mask, result);
	}
}

void executeBInstruction(Thread *thread, unsigned int instr)
{
	int fmt = bitField(instr, 28, 3);
	int immValue;
	int op = bitField(instr, 23, 5);
	int op1reg = bitField(instr, 0, 5);
	int maskreg = bitField(instr, 10, 5);
	int destreg = bitField(instr, 5, 5);
	int hasMask = fmt == 2 || fmt == 3 || fmt == 5 || fmt == 6;
	int lane;

	if (hasMask)
		immValue = signedBitField(instr, 15, 8);
	else
		immValue = signedBitField(instr, 10, 13);

	if (op == 26)
	{
		// getlane		
		setScalarReg(thread, destreg, thread->vectorReg[op1reg][15 - (immValue & 0xf)]);
	}
	else if (isCompareOp(op))
	{
		int result = 0;

		if (fmt == 1 || fmt == 2 || fmt == 3)
		{
			// Vector compares work a little differently than other arithmetic
			// operations: the results are packed together in the 16 low
			// bits of a scalar register
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
			{
				result >>= 1;
				result |= doOp(op, thread->vectorReg[op1reg][lane],
					immValue) ? 0x8000 : 0;
			}
		}
		else
		{
			result = doOp(op, getThreadScalarReg(thread, op1reg),
				immValue) ? 0xffff : 0;
		}
		
		setScalarReg(thread, destreg, result);			
	}
	else if (fmt == 0)
	{
		int result = doOp(op, getThreadScalarReg(thread, op1reg),
			immValue);
		setScalarReg(thread, destreg, result);			
	}
	else
	{
		int mask;
		int result[NUM_VECTOR_LANES];
		
		switch (fmt)
		{
			case 1: mask = 0xffff; break;
			case 2: mask = getThreadScalarReg(thread, maskreg); break;
			case 4: mask = 0xffff; break;
			case 5: mask = getThreadScalarReg(thread, maskreg); break;
		}
	
		for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
		{
			int operand1;
			if (fmt == 1 || fmt == 2 || fmt == 3)
				operand1 = thread->vectorReg[op1reg][lane];
			else
				operand1 = getThreadScalarReg(thread, op1reg);

			result[lane] = doOp(op, operand1, immValue);
		}
		
		setVectorReg(thread, destreg, mask, result);
	}
}

void executeScalarLoadStore(Thread *thread, unsigned int instr)
{
	int op = bitField(instr, 25, 4);
	int ptrreg = bitField(instr, 0, 5);
	int offset = signedBitField(instr, 10, 15);
	int destsrcreg = bitField(instr, 5, 5);
	int isLoad = bitField(instr, 29, 1);
	unsigned int address;

	address = getThreadScalarReg(thread, ptrreg) + offset;
	if (address >= thread->core->memorySize && (address & 0xffff0000) != 0xffff0000)
	{
		printf("Access Violation %08x, pc %08x\n", address, thread->currentPc - 4);
		printRegisters(thread);
		thread->core->halt = 1;	// XXX Perhaps should stop some other way...
		return;
	}

	if (isLoad)
	{
		int value;
		int alignment = 1;

		switch (op)
		{
			case 0: 	// Byte
				value = ((unsigned char*) thread->core->memory)[address]; 
				break;
				
			case 1: 	// Byte, sign extend
				value = ((char*) thread->core->memory)[address]; 
				break;
				
			case 2: 	// Short
				if ((address & 1) != 0)
				{
					memoryAccessFault(thread, address);
					return;
				}

				value = ((unsigned short*) thread->core->memory)[address / 2]; 
				break;

			case 3: 	// Short, sign extend
				if ((address & 1) != 0)
				{
					memoryAccessFault(thread, address);
					return;
				}

				value = ((short*) thread->core->memory)[address / 2]; 
				break;

			case 4:	// Load word
				if ((address & 3) != 0)
				{
					memoryAccessFault(thread, address);
					return;
				}

				value = readMemoryWord(thread, address); 
				break;

			case 5:	// Load linked
				if ((address & 3) != 0)
				{
					memoryAccessFault(thread, address);
					return;
				}

				value = readMemoryWord(thread, address);
				thread->linkedAddress = address / 64;
				break;
				
			case 6:	// Load control register
				value = 0;
				break;
		}
		
		setScalarReg(thread, destsrcreg, value);			
	}
	else
	{
		// Store
		// Shift and mask in the value.
		int valueToStore = getThreadScalarReg(thread, destsrcreg);
	
		switch (op)
		{
			case 0:
			case 1:
				writeMemByte(thread, address, valueToStore);
				break;
				
			case 2:
			case 3:
				writeMemShort(thread, address, valueToStore);
				break;
				
			case 4:
				writeMemWord(thread, address, valueToStore);
				break;

			case 5:	// Store synchronized
				if ((int) (address / 64) == thread->linkedAddress)
				{
					// Success
					thread->scalarReg[destsrcreg] = 1;	// HACK: cosim assumes one side effect per inst.
					writeMemWord(thread, address, valueToStore);
				}
				else
					thread->scalarReg[destsrcreg] = 0;	// Fail. Same as above.
				
				break;
				
			case 6:	// Store control register
				break;
		}
	}
}

void executeVectorLoadStore(Thread *thread, unsigned int instr)
{
	int op = bitField(instr, 25, 4);
	int ptrreg = bitField(instr, 0, 5);
	int maskreg = bitField(instr, 10, 5);
	int destsrcreg = bitField(instr, 5, 5);
	int isLoad = bitField(instr, 29, 1);
	int offset;
	int lane;
	int mask;
	unsigned int baseAddress;
	unsigned int address;
	unsigned int result[16];

	if (op == 7 || op == 10 || op == 13)
	{
		// not masked
		offset = signedBitField(instr, 10, 15);
	}
	else
	{
		// masked
		offset = signedBitField(instr, 15, 10);
	}

	// Compute mask value
	switch (op)
	{
		case 7:
		case 10:
		case 13:	// Not masked
			mask = 0xffff;
			break;
			
		case 8:
		case 11:
		case 14:	// Masked
			mask = getThreadScalarReg(thread, maskreg); break;
			break;
	}

	// Perform transfer
	if (op == 7 || op == 8 || op == 9)
	{
		// Block vector access.  Executes in a single cycle
		baseAddress = getThreadScalarReg(thread, ptrreg) + offset;
		if (baseAddress >= thread->core->memorySize)
		{
			printf("Access Violation %08x, pc %08x\n", baseAddress, thread->currentPc - 4);
			printRegisters(thread);
			thread->core->halt = 1;	// XXX Perhaps should stop some other way...
			return;
		}

		if (isLoad)
		{
			if ((baseAddress & 63) != 0)
			{
				memoryAccessFault(thread, baseAddress);
				return;
			}

			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
				result[lane] = readMemoryWord(thread, baseAddress + (15 - lane) * 4);
				
			setVectorReg(thread, destsrcreg, mask, result);
		}
		else
			writeMemBlock(thread, baseAddress, mask, thread->vectorReg[destsrcreg]);
	}
	else
	{
		// Multi-cycle vector access.
		if (!thread->multiCycleTransferActive)
		{
			thread->multiCycleTransferActive = 1;
			thread->multiCycleTransferLane = 15;
		}
		else
		{
			thread->multiCycleTransferLane -= 1;
			if (thread->multiCycleTransferLane == 0)
				thread->multiCycleTransferActive = 0;
		}
	
		lane = thread->multiCycleTransferLane;
		address = thread->vectorReg[ptrreg][lane] + offset;
		if (address >= thread->core->memorySize)
		{
			printf("Access Violation %08x, pc %08x\n", address, thread->currentPc - 4);
			printRegisters(thread);
			thread->core->halt = 1;	// XXX Perhaps should stop some other way...
			return;
		}

		if (isLoad)
		{
			unsigned int values[16];
			memset(values, 0, 16 * sizeof(unsigned int));
			if (mask & (1 << lane))
			{
				if ((address & 3) != 0)
				{
					memoryAccessFault(thread, address);
					return;
				}

				values[lane] = readMemoryWord(thread, address);
			}
			
			setVectorReg(thread, destsrcreg, mask & (1 << lane), values);
		}
		else if (mask & (1 << lane))
			writeMemWord(thread, address, thread->vectorReg[destsrcreg][lane]);
	}

	if (thread->multiCycleTransferActive)
		thread->currentPc -= 4;	// repeat current instruction
}

void executeControlRegister(Thread *thread, unsigned int instr)
{
	int crIndex = bitField(instr, 0, 5);
	int dstSrcReg = bitField(instr, 5, 5);
	if (bitField(instr, 29, 1))
	{
		// Load
		unsigned int value = 0xffffffff;
		switch (crIndex)
		{
			case CR_THREAD_ID:
				value = thread->id;
				break;
			
			case CR_FAULT_HANDLER:
				value = thread->core->faultHandlerPc;
				break;
			
			case CR_FAULT_PC:
				value = thread->lastFaultPc;
				break;
				
			case CR_FAULT_REASON:
				value = thread->lastFaultReason;
				break;
				
			case CR_INTERRUPT_ENABLE:
				value = thread->interruptEnable;
				break;
				
			case CR_FAULT_ADDRESS:
				value = thread->lastFaultAddress;
				break;
				
			case CR_THREAD_ENABLE:
				value = thread->core->threadEnableMask;
				break;
		}

		setScalarReg(thread, dstSrcReg, value);
	}
	else
	{
		// Store
		unsigned int value = getThreadScalarReg(thread, dstSrcReg);
		switch (crIndex)
		{
			case CR_FAULT_HANDLER:
				thread->core->faultHandlerPc = value;
				break;
				
			case CR_INTERRUPT_ENABLE:
				thread->interruptEnable = value;;
				break;
			
			case CR_HALT_THREAD:
				thread->core->threadEnableMask &= ~(1 << thread->id);
				if (thread->core->threadEnableMask == 0)
					doHalt(thread->core);

				break;
		
			case CR_THREAD_ENABLE:
				thread->core->threadEnableMask = getThreadScalarReg(thread, dstSrcReg);
				if (thread->core->threadEnableMask == 0)
					doHalt(thread->core);
					
				break;
				
			case CR_HALT:
				doHalt(thread->core);
				break;
		}
	}
}

void executeCInstruction(Thread *thread, unsigned int instr)
{
	int type = bitField(instr, 25, 4);

	if (type == 6)
		executeControlRegister(thread, instr);	
	else if (type < 6)
		executeScalarLoadStore(thread, instr);
	else
		executeVectorLoadStore(thread, instr);
}

void executeEInstruction(Thread *thread, unsigned int instr)
{
	int branchTaken;
	int srcReg = bitField(instr, 0, 5);

	switch (bitField(instr, 25, 3))
	{
		case 0: 
			branchTaken = (getThreadScalarReg(thread, srcReg) & 0xffff) == 0xffff;
			break;
			
		case 1: 
			branchTaken = getThreadScalarReg(thread, srcReg) == 0;
			break;

		case 2:
			branchTaken = getThreadScalarReg(thread, srcReg) != 0;
			break;

		case 3:
			branchTaken = 1;
			break;
			
		case 4:	// call
			branchTaken = 1;
			setScalarReg(thread, LINK_REG, thread->currentPc);
			break;
			
		case 5:
			branchTaken = (getThreadScalarReg(thread, srcReg) & 0xffff) != 0xffff;
			break;
			
		case 6:
			setScalarReg(thread, LINK_REG, thread->currentPc);
			thread->currentPc = getThreadScalarReg(thread, srcReg);
			return; // Short circuit out, since we use register as destination.
			
		case 7:
			thread->currentPc = thread->lastFaultPc;
			return; // Short circuit out
	}
	
	if (branchTaken)
		thread->currentPc += signedBitField(instr, 5, 20);
}

struct Breakpoint *lookupBreakpoint(Core *core, unsigned int pc)
{
	struct Breakpoint *breakpoint;
	
	for (breakpoint = core->breakpoints; breakpoint; breakpoint =
		breakpoint->next)
	{
		if (breakpoint->address == pc)
			return breakpoint;
	}

	return NULL;
}

void setBreakpoint(Core *core, unsigned int pc)
{
	struct Breakpoint *breakpoint = lookupBreakpoint(core, pc);
	if (breakpoint != NULL)
	{
		printf("* already has a breakpoint at this address\n");
		return;
	}
		
	breakpoint = (struct Breakpoint*) calloc(sizeof(struct Breakpoint), 1);
	breakpoint->next = core->breakpoints;
	core->breakpoints = breakpoint;
	breakpoint->address = pc;
	breakpoint->originalInstruction = core->memory[pc / 4];
	if (breakpoint->originalInstruction == BREAKPOINT_OP)
		breakpoint->originalInstruction = 0;
	
	core->memory[pc / 4] = BREAKPOINT_OP;
}

void clearBreakpoint(Core *core, unsigned int pc)
{
	struct Breakpoint **link;

	for (link = &core->breakpoints; *link; link = &(*link)->next)
	{
		if ((*link)->address == pc)
		{
			core->memory[pc / 4] = (*link)->originalInstruction;
			*link = (*link)->next;
			break;
		}
	}
}

void forEachBreakpoint(Core *core, void (*callback)(unsigned int pc))
{
	struct Breakpoint *breakpoint;

	for (breakpoint = core->breakpoints; breakpoint; breakpoint = breakpoint->next)
		callback(breakpoint->address);
}

// XXX should probably have a switch statement for more efficient op type
// lookup.
int retireInstruction(Thread *thread)
{
	unsigned int instr;

	instr = readMemoryWord(thread, thread->currentPc);
	thread->currentPc += 4;
	thread->core->totalInstructionCount++;

restart:
	if (instr == BREAKPOINT_OP)
	{
		struct Breakpoint *breakpoint = lookupBreakpoint(thread->core, thread->currentPc - 4);
		if (breakpoint == NULL)
		{
			thread->currentPc += 4;
			return 1;	// Naturally occurring invalid instruction
		}
		
		if (breakpoint->restart || thread->core->singleStepping)
		{
			breakpoint->restart = 0;
			instr = breakpoint->originalInstruction;
			assert(instr != BREAKPOINT_OP);
			goto restart;
		}
		else
		{
			// Hit a breakpoint
			breakpoint->restart = 1;
			return 0;
		}
	}
	else if (instr == 0)
	{
		// Do nothing.  The hardware explicitly disables writeback for NOPs.
	}
	else if ((instr & 0xe0000000) == 0xc0000000)
		executeAInstruction(thread, instr);
	else if ((instr & 0x80000000) == 0)
		executeBInstruction(thread, instr);
	else if ((instr & 0xc0000000) == 0x80000000)
		executeCInstruction(thread, instr);
	else if ((instr & 0xf0000000) == 0xe0000000)
		;	// Format D instruction.  Ignore
	else if ((instr & 0xf0000000) == 0xf0000000)
		executeEInstruction(thread, instr);
	else
		printf("* Unknown instruction\n");

	return 1;
}
