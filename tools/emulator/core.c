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

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <math.h>
#include <assert.h>
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
	unsigned int currentPc;
	unsigned int scalarReg[NUM_REGISTERS - 1];	// 31 is PC, which is special
	unsigned int vectorReg[NUM_REGISTERS][NUM_VECTOR_LANES];
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
};

struct Breakpoint
{
	struct Breakpoint *next;
	unsigned int address;
	unsigned int originalInstruction;
	unsigned int restart;
};

int executeInstruction(Strand *strand);

Core *initCore()
{
	int i;
	Core *core;

	core = (Core*) calloc(sizeof(Core), 1);
	core->memorySize = 0x100000;
	core->memory = (unsigned int*) malloc(core->memorySize);
	for (i = 0; i < 4; i++)
	{
		core->strands[i].core = core;
		core->strands[i].id = i;
	}
	
	core->strandEnableMask = 1;
	core->halt = 0;
	core->enableTracing = 0;

	return core;
}

void enableTracing(Core *core)
{
	core->enableTracing = 1;
}

inline int bitField(unsigned int word, int lowBitOffset, int size)
{
	return (word >> lowBitOffset) & ((1 << size) - 1);
}

inline int signedBitField(unsigned int word, int lowBitOffset, int size)
{
	unsigned int mask = (1 << size) - 1;
	int value = (word >> lowBitOffset) & mask;
	if (value & (1 << (size - 1)))
		value |= ~mask;	// Sign extend

	return value;
}

inline unsigned int swap(unsigned int value)
{
	return ((value & 0x000000ff) << 24)
		| ((value & 0x0000ff00) << 8)
		| ((value & 0x00ff0000) >> 8)
		| ((value & 0xff000000) >> 24);
}

inline int getStrandScalarReg(Strand *strand, int reg)
{
	if (reg == PC_REG)
		return strand->currentPc;
	else
		return strand->scalarReg[reg];
}

inline void setScalarReg(Strand *strand, int reg, int value)
{
	if (strand->core->enableTracing)
		printf("%08x [st %d] s%d <= %08x\n", strand->currentPc - 4, strand->id, reg, value);

	if (reg == PC_REG)
		strand->currentPc = value;
	else
		strand->scalarReg[reg] = value;
}

inline void setVectorReg(Strand *strand, int reg, int mask, int value[NUM_VECTOR_LANES])
{
	int lane;

	if (strand->core->enableTracing)
	{
		printf("%08x [st %d] v%d{%04x} <= ", strand->currentPc - 4, strand->id, reg, 
			mask & 0xffff);
		for (lane = NUM_VECTOR_LANES - 1; lane >= 0; lane--)
			printf("%08x", value[lane]);
			
		printf("\n");
	}

	for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
	{
		if (mask & (1 << lane))
			strand->vectorReg[reg][lane] = value[lane];
	}
}

inline void writeMemory(Strand *strand, unsigned int address, int value)
{
	// XXX bounds check
	strand->core->memory[address / 4] = value;
//	printf("%08x write %08x %08x\n", strand->currentPc - 4, address, value);
}

inline unsigned int readMemory(Strand *strand, unsigned int address)
{
	// XXX bounds check
//	printf("%08x read %08x = %08x\n", strand->currentPc - 4, address, strand->core->memory[address / 4]);
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
		*memptr++ = swap(strtoul(line, NULL, 16));
	
	fclose(file);

	return 0;
}

void dumpMemory(Core *core, const char *filename, unsigned int baseAddress, 
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

int getScalarRegister(Core *core, int index)
{
	return getStrandScalarReg(&core->strands[core->currentStrand], index);
}

int getVectorRegister(Core *core, int index, int lane)
{
	return core->strands[core->currentStrand].vectorReg[index][lane];
}

int runQuantum(Core *core)
{
	int i;
	int strand;
	
	core->singleStepping = 0;
	for (i = 0; i < 1000; i++)
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
				if (!executeInstruction(&core->strands[strand]))
					return 0;	// Hit breakpoint
			}
		}
	}

	return 1;
}

void stepInto(Core *core)
{
	core->singleStepping = 1;
	executeInstruction(&core->strands[core->currentStrand]);	// XXX
}

void stepOver(Core *core)
{
	core->singleStepping = 1;
	executeInstruction(&core->strands[core->currentStrand]);
}

void stepReturn(Core *core)
{
	core->singleStepping = 1;
	executeInstruction(&core->strands[core->currentStrand]);
}

int readMemoryByte(Core *core, unsigned int addr)
{
	return ((unsigned char*) core->memory)[addr];
}

int clz(int value)
{
	int i;
	
	for (i = 0; i < 32; i++)
	{
		if (value & 0x80000000)
			return i;
			
		value <<= 1;
	}
	
	return 32;
}

int ctz(int value)
{
	int i;
	
	for (i = 0; i < 32; i++)
	{
		if (value & 1)
			return i;
			
		value >>= 1;
	}
	
	return 32;
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
		case 4: return ~value2;
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
		case 12: return clz(value2);
		case 14: return ctz(value2);
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
		case 32: return valueAsInt(valueAsFloat(value1) + valueAsFloat(value2));
		case 33: return valueAsInt(valueAsFloat(value1) - valueAsFloat(value2));
		case 34: return valueAsInt(valueAsFloat(value1) * valueAsFloat(value2));
		case 35: return valueAsInt(valueAsFloat(value1) / valueAsFloat(value2));
		case 38: return valueAsInt(floor(valueAsFloat(value2)));
		case 39: return valueAsInt(frac(valueAsFloat(value2)));
		case 40: return valueAsInt(1.0 / valueAsFloat(value2));
		case 42: return valueAsInt((float)((int)value2)); // itof
		case 44: return valueAsFloat(value1) > valueAsFloat(value2);
		case 45: return valueAsFloat(value1) >= valueAsFloat(value2);
		case 46: return valueAsFloat(value1) < valueAsFloat(value2);
		case 47: return valueAsFloat(value1) <= valueAsFloat(value2);
		default: return 0;
	}
}

