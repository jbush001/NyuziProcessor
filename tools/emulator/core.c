#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <math.h>
#include <assert.h>
#include "core.h"

#define PC_REG 31

// This is used to signal an instruction that may be a breakpoint.  We use
// a special instruction to avoid a breakpoint lookup on every instruction cycle.
// This is an invalid instruction because it uses a reserved access type.
#define BREAKPOINT_OP 0xefffffff

#define bitField(word, lowBitOffset, size) \
	((word >> lowBitOffset) & ((1 << size) - 1))

struct Core
{
	unsigned int *memory;
	unsigned int currentPc;
	unsigned int memorySize;
	unsigned int scalarReg[NUM_REGISTERS - 1];	// 31 is PC, which is special
	unsigned int vectorReg[NUM_REGISTERS][NUM_VECTOR_LANES];
	struct Breakpoint *breakpoints;
	int singleStepping;
};

struct Breakpoint
{
	struct Breakpoint *next;
	unsigned int address;
	unsigned int originalInstruction;
	unsigned int restart;
};

int executeInstruction(Core *core);

Core *initCore()
{
	Core *core = (Core*) calloc(sizeof(Core), 1);
	core->memorySize = 0x100000;
	core->memory = (unsigned int*) malloc(core->memorySize);

	return core;
}

unsigned int swap(unsigned int value)
{
	return ((value & 0x000000ff) << 24)
		| ((value & 0x0000ff00) << 8)
		| ((value & 0x00ff0000) >> 8)
		| ((value & 0xff000000) >> 24);
}

int loadImage(Core *core, const char *filename)
{
	FILE *file;
	char line[64];
	unsigned int *memptr = core->memory;

	file = fopen(filename, "r");
	if (file == NULL)
	{
		perror("Error opening file");
		return -1;
	}

	while (fgets(line, sizeof(line), file))
		*memptr++ = swap(strtoul(line, NULL, 16));
	
	fclose(file);

	return 0;
}

unsigned int getPc(Core *core)
{
	return core->currentPc;
}

int getScalarRegister(Core *core, int index)
{
	if (index == PC_REG)
		return core->currentPc + 4;
	else
		return core->scalarReg[index];
}

int getVectorRegister(Core *core, int index, int lane)
{
	return core->vectorReg[index][lane];
}

int runQuantum(Core *core)
{
	int i;
	
	core->singleStepping = 0;
	for (i = 0; i < 1000; i++)
	{
		if (!executeInstruction(core))
			return 0;	// Hit breakpoint
	}

	return 1;
}

void stepInto(Core *core)
{
	core->singleStepping = 1;
	executeInstruction(core);
}

void stepOver(Core *core)
{
	core->singleStepping = 1;
	executeInstruction(core);
}

void stepReturn(Core *core)
{
	core->singleStepping = 1;
	executeInstruction(core);
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
		case 2: return value1 & ~value2;
		case 3: return value1 ^ value2;
		case 4: return ~value2;
		case 5: return value1 + value2;
		case 6: return value1 - value2;
		case 7: return value1 * value2;
		case 8: return value1 / value2;
		case 9: return ((int)value1) >> value2;
		case 10: return value1 >> value2;
		case 11: return value1 << value2;
		case 12: return clz(value2);
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
		case 32: return valueAsInt(valueAsFloat(value1) + valueAsFloat(value2));
		case 33: return valueAsInt(valueAsFloat(value1) - valueAsFloat(value2));
		case 34: return valueAsInt(valueAsFloat(value1) * valueAsFloat(value2));
		case 35: return valueAsInt(valueAsFloat(value1) / valueAsFloat(value2));
		case 38: return valueAsInt(floor(valueAsFloat(value2)));
		case 39: return valueAsInt(frac(valueAsFloat(value2)));
		case 40: return valueAsInt(1.0 / valueAsFloat(value2));
		case 42: return (int) ((float) value1 * valueAsFloat(value2));	// sitof
		case 44: return valueAsFloat(value1) > valueAsFloat(value2);
		case 45: return valueAsFloat(value1) >= valueAsFloat(value2);
		case 46: return valueAsFloat(value1) < valueAsFloat(value2);
		case 47: return valueAsFloat(value1) <= valueAsFloat(value2);
		case 48: return (int) (valueAsFloat(value1) * valueAsFloat(value1)); // sftoi
		default: return 0;
	}
}

