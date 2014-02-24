// 
// Copyright 2011-2012 Jeff Bush
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

typedef struct Strand Strand;

struct Strand
{
	int id;
	Core *core;
	unsigned int linkedAddress;		// Cache line (/ 64)
	unsigned int currentPc;
	unsigned int scalarReg[NUM_REGISTERS - 1];	// 31 is PC, which is special
	unsigned int vectorReg[NUM_REGISTERS][NUM_VECTOR_LANES];
	int multiCycleTransferActive;
	int multiCycleTransferLane;
};

struct Core
{
	Strand strands[4];
	unsigned int *memory;
	unsigned int memorySize;
	struct Breakpoint *breakpoints;
	int singleStepping;
	int currentStrand;	// For debug commands
	int strandEnableMask;
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
};

struct Breakpoint
{
	struct Breakpoint *next;
	unsigned int address;
	unsigned int originalInstruction;
	unsigned int restart;
};

int retireInstruction(Strand *strand);

Core *initCore(int memsize)
{
	int i;
	Core *core;

	core = (Core*) calloc(sizeof(Core), 1);
	core->memorySize = memsize;
	core->memory = (unsigned int*) malloc(core->memorySize);
	for (i = 0; i < 4; i++)
	{
		core->strands[i].core = core;
		core->strands[i].id = i;
	}
	
	core->strandEnableMask = 1;
	core->halt = 0;
	core->enableTracing = 0;
	core->totalInstructionCount = 0;

	// Set floating point emulation mode to match hardware.
	if (fesetround(FE_TOWARDZERO) != 0)
		printf("error setting rounding mode\n");

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

static void printRegisters(Strand *strand)
{
	int reg;
	int lane;
	
	printf("REGISTERS\n");
	for (reg = 0; reg < 31; reg++)
	{
		if (reg < 10)
			printf(" ");
			
		printf("r%d %08x ", reg, strand->scalarReg[reg]);
		if (reg % 8 == 7)
			printf("\n");
	}

	printf("r31 %08x\n\n", strand->currentPc - 4);
	for (reg = 0; reg < 32; reg++)
	{
		if (reg < 10)
			printf(" ");
			
		printf("v%d ", reg);
		for (lane = 15; lane >= 0; lane--)
			printf("%08x", strand->vectorReg[reg][lane]);
			
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
			printf("MEM[%x]{%04x} <= ", core->cosimCheckAddress, (unsigned int) 
				core->cosimCheckMask & 0xffff);
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

int getStrandScalarReg(const Strand *strand, int reg)
{
	if (reg == PC_REG)
		return strand->currentPc;
	else
		return strand->scalarReg[reg];
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

void setScalarReg(Strand *strand, int reg, unsigned int value)
{
	if (strand->core->enableTracing)
		printf("%08x [st %d] s%d <= %08x\n", strand->currentPc - 4, strand->id, reg, value);

	strand->core->cosimEventTriggered = 1;
	if (strand->core->cosimEnable
		&& (strand->core->cosimCheckEvent != kScalarWriteback
		|| strand->core->cosimCheckPc != strand->currentPc - 4
		|| strand->core->cosimCheckRegister != reg
		|| strand->core->cosimCheckValues[0] != value))
	{
		strand->core->cosimError = 1;
		printRegisters(strand);
		printf("COSIM MISMATCH, strand %d instruction %x\n", strand->id, strand->core->memory[
			(strand->currentPc / 4) - 1]);
		printf("Reference: %08x s%d <= %08x\n", strand->currentPc - 4, reg, value);
		printf("Hardware:  ");
		printCosimExpected(strand->core);
	}

	if (reg == PC_REG)
		strand->currentPc = value;
	else
		strand->scalarReg[reg] = value;
}

void setVectorReg(Strand *strand, int reg, int mask, unsigned int values[NUM_VECTOR_LANES])
{
	int lane;

	if (strand->core->enableTracing)
	{
		printf("%08x [st %d] v%d{%04x} <= ", strand->currentPc - 4, strand->id, reg, 
			mask & 0xffff);
		printVector(values);
		printf("\n");
	}

	strand->core->cosimEventTriggered = 1;
	if (strand->core->cosimEnable)
	{
		if (strand->core->cosimCheckEvent != kVectorWriteback
			|| strand->core->cosimCheckPc != strand->currentPc - 4
			|| strand->core->cosimCheckRegister != reg
			|| !compareMasked(mask, strand->core->cosimCheckValues, values)
			|| strand->core->cosimCheckMask != (mask & 0xffff))
		{
			strand->core->cosimError = 1;
			printRegisters(strand);
			printf("COSIM MISMATCH, strand %d instruction %x\n", strand->id, strand->core->memory[
				(strand->currentPc / 4) - 1]);
			printf("Reference: %08x v%d{%04x} <= ", strand->currentPc - 4, reg, mask & 0xffff);
			printVector(values);
			printf("\n");
			printf("Hardware:  ");
			printCosimExpected(strand->core);
		}
	}

	for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
	{
		if (mask & (1 << lane))
			strand->vectorReg[reg][lane] = values[lane];
	}
}

void writeMemBlock(Strand *strand, unsigned int address, int mask, unsigned int values[16])
{
	int lane;

	if ((mask & 0xffff) == 0)
		return;	// Hardware ignores block stores with a mask of zero

	if (address >= strand->core->memorySize)
	{
		printf("* Write Access Violation %08x, pc %08x\n", address, strand->currentPc - 4);
		strand->core->halt = 1;	// XXX Perhaps should stop some other way...
		return;
	}

	if (strand->core->enableTracing)
	{
		printf("%08x [st %d] writeMemBlock %08x\n", strand->currentPc - 4, strand->id,
			address);
	}
	
	strand->core->cosimEventTriggered = 1;
	if (strand->core->cosimEnable
		&& (strand->core->cosimCheckEvent != kMemStore
		|| strand->core->cosimCheckPc != strand->currentPc - 4
		|| strand->core->cosimCheckAddress != (address & ~63)
//		|| strand->core->cosimCheckMask != mask // XXX need to convert 16->64 bit mask
		|| !compareMasked(mask, strand->core->cosimCheckValues, values)))
	{
		strand->core->cosimError = 1;
		printRegisters(strand);
		printf("COSIM MISMATCH, strand %d instruction %x\n", strand->id, strand->core->memory[
			(strand->currentPc / 4) - 1]);
		printf("Reference: %08x writeMemBlock %08x\n", strand->currentPc - 4, address);
		printf("Hardware:  ");
		printCosimExpected(strand->core);
	}

	for (lane = 15; lane >= 0; lane--)
	{
		if (mask & (1 << lane))
			strand->core->memory[(address / 4) + (15 - lane)] = values[lane];
	}
}

void writeMemWord(Strand *strand, unsigned int address, unsigned int value)
{
	int stid;
	if ((address & 0xFFFF0000) == 0xFFFF0000)
	{
		// Simulate output device
		printf("%c", value & 0xff);
		return;
	}

	if (address >= strand->core->memorySize || ((address & 3) != 0))
	{
		printf("* Write Access Violation %08x, pc %08x\n", address, strand->currentPc - 4);
		strand->core->halt = 1;	// XXX Perhaps should stop some other way...
		return;
	}

	if (strand->core->enableTracing)
	{
		printf("%08x [st %d] writeMemWord %08x %08x\n", strand->currentPc - 4, strand->id, 
			address, value);
	}
	
	strand->core->cosimEventTriggered = 1;
	if (strand->core->cosimEnable
		&& (strand->core->cosimCheckEvent != kMemStore
		|| strand->core->cosimCheckPc != strand->currentPc - 4
		|| strand->core->cosimCheckAddress != (address & ~63)
		|| strand->core->cosimCheckMask != (0xfLL << (60 - (address & 60)))
		|| strand->core->cosimCheckValues[15 - ((address & 63) / 4)] != value))
	{
		strand->core->cosimError = 1;
		printRegisters(strand);
		printf("COSIM MISMATCH, strand %d instruction %x\n", strand->id, strand->core->memory[
			(strand->currentPc / 4) - 1]);
		printf("Reference: %08x writeMemWord %08x %08x\n", strand->currentPc - 4, address, value);
		printf("Hardware:  ");
		printCosimExpected(strand->core);
	}

	strand->core->memory[address / 4] = value;
	for (stid = 0; stid < 4; stid++)
	{
		if (&strand->core->strands[stid] != strand && strand->core->strands[stid].linkedAddress
			== address / 64)
		{
			// Invalidate
			strand->core->strands[stid].linkedAddress = 0xffffffff;
		}
	}
}

void writeMemShort(Strand *strand, unsigned int address, unsigned int valueToStore)
{
	if (strand->core->enableTracing)
	{
		printf("%08x [st %d] writeMemShort %08x %04x\n", strand->currentPc - 4, strand->id,
			address, valueToStore);
	}
	
	if (address >= strand->core->memorySize || ((address & 1) != 0))
	{
		printf("* Write Access Violation %08x, pc %08x\n", address, strand->currentPc - 4);
		strand->core->halt = 1;	// XXX Perhaps should stop some other way...
		return;
	}

	strand->core->cosimEventTriggered = 1;
	if (strand->core->cosimEnable
		&& (strand->core->cosimCheckEvent != kMemStore
		|| strand->core->cosimCheckAddress != (address & ~63)
		|| strand->core->cosimCheckPc != strand->currentPc - 4
		|| strand->core->cosimCheckMask != (0x3LL << (62 - (address & 62)))))
	{
		// XXX !!! does not check value !!!
		strand->core->cosimError = 1;
		printRegisters(strand);
		printf("COSIM MISMATCH, strand %d instruction %x\n", strand->id, strand->core->memory[
			(strand->currentPc / 4) - 1]);
		printf("Reference: %08x writeMemShort %08x %04x\n", strand->currentPc - 4, address, valueToStore);
		printf("Hardware: ");
		printCosimExpected(strand->core);
	}

	((unsigned short*)strand->core->memory)[address / 2] = valueToStore & 0xffff;
}

void writeMemByte(Strand *strand, unsigned int address, unsigned int valueToStore)
{
	if (strand->core->enableTracing)
	{
		printf("%08x [st %d] writeMemByte %08x %02x\n", strand->currentPc - 4, strand->id,
			address, valueToStore);
	}
	
	strand->core->cosimEventTriggered = 1;
	if (strand->core->cosimEnable
		&& (strand->core->cosimCheckEvent != kMemStore
		|| strand->core->cosimCheckAddress != (address & ~63)
		|| strand->core->cosimCheckPc != strand->currentPc - 4
		|| strand->core->cosimCheckMask != (0x1LL << (63 - (address & 63)))))
	{
		// XXX !!! does not check value !!!
		strand->core->cosimError = 1;
		printRegisters(strand);
		printf("COSIM MISMATCH, strand %d instruction %x\n", strand->id, strand->core->memory[
			(strand->currentPc / 4) - 1]);
		printf("Reference: %08x writeMemByte %08x %02x\n", strand->currentPc - 4, address, valueToStore);
		printf("Hardware: ");
		printCosimExpected(strand->core);
	}

	((unsigned char*)strand->core->memory)[address] = valueToStore & 0xff;
}

void doHalt(Core *core)
{
	core->halt = 1;
}

unsigned int readMemory(const Strand *strand, unsigned int address)
{
	if (address >= strand->core->memorySize || ((address & 1) != 0))
	{
		printf("* Read Access Violation %08x, pc %08x\n", address, strand->currentPc - 4);
		strand->core->halt = 1;	// XXX Perhaps should stop some other way...
		return 0;
	}

	return strand->core->memory[address / 4];
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

unsigned int getPc(Core *core)
{
	return core->strands[core->currentStrand].currentPc;
}

void setCurrentStrand(Core *core, int strand)
{
	core->currentStrand = strand;
}

int getCurrentStrand(Core *core)
{
	return core->currentStrand;
}

int getScalarRegister(Core *core, int index)
{
	return getStrandScalarReg(&core->strands[core->currentStrand], index);
}

int getVectorRegister(Core *core, int index, int lane)
{
	return core->strands[core->currentStrand].vectorReg[index][lane];
}

// Returns 1 if the event matched, 0 if it did not.
static int cosimStep(Strand *strand)
{
	int count = 0;

#if 0

	// This doesn't quite work yet because we don't receive events from strands
	// that do control register transfers and therefore don't catch starting
	// the strand right away.
	if (!(strand->core->strandEnableMask & (1 << strand->id)))
	{
		printf("COSIM MISMATCH, strand %d instruction %x\n", strand->id, strand->core->memory[
			(strand->currentPc / 4) - 1]);
		printf("Reference is halted\n");
		printf("Hardware: ");
		printCosimExpected(strand->core);
		return 0;
	}
#endif

	strand->core->cosimEnable = 1;
	strand->core->cosimError = 0;
	strand->core->cosimEventTriggered = 0;
	for (count = 0; count < 50 && !strand->core->cosimEventTriggered; count++)
		retireInstruction(strand);

	if (!strand->core->cosimEventTriggered)
		printf("No event triggered\n");
	
	return strand->core->cosimEventTriggered && !strand->core->cosimError;
}		

int cosimMemoryStore(Core *core, int strandId, unsigned int pc, unsigned int address, unsigned long long int mask,
	const unsigned int values[16])
{
	core->cosimCheckEvent = kMemStore;
	core->cosimCheckPc = pc;
	core->cosimCheckAddress = address;
	core->cosimCheckMask = mask;
	memcpy(core->cosimCheckValues, values, sizeof(unsigned int) * 16);
	
	return cosimStep(&core->strands[strandId]);
}

int cosimVectorWriteback(Core *core, int strandId, unsigned int pc, int reg, 
	unsigned int mask, const unsigned int values[16])
{
	int i;
	
	core->cosimCheckEvent = kVectorWriteback;
	core->cosimCheckPc = pc;
	core->cosimCheckRegister = reg;
	core->cosimCheckMask = mask;
	memcpy(core->cosimCheckValues, values, sizeof(unsigned int) * 16);
	
	return cosimStep(&core->strands[strandId]);
}

int cosimScalarWriteback(Core *core, int strandId, unsigned int pc, int reg, 
	unsigned int value)
{
	core->cosimCheckEvent = kScalarWriteback;
	core->cosimCheckPc = pc;
	core->cosimCheckRegister = reg;
	core->cosimCheckValues[0] = value;

	return cosimStep(&core->strands[strandId]);
}

int cosimHalt(Core *core)
{
	return core->halt;
}

int runQuantum(Core *core, int instructions)
{
	int i;
	int strand;
	
	core->singleStepping = 0;
	for (i = 0; i < instructions; i++)
	{
		if (core->strandEnableMask == 0)
		{
			printf("* Strand enable mask is now zero\n");
			return 0;
		}
	
		if (core->halt)
		{
			printf("* HALT request\n");
			return 0;
		}

		for (strand = 0; strand < 4; strand++)
		{
			if (core->strandEnableMask & (1 << strand))
			{
				if (!retireInstruction(&core->strands[strand]))
					return 0;	// Hit breakpoint
			}
		}
	}

	return 1;
}

void singleStep(Core *core)
{
	core->singleStepping = 1;
	retireInstruction(&core->strands[core->currentStrand]);	
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
	return *((unsigned int*) &value);
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
		case 2: return -value2;
		case 3: return value1 ^ value2;
		case 5: return value1 + value2;
		case 6: return value1 - value2;
		case 7: return value1 * value2;
		case 8: return value1 / value2;
		case 9:	// Arithmetic shift right
			if (value2 < 32) 
				return ((int)value1) >> value2;
			else if (value1 & 0x80000000)
				return 0xffffffff;	// Sign extend
			else
				return 0;

		case 10: return value2 < 32 ? value1 >> value2 : 0;
		case 11: return value2 < 32 ? value1 << value2 : 0;
		case 12: return __builtin_clz(value2);
		case 14: return __builtin_ctz(value2);
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
		case 28: return valueAsInt(1.0 / valueAsFloat(value2));	// XXX should be estimate
		case 29: return (value2 & 0x80) ? (value2 | 0xffffff00) : value2;
		case 30: return (value2 & 0x8000) ? (value2 | 0xffff0000) : value2;
		case 32: return valueAsInt(valueAsFloat(value1) + valueAsFloat(value2));
		case 33: return valueAsInt(valueAsFloat(value1) - valueAsFloat(value2));
		case 34: return valueAsInt(valueAsFloat(value1) * valueAsFloat(value2));
		case 38: return valueAsInt(floor(valueAsFloat(value2)));
		case 39: return valueAsInt(frac(valueAsFloat(value2)));
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

void executeAInstruction(Strand *strand, unsigned int instr)
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
		setScalarReg(strand, destreg, strand->vectorReg[op1reg][15 - getStrandScalarReg(
			strand, op2reg) & 0xf]);
	}
	else if (isCompareOp(op))
	{
		int result = 0;
		
		if (fmt == 0)
		{
			// Scalar
			result = doOp(op, getStrandScalarReg(strand, op1reg), getStrandScalarReg(strand, 
				op2reg)) ? 0xffff : 0;
		}
		else if (fmt < 4)
		{
			// Vector compares work a little differently than other arithmetic
			// operations: the results are packed together in the 16 low
			// bits of a scalar register

			// Vector/Scalar operation
			int scalarValue = getStrandScalarReg(strand, op2reg);
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
			{
				result >>= 1;
				result |= doOp(op, strand->vectorReg[op1reg][lane],
					scalarValue) ? 0x8000 : 0;
			}
		}
		else
		{
			// Vector/Vector operation
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
			{
				result >>= 1;
				result |= doOp(op, strand->vectorReg[op1reg][lane],
					strand->vectorReg[op2reg][lane]) ? 0x8000 : 0;
			}
		}		
		
		setScalarReg(strand, destreg, result);			
	} 
	else if (fmt == 0)
	{
		int result = doOp(op, getStrandScalarReg(strand, op1reg),
			getStrandScalarReg(strand, op2reg));
		setScalarReg(strand, destreg, result);			
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
				mask = getStrandScalarReg(strand, maskreg); 
				break;
				
			case 3:
			case 6:
				mask = ~getStrandScalarReg(strand, maskreg); 
				break;
		}
	
		if (op == 13)
		{
			// Shuffle
			unsigned int *src1 = strand->vectorReg[op1reg];
			const unsigned int *src2 = strand->vectorReg[op2reg];
			
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
				result[lane] = src1[15 - (src2[lane] & 0xf)];
		}
		else if (fmt < 4)
		{
			// Vector/Scalar operation
			int scalarValue = getStrandScalarReg(strand, op2reg);
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
			{
				result[lane] = doOp(op, strand->vectorReg[op1reg][lane],
					scalarValue);
			}
		}
		else
		{
			// Vector/Vector operation
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
			{
				result[lane] = doOp(op, strand->vectorReg[op1reg][lane],
					strand->vectorReg[op2reg][lane]);
			}
		}

		setVectorReg(strand, destreg, mask, result);
	}
}

void executeBInstruction(Strand *strand, unsigned int instr)
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
		setScalarReg(strand, destreg, strand->vectorReg[op1reg][15 - (immValue & 0xf)]);
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
				result |= doOp(op, strand->vectorReg[op1reg][lane],
					immValue) ? 0x8000 : 0;
			}
		}
		else
		{
			result = doOp(op, getStrandScalarReg(strand, op1reg),
				immValue) ? 0xffff : 0;
		}
		
		setScalarReg(strand, destreg, result);			
	}
	else if (fmt == 0)
	{
		int result = doOp(op, getStrandScalarReg(strand, op1reg),
			immValue);
		setScalarReg(strand, destreg, result);			
	}
	else
	{
		int mask;
		int result[NUM_VECTOR_LANES];
		
		switch (fmt)
		{
			case 1: mask = 0xffff; break;
			case 2: mask = getStrandScalarReg(strand, maskreg); break;
			case 3: mask = ~getStrandScalarReg(strand, maskreg); break;
			case 4: mask = 0xffff; break;
			case 5: mask = getStrandScalarReg(strand, maskreg); break;
			case 6: mask = ~getStrandScalarReg(strand, maskreg); break;
		}
	
		for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
		{
			int operand1;
			if (fmt == 1 || fmt == 2 || fmt == 3)
				operand1 = strand->vectorReg[op1reg][lane];
			else
				operand1 = getStrandScalarReg(strand, op1reg);

			result[lane] = doOp(op, operand1, immValue);
		}
		
		setVectorReg(strand, destreg, mask, result);
	}
}