inline int isCompareOp(int op)
{
	return (op >= 16 && op <= 26) || (op >= 44 && op <= 47);
}

void executeAInstruction(Strand *strand, unsigned int instr)
{
	// A operation
	int fmt = bitField(instr, 20, 3);
	int op = bitField(instr, 23, 6);
	int op1reg = bitField(instr, 0, 5);
	int op2reg = bitField(instr, 15, 5);
	int destreg = bitField(instr, 5, 5);
	int maskreg = bitField(instr, 10, 5);
	int lane;

	if (op == 26)
	{
		// getlane		
		setScalarReg(strand, destreg, strand->vectorReg[op1reg][getStrandScalarReg(
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
				result[lane] = src1[src2[lane] & 0xf];
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
	int fmt = bitField(instr, 23, 3);
	int immValue;
	int op = bitField(instr, 26, 5);
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
		setScalarReg(strand, destreg, strand->vectorReg[op1reg][immValue & 0xf]);
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
	int offset = signedBitField(instr, 15, 10);
	int destsrcreg = bitField(instr, 5, 5);
	int isLoad = bitField(instr, 29, 1);
	unsigned int ptr;

	ptr = getStrandScalarReg(strand, ptrreg) + offset;
	if (ptr >= strand->core->memorySize)
	{
		printf("* Access Violation %08x\n", ptr);
		return;
	}
	
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
				value = ((unsigned short*) strand->core->memory)[ptr / 2]; 
				break;

			case 3: 	// Short, sign extend
				value = ((short*) strand->core->memory)[ptr / 2]; 
				break;

			case 4:	// Load word
			case 5:	// Load linked
				value = readMemory(strand, ptr); 
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
				((unsigned char*)strand->core->memory)[ptr] = valueToStore & 0xff;
				break;
				
			case 2:
			case 3:
				((unsigned short*)strand->core->memory)[ptr / 2] = valueToStore & 0xffff;
				break;
				
			case 4:
			case 5:
				writeMemory(strand, ptr, valueToStore);
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
	int offset;
	int maskreg = bitField(instr, 10, 5);
	int destsrcreg = bitField(instr, 5, 5);
	int lane;
	int mask;
	unsigned int ptr[NUM_VECTOR_LANES];
	unsigned int basePtr;
	int isLoad = bitField(instr, 29, 1);

	// Compute pointers for lanes. Note that the pointers will be indices
	// into the memory array (which is an array of ints).
	switch (op)
	{
		case 7:
		case 8:
		case 9: // Block vector access
			offset = signedBitField(instr, 15, 10);
			basePtr = getStrandScalarReg(strand, ptrreg) + offset;
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
				ptr[lane] = basePtr + (15 - lane) * 4;
				
			break;

		case 10:
		case 11:
		case 12: // Strided vector access
			offset = bitField(instr, 15, 10);	// Note: unsigned
			basePtr = getStrandScalarReg(strand, ptrreg);
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
				ptr[lane] = basePtr + (15 - lane) * offset;	
				
			break;

		case 13:
		case 14:
		case 15: // Scatter/gather load/store
			offset = signedBitField(instr, 15, 10);
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
				ptr[lane] = strand->vectorReg[ptrreg][lane] + offset;
			
			break;
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

	// Do the actual memory transfers
	if (isLoad)
	{
		// Load
		if (op == 7 || op == 8 || op == 9)
		{		
			// Block transfers execute in a single cycle
			int result[NUM_VECTOR_LANES];
			
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
				result[lane] = readMemory(strand, ptr[lane]);
	
			setVectorReg(strand, destsrcreg, mask, result);
		}
		else
		{
			// Strided and gather take one cycle per lane
			// Need to emulate this to match output from simulation
			int result[NUM_VECTOR_LANES];
			int i;
			
			for (lane = NUM_VECTOR_LANES - 1; lane >= 0; lane--)
			{
				unsigned int memory_value = readMemory(strand, ptr[lane]);
				for (i = 0; i < NUM_VECTOR_LANES; i++)
					result[i] = memory_value;

				setVectorReg(strand, destsrcreg, mask & (1 << lane), result);
			}
		}
	}
	else
	{
		// Store. Write in proper order because it is possible for a scatter 
		// store to have multiple lanes write to the same address.
		for (lane = NUM_VECTOR_LANES - 1; lane >= 0; lane--)
		{
			if (mask & (1 << lane))
				writeMemory(strand, ptr[lane], strand->vectorReg[destsrcreg][lane]);
		}
	}
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
			case 30:
				strand->core->strandEnableMask = getStrandScalarReg(strand, dstSrcReg);
				break;
				
			case 31:
				strand->core->halt = 1;
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

// XXX should probably have a switch statement for more efficient op type
// lookup.
int executeInstruction(Strand *strand)
{
	unsigned int instr;

	if (strand->currentPc >= strand->core->memorySize)
	{
		printf("* invalid instruction address %08x, strand %d\n", strand->currentPc,
			strand->id);
		return 0;	// Invalid address
	}
	
	instr = readMemory(strand, strand->currentPc);

	strand->currentPc += 4;


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