inline int isCompareOp(int op)
{
	return (op >= 16 && op <= 26) || (op >= 44 && op <= 47);
}

void executeAInstruction(Core *core, unsigned int instr)
{
	// A operation
	int fmt = bitField(instr, 20, 3);
	int op = bitField(instr, 23, 6);
	int op1reg = bitField(instr, 0, 5);
	int op2reg = bitField(instr, 15, 5);
	int destreg = bitField(instr, 5, 5);
	int maskreg = bitField(instr, 10, 5);
	int mask;
	int lane;

	if (fmt == 0)
	{
		int result = doOp(op, getScalarRegister(core, op1reg),
			getScalarRegister(core, op2reg));
		if (destreg == PC_REG)
			core->currentPc = result - 4;	// HACK: subtract 4 so the increment won't corrupt
		else
			core->scalarReg[destreg] = result;
	}
	else
	{
		switch (fmt)
		{
			case 1: 
			case 4:
				mask = 0xffff; 
				break;
				
			case 2:
			case 5:
				mask = getScalarRegister(core, maskreg); 
				break;
				
			case 3:
			case 6:
				mask = ~getScalarRegister(core, maskreg); 
				break;
		}
	
		if (isCompareOp(op))
		{
			int result = 0;
			
			// Vector compares work a little differently than other arithmetic
			// operations: the results are packed together in the 16 low
			// bits of a scalar register
			 if (fmt < 4)
			 {
				// Vector/Scalar operation
				int scalarValue = getScalarRegister(core, op2reg);
				for (lane = 0; lane < 16; lane++, mask >>= 1, result >>= 1)
				{
					if (mask & 1)
					{
						result |= doOp(op, core->vectorReg[op1reg][lane],
							scalarValue) ? 0x8000 : 0;
					}
				}
			}
			else
			{
				// Vector/Vector operation
				for (lane = 0; lane < 16; lane++, mask >>= 1, result >>= 1)
				{
					if (mask & 1)
					{
						result |= doOp(op, core->vectorReg[op1reg][lane],
							core->vectorReg[op2reg][lane]) ? 0x8000 : 0;
					}
				}
			}		
			
			// XXX need to check for PC destination
			core->scalarReg[destreg] = result;
		}
		else
		{
			// Vector arithmetic...
			if (fmt < 4)
			{
				// Vector/Scalar operation
				int scalarValue = getScalarRegister(core, op2reg);
				for (lane = 0; lane < 16; lane++, mask >>= 1)
				{
					if (mask & 1)
					{
						core->vectorReg[destreg][lane] =
							doOp(op, core->vectorReg[op1reg][lane],
							scalarValue);
					}
				}
			}
			else
			{
				// Vector/Vector operation
				for (lane = 0; lane < 16; lane++, mask >>= 1)
				{
					if (mask & 1)
					{
						core->vectorReg[destreg][lane] =
							doOp(op, core->vectorReg[op1reg][lane],
							core->vectorReg[op2reg][lane]);
					}
				}
			}
		}
	}
}