void executeScalarLoadStore(Strand *strand, unsigned int instr)
{
	int op = bitField(instr, 25, 4);
	int ptrreg = bitField(instr, 0, 5);
	int offset = signedBitField(instr, 10, 15);
	int destsrcreg = bitField(instr, 5, 5);
	int isLoad = bitField(instr, 29, 1);
	unsigned int ptr;

	ptr = getStrandScalarReg(strand, ptrreg) + offset;
	if (isLoad)
	{
		int value;

		switch (op)
		{
			case 0: 	// Byte
				value = ((unsigned char*) strand->core->memory)[ptr]; 
				break;
				
			case 1: 	// Byte, sign extend
				value = ((char*) strand->core->memory)[ptr]; 
				break;
				
			case 2: 	// Short
				// XXX check for alignment 
				value = ((unsigned short*) strand->core->memory)[ptr / 2]; 
				break;

			case 3: 	// Short, sign extend
				// XXX Check for alignment
				value = ((short*) strand->core->memory)[ptr / 2]; 
				break;

			case 4:	// Load word
				value = readMemory(strand, ptr); 
				break;

			case 5:	// Load linked
				value = readMemory(strand, ptr);
				strand->linkedAddress = ptr / 64;
				break;
				
			case 6:	// Load control register
				value = 0;
				break;
		}
		
		setScalarReg(strand, destsrcreg, value);			
	}
	else
	{
		// Store
		// Shift and mask in the value.
		int valueToStore = getStrandScalarReg(strand, destsrcreg);
	
		switch (op)
		{
			case 0:
			case 1:
				writeMemByte(strand, ptr, valueToStore);
				break;
				
			case 2:
			case 3:
				writeMemShort(strand, ptr, valueToStore);
				break;
				
			case 4:
				writeMemWord(strand, ptr, valueToStore);
				break;

			case 5:	// Store linked
				if ((int) (ptr / 64) == strand->linkedAddress)
				{
					writeMemWord(strand, ptr, valueToStore);
					setScalarReg(strand, destsrcreg, 1);	// Success
				}
				else
					setScalarReg(strand, destsrcreg, 0);	// Failure
				
				break;
				
			case 6:	// Store control register
				break;
		}
	}
}