void executeBInstruction(Core *core, unsigned int instr)
{
	int fmt = bitField(instr, 24, 2);
	int immValue = bitField(instr, 15, 9);
	int op = bitField(instr, 26, 5);
	int op1reg = bitField(instr, 0, 5);
	int maskreg = bitField(instr, 10, 5);
	int destreg = bitField(instr, 5, 5);
	
	if (immValue & (1 << 9))
		immValue |= 0xfffffe00;	// Sign extend
	
	if (fmt == 0)
	{
		int result = doOp(op, getScalarRegister(core, op1reg),
			immValue);
		if (destreg == PC_REG)
			core->currentPc = result - 4; // HACK: add 4 so increment won't corrupt
		else
			core->scalarReg[destreg] = result;
	}
	else
	{
		int mask;
		int lane;
		
		switch (fmt)
		{
			case 1: mask = 0xffff; break;
			case 2: mask = getScalarRegister(core, maskreg); break;
			case 3: mask = ~getScalarRegister(core, maskreg); break;
		}

		if (isCompareOp(op))
		{
			// Vector compares work a little differently than other arithmetic
			// operations: the results are packed together in the 16 low
			// bits of a scalar register
			int result = 0;

			for (lane = 0; lane < 16; lane++, mask >>= 1, result >>= 1)
			{
				if (mask & 1)
				{
					result |= doOp(op, core->vectorReg[op1reg][lane],
						immValue) ? 0x8000 : 0;
				}
			}
			
			// XXX check for PC dest (which doesn't make sense here)
			core->scalarReg[destreg] = result;
		}
		else
		{
			for (lane = 0; lane < 16; lane++, mask >>= 1)
			{
				if (mask & 1)
				{
					core->vectorReg[destreg][lane] =
						doOp(op, core->vectorReg[op1reg][lane],
						immValue);
				}
			}
		}
	}
}

void executeScalarLoadStore(Core *core, unsigned int instr)
{
	int op = bitField(instr, 25, 4);
	int ptrreg = bitField(instr, 0, 5);
	int offset = bitField(instr, 15, 10);
	int destsrcreg = bitField(instr, 5, 5);
	int isLoad = bitField(instr, 29, 1);
	unsigned int ptr;

	if (offset & (1 << 10))
		offset |= 0xfffffc00;	// Sign extend

	ptr = getScalarRegister(core, ptrreg) + offset;
	if (ptr >= core->memorySize)
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
				value = ((unsigned char*) core->memory)[ptr]; 
				break;
				
			case 1: 	// Byte, sign extend
				value = ((char*) core->memory)[ptr]; 
				break;
				
			case 2: 	// Short
				value = ((unsigned short*) core->memory)[ptr / 2]; 
				break;

			case 3: 	// Short, sign extend
				value = ((short*) core->memory)[ptr / 2]; 
				break;

			case 4:	// Load word
			case 5:	// Load linked
				value = core->memory[ptr / 4]; 
				break;
				
			case 6:	// Load control register
				value = 0;
				break;
		}
		
		if (destsrcreg == PC_REG)
			core->currentPc = value - 4;		// HACK subtract 4 so PC increment won't break
		else
			core->scalarReg[destsrcreg] = value;
	}
	else
	{
		// Store
		// Shift and mask in the value.
		int valueToStore = getScalarRegister(core, destsrcreg);
	
		switch (op)
		{
			case 0:
			case 1:
				((unsigned char*)core->memory)[ptr] = valueToStore & 0xff;
				break;
				
			case 2:
			case 3:
				((unsigned short*)core->memory)[ptr / 2] = valueToStore & 0xffff;
				break;
				
			case 4:
			case 5:
				core->memory[ptr / 4] = valueToStore;
				break;
				
			case 6:	// Store control register
				break;
		}
	}
}