void executeVectorLoadStore(Strand *strand, unsigned int instr)
{
	int op = bitField(instr, 25, 4);
	int ptrreg = bitField(instr, 0, 5);
	int maskreg = bitField(instr, 10, 5);
	int destsrcreg = bitField(instr, 5, 5);
	int isLoad = bitField(instr, 29, 1);
	int offset;
	int lane;
	int mask;
	unsigned int basePtr;
	unsigned int pointer;
	unsigned int result[16];

	if (op == 7 || op == 10 || op == 13)
	{
		// not masked
		if (op == 10)	// Strided
			offset = bitField(instr, 10, 15);
		else		
			offset = signedBitField(instr, 10, 15);
	}
	else
	{
		// masked
		if (op == 11 || op == 12)	// Strided
			offset = bitField(instr, 15, 10);
		else		
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
			mask = getStrandScalarReg(strand, maskreg); break;
			break;
			
		case 9:
		case 12:
		case 15:	// Invert Mask
			mask = ~getStrandScalarReg(strand, maskreg); break;
			break;
	}

	// Perform transfer
	if (op == 7 || op == 8 || op == 9)
	{
		// Block vector access.  Executes in a single cycle
		basePtr = getStrandScalarReg(strand, ptrreg) + offset;
		if (isLoad)
		{
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
				result[lane] = readMemory(strand, basePtr + (15 - lane) * 4);
				
			setVectorReg(strand, destsrcreg, mask, result);
		}
		else
			writeMemBlock(strand, basePtr, mask, strand->vectorReg[destsrcreg]);
	}
	else
	{
		// Multi-cycle vector access.
		if (!strand->multiCycleTransferActive)
		{
			strand->multiCycleTransferActive = 1;
			strand->multiCycleTransferLane = 15;
		}
		else
		{
			strand->multiCycleTransferLane -= 1;
			if (strand->multiCycleTransferLane == 0)
				strand->multiCycleTransferActive = 0;
		}
	
		lane = strand->multiCycleTransferLane;
		if (op == 10 || op == 11 || op == 12)
		{
			// Strided
			basePtr = getStrandScalarReg(strand, ptrreg);
			pointer = basePtr + (15 - lane) * offset;
		}
		else
		{
			// Scatter/gather
			pointer = strand->vectorReg[ptrreg][lane] + offset;
		}

		if (isLoad)
		{
			unsigned int values[16];
			memset(values, 0, 16 * sizeof(unsigned int));
			values[lane] = readMemory(strand, pointer);
			setVectorReg(strand, destsrcreg, mask & (1 << lane), values);
		}
		else if (mask & (1 << lane))
			writeMemWord(strand, pointer, strand->vectorReg[destsrcreg][lane]);
	}

	if (strand->multiCycleTransferActive)
		strand->currentPc -= 4;	// repeat current instruction
}

void executeControlRegister(Strand *strand, unsigned int instr)
{
	int crIndex = bitField(instr, 0, 5);
	int dstSrcReg = bitField(instr, 5, 5);
	if (bitField(instr, 29, 1))
	{
		// Load
		switch (crIndex)
		{
			case 0:
				setScalarReg(strand, dstSrcReg, strand->id);
				break;
			
			case 30:
				setScalarReg(strand, dstSrcReg, strand->core->strandEnableMask);
				break;

			default:
				setScalarReg(strand, dstSrcReg, 0);
		}
	}
	else
	{
		// Store
		switch (crIndex)
		{
			case 29:
				strand->core->strandEnableMask &= ~(1 << strand->id);
				if (strand->core->strandEnableMask == 0)
					doHalt(strand->core);

				break;
		
			case 30:
				strand->core->strandEnableMask = getStrandScalarReg(strand, dstSrcReg);
				if (strand->core->strandEnableMask == 0)
					doHalt(strand->core);
					
				break;
				
			case 31:
				doHalt(strand->core);
				break;
		}
	}
}

void executeCInstruction(Strand *strand, unsigned int instr)
{
	int type = bitField(instr, 25, 4);
	
	if (type == 6)
		executeControlRegister(strand, instr);	
	else if (type < 6)
		executeScalarLoadStore(strand, instr);
	else
		executeVectorLoadStore(strand, instr);
}