void executeVectorLoadStore(Core *core, unsigned int instr)
{
	int op = bitField(instr, 25, 4);
	int ptrreg = bitField(instr, 0, 5);
	int offset = bitField(instr, 15, 10);
	int maskreg = bitField(instr, 10, 5);
	int destsrcreg = bitField(instr, 5, 5);
	int lane;
	int mask;
	unsigned int ptr[NUM_VECTOR_LANES];
	unsigned int basePtr;
	int isLoad = bitField(instr, 29, 1);

	if (offset & (1 << 10))
		offset |= 0xfffffc00;	// Sign extend

	// Compute pointers for lanes. Note that the pointers will be indices
	// into the memory array (which is an array of ints).
	switch (op)
	{
		case 7:
		case 8:
		case 9: // Block vector access
			basePtr = (getScalarRegister(core, ptrreg) + offset) / 4;
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
				ptr[lane] = basePtr + lane;
				
			break;

		case 10:
		case 11:
		case 12: // Strided vector access
			basePtr = getScalarRegister(core, ptrreg) / 4;
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
				ptr[lane] = basePtr + lane * offset / 4;	// offset in this case is word multiples
				
			break;

		case 13:
		case 14:
		case 15: // Scatter/gather load/store
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
				ptr[lane] = (core->vectorReg[ptrreg][lane] + offset) / 4;
			
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
			mask = getScalarRegister(core, maskreg); break;
			break;
			
		case 9:
		case 12:
		case 15:	// Invert Mask
			mask = ~getScalarRegister(core, maskreg); break;
			break;
	}

	// Do the actual memory transfers
	if (isLoad)
	{
		// Load
		for (lane = 0; lane < NUM_VECTOR_LANES; lane++, mask >>= 1)
		{
			if (mask & 1)
				core->vectorReg[destsrcreg][lane] = core->memory[ptr[lane]];
		}
	}
	else
	{
		// Store
		for (lane = 0; lane < NUM_VECTOR_LANES; lane++, mask >>= 1)
		{
			if (mask & 1)
				core->memory[ptr[lane]] = core->vectorReg[destsrcreg][lane];
		}
	}
	
}

void executeCInstruction(Core *core, unsigned int instr)
{
	if (bitField(instr, 25, 4) <= 6)
		executeScalarLoadStore(core, instr);
	else
		executeVectorLoadStore(core, instr);
}

void executeEInstruction(Core *core, unsigned int instr)
{
	int branchTaken;
	int srcReg = bitField(instr, 0, 5);

	switch (bitField(instr, 25, 3))
	{
		case 0: 
			branchTaken = (getScalarRegister(core, srcReg) & 0xffff) == 0xffff;
			break;
			
		case 1: 
			branchTaken = (getScalarRegister(core, srcReg) & 0xffff) == 0;
			break;

		case 2:
			branchTaken = (getScalarRegister(core, srcReg) & 0xffff) != 0;
			break;

		case 3:
			branchTaken = 1;
			break;
			
		case 4:	// call
			branchTaken = 1;
			core->scalarReg[30] = core->currentPc + 4;
			break;
	}
	
	if (branchTaken)
	{
		int offset = bitField(instr, 5, 21);
		if (offset & (1 << 20))
			offset |= 0xffe00000;
			
		// The math here is a bit subtle.  A branch offset is normally from
		// the next instruction, but currentPC is still pointing to the branch
		// instruction.  However, in executeInstruction, 4 will be added to the
		// program counter after this.  That will effectively point to the 
		// correct target address.
		core->currentPc += offset;
	}
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
int executeInstruction(Core *core)
{
	unsigned int instr;

	if (core->currentPc >= core->memorySize)
	{
		printf("* invalid access %08x\n", core->currentPc);
		return 0;	// Invalid address
	}

	instr = core->memory[core->currentPc / 4];

restart:
	if (instr == BREAKPOINT_OP)
	{
		struct Breakpoint *breakpoint = lookupBreakpoint(core, core->currentPc);
		if (breakpoint == NULL)
		{
			core->currentPc += 4;
			return 1;	// Naturally occurring invalid instruction
		}
		
		if (breakpoint->restart || core->singleStepping)
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
	else if ((instr & 0xe0000000) == 0xc0000000)
		executeAInstruction(core, instr);
	else if ((instr & 0x80000000) == 0)
		executeBInstruction(core, instr);
	else if ((instr & 0xc0000000) == 0x80000000)
		executeCInstruction(core, instr);
	else if ((instr & 0xf0000000) == 0xf0000000)
		executeEInstruction(core, instr);
	else
		printf("* Unknown instruction\n");

	core->currentPc += 4;
	return 1;
}