void executeEInstruction(Strand *strand, unsigned int instr)
{
	int branchTaken;
	int srcReg = bitField(instr, 0, 5);

	switch (bitField(instr, 25, 3))
	{
		case 0: 
			branchTaken = (getStrandScalarReg(strand, srcReg) & 0xffff) == 0xffff;
			break;
			
		case 1: 
			branchTaken = getStrandScalarReg(strand, srcReg) == 0;
			break;

		case 2:
			branchTaken = getStrandScalarReg(strand, srcReg) != 0;
			break;

		case 3:
			branchTaken = 1;
			break;
			
		case 4:	// call
			branchTaken = 1;
			setScalarReg(strand, LINK_REG, strand->currentPc);
			break;
			
		case 5:
			branchTaken = (getStrandScalarReg(strand, srcReg) & 0xffff) != 0xffff;
			break;
			
		case 6:
			setScalarReg(strand, LINK_REG, strand->currentPc);
			strand->currentPc = getStrandScalarReg(strand, srcReg);
			return; // Short circuit out, since we use register as destination.
	}
	
	if (branchTaken)
		strand->currentPc += signedBitField(instr, 5, 20);
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
int retireInstruction(Strand *strand)
{
	unsigned int instr;

	instr = readMemory(strand, strand->currentPc);
	strand->currentPc += 4;
	strand->core->totalInstructionCount++;

restart:
	if (instr == BREAKPOINT_OP)
	{
		struct Breakpoint *breakpoint = lookupBreakpoint(strand->core, strand->currentPc - 4);
		if (breakpoint == NULL)
		{
			strand->currentPc += 4;
			return 1;	// Naturally occurring invalid instruction
		}
		
		if (breakpoint->restart || strand->core->singleStepping)
		{
			breakpoint->restart = 0;
			instr = breakpoint->originalInstruction;
			assert(instr != BREAKPOINT_OP);
			goto restart;
		}
		else
		{
			// Hit a breakpoint
			printf("* Hit breakpoint\n");
			breakpoint->restart = 1;
			strand->core->currentStrand = strand->id;
			return 0;
		}
	}
	else if (instr == 0)
	{
		// Do nothing.  The hardware explicitly disables writeback for NOPs.
	}
	else if ((instr & 0xe0000000) == 0xc0000000)
		executeAInstruction(strand, instr);
	else if ((instr & 0x80000000) == 0)
		executeBInstruction(strand, instr);
	else if ((instr & 0xc0000000) == 0x80000000)
		executeCInstruction(strand, instr);
	else if ((instr & 0xf0000000) == 0xe0000000)
		;	// Format D instruction.  Ignore
	else if ((instr & 0xf0000000) == 0xf0000000)
		executeEInstruction(strand, instr);
	else
		printf("* Unknown instruction\n");

	return 1;
}
