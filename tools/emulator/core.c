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

#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include "core.h"
#include "device.h"
#include "stats.h"
#include "cosimulation.h"
#include "util.h"

#define LINK_REG 30
#define PC_REG 31
#define INVALID_LINK_ADDR 0xffffffff

// This is used to signal an instruction that may be a breakpoint.  We use
// a special instruction to avoid a breakpoint lookup on every instruction cycle.
// This is an invalid instruction because it uses a reserved format type
#define BREAKPOINT_OP 0x707fffff

typedef struct Thread Thread;

typedef enum {
	CR_THREAD_ID = 0,
	CR_FAULT_HANDLER = 1,
	CR_FAULT_PC = 2,
	CR_FAULT_REASON = 3,
	CR_INTERRUPT_ENABLE = 4,
	CR_FAULT_ADDRESS = 5,
	CR_CYCLE_COUNT = 6,
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
	uint32_t linkedAddress;		// Cache line (/ 64)
	uint32_t currentPc;
	uint32_t scalarReg[NUM_REGISTERS - 1];	// 31 is PC, which is special
	uint32_t vectorReg[NUM_REGISTERS][NUM_VECTOR_LANES];
	int multiCycleTransferActive;
	int multiCycleTransferLane;
	FaultReason lastFaultReason;
	uint32_t lastFaultPc;
	uint32_t lastFaultAddress;
	int interruptEnable;
};

struct Core
{
	uint32_t *memory;
	size_t memorySize;
	int totalThreads;
	Thread *threads;
	struct Breakpoint *breakpoints;
	int singleStepping;
	uint32_t threadEnableMask;
	int halt;
	int stopOnFault;
	int enableTracing;
	int cosimEnable;
	uint32_t faultHandlerPc;
};

struct Breakpoint
{
	struct Breakpoint *next;
	uint32_t address;
	uint32_t originalInstruction;
	int restart;
};

static void doHalt(Core *core);
static uint32_t getThreadScalarReg(const Thread *thread, int reg);
static void setScalarReg(Thread *thread, int reg, uint32_t value);
static void setVectorReg(Thread *thread, int reg, int mask, 
	uint32_t values[NUM_VECTOR_LANES]);
static void invalidateSyncAddress(Core *core, uint32_t address);
static void memoryAccessFault(Thread *thread, uint32_t address, int isLoad);
static void illegalInstruction(Thread *thread, uint32_t instr);
static void writeMemBlock(Thread *thread, uint32_t address, int mask, 
	const uint32_t values[NUM_VECTOR_LANES]);
static void writeMemWord(Thread *thread, uint32_t address, uint32_t value);
static void writeMemShort(Thread *thread, uint32_t address, uint32_t value);
static void writeMemByte(Thread *thread, uint32_t address, uint32_t value);
static uint32_t readMemoryWord(const Thread *thread, uint32_t address);
static uint32_t doOp(int operation, uint32_t value1, uint32_t value2);
static int isCompareOp(int op);
static struct Breakpoint *lookupBreakpoint(Core *core, uint32_t pc);
static void executeRegisterArith(Thread *thread, uint32_t instr);
static void executeImmediateArith(Thread *thread, uint32_t instr);
static void executeScalarLoadStore(Thread *thread, uint32_t instr);
static void executeVectorLoadStore(Thread *thread, uint32_t instr);
static void executeControlRegister(Thread *thread, uint32_t instr);
static void executeMemoryAccess(Thread *thread, uint32_t instr);
static void executeBranch(Thread *thread, uint32_t instr);
static int retireInstruction(Thread *thread);

Core *initCore(size_t memorySize, int totalThreads, int randomizeMemory)
{
	uint32_t address;
	int threadid;
	Core *core;

	// Currently limited by enable mask
	assert(totalThreads <= 32);

	core = (Core*) calloc(sizeof(Core), 1);
	core->memorySize = memorySize;
	core->memory = (uint32_t*) malloc(memorySize);
	if (randomizeMemory)
	{
		srand(time(NULL));
		for (address = 0; address < memorySize / 4; address++)
			core->memory[address] = rand();
	}
	else
		memset(core->memory, 0, core->memorySize);

	core->totalThreads = totalThreads;
	core->threads = (Thread*) calloc(sizeof(Thread), totalThreads);
	for (threadid = 0; threadid < totalThreads; threadid++)
	{
		core->threads[threadid].core = core;
		core->threads[threadid].id = threadid;
		core->threads[threadid].lastFaultReason = FR_RESET;
		core->threads[threadid].linkedAddress = INVALID_LINK_ADDR;
	}

	// XXX this is currently different than hardware, where the main
	// thread on each core starts automatically
	core->threadEnableMask = 1;
	core->halt = 0;
	core->enableTracing = 0;
	core->faultHandlerPc = 0;

	return core;
}

void enableTracing(Core *core)
{
	core->enableTracing = 1;
}

int loadHexFile(Core *core, const char *filename)
{
	FILE *file;
	char line[16];
	uint32_t *memptr = core->memory;

	file = fopen(filename, "r");
	if (file == NULL)
	{
		perror("Error opening hex memory file");
		return -1;
	}

	while (fgets(line, sizeof(line), file))
	{
		*memptr++ = endianSwap32(strtoul(line, NULL, 16));
		if ((size_t)((memptr - core->memory) * 4) >= core->memorySize)
		{
			fprintf(stderr, "code was too bit to fit in memory\n");
			return -1;
		}
	}
	
	fclose(file);

	return 0;
}

void writeMemoryToFile(const Core *core, const char *filename, uint32_t baseAddress, 
	size_t length)
{
	FILE *file;

	file = fopen(filename, "wb+");
	if (file == NULL)
	{
		perror("Error opening memory dump file");
		return;
	}

	if (fwrite((int8_t*) core->memory + baseAddress, MIN(core->memorySize, length), 1, file) <= 0)
	{
		perror("Error writing memory dump");
		return;
	}
	
	fclose(file);
}

void *getCoreFb(Core *core)
{
	return ((uint8_t*) core->memory) + 0x200000;
}

void printRegisters(const Core *core, int threadId)
{
	int reg;
	int lane;
	const Thread *thread = &core->threads[threadId];
	
	printf("REGISTERS\n");
	for (reg = 0; reg < 31; reg++)
	{
		if (reg < 10)
			printf(" ");
			
		printf("s%d %08x ", reg, thread->scalarReg[reg]);
		if (reg % 8 == 7)
			printf("\n");
	}

	printf("s31 %08x\n\n", thread->currentPc - 4);
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

void enableCosim(Core *core, int enable)
{
	core->cosimEnable = enable;
}

void cosimInterrupt(Core *core, int threadId, uint32_t pc)
{
	Thread *thread = &core->threads[threadId];

	thread->lastFaultPc = pc;
	thread->currentPc = thread->core->faultHandlerPc;
	thread->lastFaultReason = FR_INTERRUPT;
	thread->interruptEnable = 0;
	thread->multiCycleTransferActive = 0;
}

int getTotalThreads(const Core *core)
{
	return core->totalThreads;
}

int coreHalted(const Core *core)
{
	return core->threadEnableMask == 0;
}

int executeInstructions(Core *core, int threadId, int instructions)
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
			for (thread = 0; thread < core->totalThreads; thread++)
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

uint32_t getPc(const Core *core, int threadId)
{
	return core->threads[threadId].currentPc;
}

uint32_t getScalarRegister(const Core *core, int threadId, int index)
{
	return getThreadScalarReg(&core->threads[threadId], index);
}

uint32_t getVectorRegister(const Core *core, int threadId, int index, int lane)
{
	return core->threads[threadId].vectorReg[index][lane];
}

uint32_t readMemoryByte(const Core *core, uint32_t address)
{
	if (address >= core->memorySize)
		return 0xffffffff;
	
	return ((uint8_t*) core->memory)[address];
}

void setBreakpoint(Core *core, uint32_t pc)
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
		breakpoint->originalInstruction = 0;	// Avoid infinite loop
	
	core->memory[pc / 4] = BREAKPOINT_OP;
}

void clearBreakpoint(Core *core, uint32_t pc)
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

void forEachBreakpoint(const Core *core, void (*callback)(uint32_t pc))
{
	const struct Breakpoint *breakpoint;

	for (breakpoint = core->breakpoints; breakpoint; breakpoint = breakpoint->next)
		callback(breakpoint->address);
}

void setStopOnFault(Core *core, int stopOnFault)
{
	core->stopOnFault = stopOnFault;
}

static void doHalt(Core *core)
{
	core->halt = 1;
}

static uint32_t getThreadScalarReg(const Thread *thread, int reg)
{
	if (reg == PC_REG)
		return thread->currentPc;
	else
		return thread->scalarReg[reg];
}

static void setScalarReg(Thread *thread, int reg, uint32_t value)
{
	if (thread->core->enableTracing)
		printf("%08x [at %d] s%d <= %08x\n", thread->currentPc - 4, thread->id, reg, value);

	if (thread->core->cosimEnable)
		cosimSetScalarReg(thread->core, thread->currentPc - 4, reg, value);

	if (reg == PC_REG)
		thread->currentPc = value;
	else
		thread->scalarReg[reg] = value;
}

static void setVectorReg(Thread *thread, int reg, int mask, uint32_t values[NUM_VECTOR_LANES])
{
	int lane;

	if (thread->core->enableTracing)
	{
		printf("%08x [st %d] v%d{%04x} <= ", thread->currentPc - 4, thread->id, reg, 
			mask & 0xffff);
		for (lane = 15; lane >= 0; lane--)
			printf("%08x ", values[lane]);

		printf("\n");
	}

	if (thread->core->cosimEnable)
		cosimSetVectorReg(thread->core, thread->currentPc - 4, reg, mask, values);

	for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
	{
		if (mask & (1 << lane))
			thread->vectorReg[reg][lane] = values[lane];
	}
}

static void invalidateSyncAddress(Core *core, uint32_t address)
{
	int threadId;
	
	for (threadId = 0; threadId < core->totalThreads; threadId++)
	{
		if (core->threads[threadId].linkedAddress == address / 64)
		{
			// Invalidate
			core->threads[threadId].linkedAddress = INVALID_LINK_ADDR;
		}
	}
}

static void memoryAccessFault(Thread *thread, uint32_t address, int isLoad)
{
	if (thread->core->stopOnFault)
	{
		printf("Invalid %s access thread %d PC %08x address %08x\n",
			isLoad ? "load" : "store",
			thread->id, thread->currentPc - 4, address);
		printRegisters(thread->core, thread->id);
		thread->core->halt = 1;
	}
	else
	{
		// Allow core to dispatch
		thread->lastFaultPc = thread->currentPc - 4;
		thread->currentPc = thread->core->faultHandlerPc;
		thread->lastFaultReason = FR_INVALID_ACCESS;
		thread->interruptEnable = 0;
		thread->lastFaultAddress = address;
	}
}

static void illegalInstruction(Thread *thread, uint32_t instr)
{
	if (thread->core->stopOnFault)
	{
		printf("Illegal instruction %08x thread %d PC %08x\n", instr, thread->id, thread->currentPc 
			- 4);
		printRegisters(thread->core, thread->id);
		thread->core->halt = 1;
	}
	else
	{
		// Allow core to dispatch
		thread->lastFaultPc = thread->currentPc - 4;
		thread->currentPc = thread->core->faultHandlerPc;
		thread->lastFaultReason = FR_ILLEGAL_INSTRUCTION;
		thread->interruptEnable = 0;
	}
}

static void writeMemBlock(Thread *thread, uint32_t address, int mask, 
	const uint32_t values[NUM_VECTOR_LANES])
{
	int lane;

	if ((mask & 0xffff) == 0)
		return;	// Hardware ignores block stores with a mask of zero

	if (thread->core->enableTracing)
	{
		printf("%08x [st %d] writeMemBlock %08x\n", thread->currentPc - 4, thread->id,
			address);
	}
	
	if (thread->core->cosimEnable)
		cosimWriteBlock(thread->core, thread->currentPc - 4, address, mask, values);
	
	for (lane = 15; lane >= 0; lane--)
	{
		if (mask & (1 << lane))
			thread->core->memory[(address / 4) + (15 - lane)] = values[lane];
	}

	invalidateSyncAddress(thread->core, address);
}

static void writeMemWord(Thread *thread, uint32_t address, uint32_t value)
{
	if ((address & 0xFFFF0000) == 0xFFFF0000)
	{
		// IO address range
		writeDeviceRegister(address & 0xffff, value);
		return;
	}

	if (thread->core->enableTracing)
	{
		printf("%08x [st %d] writeMemWord %08x %08x\n", thread->currentPc - 4, thread->id, 
			address, value);
	}

	if (thread->core->cosimEnable)
		cosimWriteMemory(thread->core, thread->currentPc - 4, address, 4, value);

	thread->core->memory[address / 4] = value;
	invalidateSyncAddress(thread->core, address);
}

static void writeMemShort(Thread *thread, uint32_t address, uint32_t value)
{
	if (thread->core->enableTracing)
	{
		printf("%08x [st %d] writeMemShort %08x %04x\n", thread->currentPc - 4, thread->id,
			address, value);
	}

	if (thread->core->cosimEnable)
		cosimWriteMemory(thread->core, thread->currentPc - 4, address, 2, value);

	((uint16_t*)thread->core->memory)[address / 2] = value & 0xffff;
	invalidateSyncAddress(thread->core, address);
}

static void writeMemByte(Thread *thread, uint32_t address, uint32_t value)
{
	if (thread->core->enableTracing)
	{
		printf("%08x [st %d] writeMemByte %08x %02x\n", thread->currentPc - 4, thread->id,
			address, value);
	}

	if (thread->core->cosimEnable)
		cosimWriteMemory(thread->core, thread->currentPc - 4, address, 1, value);

	((uint8_t*)thread->core->memory)[address] = value & 0xff;
	invalidateSyncAddress(thread->core, address);
}

static uint32_t readMemoryWord(const Thread *thread, uint32_t address)
{
	if ((address & 0xffff0000) == 0xffff0000)
		return readDeviceRegister(address & 0xffff);
	
	if (address >= thread->core->memorySize)
	{
		printf("Load Access Violation %08x, pc %08x\n", address, thread->currentPc - 4);
		printRegisters(thread->core, thread->id);
		thread->core->halt = 1;	// XXX Perhaps should stop some other way...
		return 0;
	}

	return thread->core->memory[address / 4];
}

static uint32_t doOp(int operation, uint32_t value1, uint32_t value2)
{
	switch (operation)
	{
		case 0: return value1 | value2;
		case 1: return value1 & value2;
		case 3: return value1 ^ value2;
		case 5: return value1 + value2;
		case 6: return value1 - value2;
		case 7: return value1 * value2;  
		case 8: return ((uint64_t)value1 * (uint64_t)value2) >> 32;	
		case 9:	return ((int32_t)value1) >> (value2 & 31);
		case 10: return value1 >> (value2 & 31);
		case 11: return value1 << (value2 & 31);
		case 12: return value2 == 0 ? 32 : __builtin_clz(value2);
		case 14: return value2 == 0 ? 32 : __builtin_ctz(value2);
		case 15: return value2;
		case 16: return value1 == value2;
		case 17: return value1 != value2;
		case 18: return (int32_t) value1 > (int32_t) value2;
		case 19: return (int32_t) value1 >= (int32_t) value2;
		case 20: return (int32_t) value1 < (int32_t) value2;
		case 21: return (int32_t) value1 <= (int32_t) value2;
		case 22: return value1 > value2;
		case 23: return value1 >= value2;
		case 24: return value1 < value2;
		case 25: return value1 <= value2;
		case 27: return (int32_t) valueAsFloat(value2); // ftoi
		case 28:
		{
			// Reciprocal only has 6 bits of accuracy
			uint32_t result = valueAsInt(1.0 / valueAsFloat(value2 & 0xfffe0000)); 
			if (((result >> 23) & 0xff) != 0xff || (result & 0x7fffff) == 0)
				result &= 0xfffe0000;	// Truncate, but only if not NaN

			return result;
		}

		case 29: return (int32_t)(int8_t) value2;
		case 30: return (int32_t)(int16_t) value2;
		case 31: return ((int64_t)(int32_t) value1 * (int64_t)(int32_t) value2) >> 32;
		case 32: return valueAsInt(valueAsFloat(value1) + valueAsFloat(value2));
		case 33: return valueAsInt(valueAsFloat(value1) - valueAsFloat(value2));
		case 34: return valueAsInt(valueAsFloat(value1) * valueAsFloat(value2));
		case 42: return valueAsInt((float)((int32_t)value2)); // itof
		case 44: return valueAsFloat(value1) > valueAsFloat(value2);
		case 45: return valueAsFloat(value1) >= valueAsFloat(value2);
		case 46: return valueAsFloat(value1) < valueAsFloat(value2);
		case 47: return valueAsFloat(value1) <= valueAsFloat(value2);
		case 48: return valueAsFloat(value1) == valueAsFloat(value2);
		case 49: return valueAsFloat(value1) != valueAsFloat(value2);
		default: return 0;
	}
}

static int isCompareOp(int op)
{
	return (op >= 16 && op <= 25) || (op >= 44 && op <= 49);
}

static struct Breakpoint *lookupBreakpoint(Core *core, uint32_t pc)
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

static void executeRegisterArith(Thread *thread, uint32_t instr)
{
	// A operation
	int fmt = extractUnsignedBits(instr, 26, 3);
	int op = extractUnsignedBits(instr, 20, 6);
	int op1reg = extractUnsignedBits(instr, 0, 5);
	int op2reg = extractUnsignedBits(instr, 15, 5);
	int destreg = extractUnsignedBits(instr, 5, 5);
	int maskreg = extractUnsignedBits(instr, 10, 5);
	int lane;

	LOG_INST_TYPE(STAT_REG_ARITH_INST);
	if (op == 26)
	{
		// getlane		
		setScalarReg(thread, destreg, thread->vectorReg[op1reg][15 - (getThreadScalarReg(
			thread, op2reg) & 0xf)]);
	}
	else if (isCompareOp(op))
	{
		uint32_t result = 0;
		switch (fmt)
		{
			case 0:
				// Scalar
				result = doOp(op, getThreadScalarReg(thread, op1reg), getThreadScalarReg(thread, 
					op2reg)) ? 0xffff : 0;
				break;
				
			case 1:
			case 2:
				LOG_INST_TYPE(STAT_VECTOR_INST);

				// Vector compares work a little differently than other arithmetic
				// operations: the results are packed together in the 16 low
				// bits of a scalar register

				// Vector/Scalar operation
				uint32_t scalarValue = getThreadScalarReg(thread, op2reg);
				for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
				{
					result >>= 1;
					result |= doOp(op, thread->vectorReg[op1reg][lane],
						scalarValue) ? 0x8000 : 0;
				}

				break;

			case 4:
			case 5:
				LOG_INST_TYPE(STAT_VECTOR_INST);

				// Vector/Vector operation
				for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
				{
					result >>= 1;
					result |= doOp(op, thread->vectorReg[op1reg][lane],
						thread->vectorReg[op2reg][lane]) ? 0x8000 : 0;
				}
				
				break;
				
			default:
				illegalInstruction(thread, instr);
				return;
		}		
		
		setScalarReg(thread, destreg, result);			
	} 
	else if (fmt == 0)
	{
		uint32_t result = doOp(op, getThreadScalarReg(thread, op1reg),
			getThreadScalarReg(thread, op2reg));
		setScalarReg(thread, destreg, result);			
	}
	else
	{
		// Vector arithmetic...
		uint32_t result[NUM_VECTOR_LANES];
		int mask;

		LOG_INST_TYPE(STAT_VECTOR_INST);
		switch (fmt)
		{
			case 2:
			case 5:
				mask = getThreadScalarReg(thread, maskreg); 
				break;
				
			case 1:
			case 4:
				mask = 0xffff;
				break;

			default:
				illegalInstruction(thread, instr);
				return;
		}
	
		if (op == 13)
		{
			// Shuffle
			uint32_t *src1 = thread->vectorReg[op1reg];
			const uint32_t *src2 = thread->vectorReg[op2reg];
			
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
				result[lane] = src1[15 - (src2[lane] & 0xf)];
		}
		else if (fmt < 4)
		{
			// Vector/Scalar operation
			uint32_t scalarValue = getThreadScalarReg(thread, op2reg);
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

static void executeImmediateArith(Thread *thread, uint32_t instr)
{
	int fmt = extractUnsignedBits(instr, 28, 3);
	int immValue;
	int op = extractUnsignedBits(instr, 23, 5);
	int op1reg = extractUnsignedBits(instr, 0, 5);
	int maskreg = extractUnsignedBits(instr, 10, 5);
	int destreg = extractUnsignedBits(instr, 5, 5);
	int hasMask = fmt == 2 || fmt == 3 || fmt == 5 || fmt == 6;
	int lane;

	LOG_INST_TYPE(STAT_IMM_ARITH_INST);
	if (hasMask)
		immValue = extractSignedBits(instr, 15, 8);
	else
		immValue = extractSignedBits(instr, 10, 13);

	if (op == 26)
	{
		// getlane		
		LOG_INST_TYPE(STAT_VECTOR_INST);
		setScalarReg(thread, destreg, thread->vectorReg[op1reg][15 - (immValue & 0xf)]);
	}
	else if (isCompareOp(op))
	{
		uint32_t result = 0;

		if (fmt == 1 || fmt == 2)
		{
			LOG_INST_TYPE(STAT_VECTOR_INST);

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
		else if (fmt == 0 || fmt == 4 || fmt == 5)
		{
			result = doOp(op, getThreadScalarReg(thread, op1reg),
				immValue) ? 0xffff : 0;
		}
		else
		{
			illegalInstruction(thread, instr);
			return;
		}
		
		setScalarReg(thread, destreg, result);			
	}
	else if (fmt == 0)
	{
		uint32_t result = doOp(op, getThreadScalarReg(thread, op1reg),
			immValue);
		setScalarReg(thread, destreg, result);			
	}
	else
	{
		int mask;
		uint32_t result[NUM_VECTOR_LANES];

		LOG_INST_TYPE(STAT_VECTOR_INST);
		switch (fmt)
		{
			case 2: 
				mask = getThreadScalarReg(thread, maskreg); 
				break;

			case 5: 
				mask = getThreadScalarReg(thread, maskreg); 
				break;

			case 0:
			case 1:
			case 4:
				mask = 0xffff;
				break;
				
			default:
				illegalInstruction(thread, instr);
				return;
		}
	
		for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
		{
			uint32_t operand1;
			if (fmt == 1 || fmt == 2 || fmt == 3)
				operand1 = thread->vectorReg[op1reg][lane];
			else
				operand1 = getThreadScalarReg(thread, op1reg);

			result[lane] = doOp(op, operand1, immValue);
		}
		
		setVectorReg(thread, destreg, mask, result);
	}
}

static void executeScalarLoadStore(Thread *thread, uint32_t instr)
{
	int op = extractUnsignedBits(instr, 25, 4);
	int ptrreg = extractUnsignedBits(instr, 0, 5);
	int offset = extractSignedBits(instr, 10, 15);
	int destsrcreg = extractUnsignedBits(instr, 5, 5);
	int isLoad = extractUnsignedBits(instr, 29, 1);
	uint32_t address;

	address = getThreadScalarReg(thread, ptrreg) + offset;
	if (address >= thread->core->memorySize && (address & 0xffff0000) != 0xffff0000)
	{
		printf("%s Access Violation %08x, pc %08x\n", isLoad ? "Load" : "Store",
			address, thread->currentPc - 4);
		printRegisters(thread->core, thread->id);
		thread->core->halt = 1;	// XXX Perhaps should stop some other way...
		return;
	}

	// Check for address alignment
	if (op == 2 || op == 3)
	{
		// Short
		if ((address & 1) != 0)
		{
			memoryAccessFault(thread, address, isLoad);
			return;
		}
	}
	else if (op == 4 || op == 5)
	{
		// Word
		if ((address & 3) != 0)
		{
			memoryAccessFault(thread, address, isLoad);
			return;
		}
	}

	if (isLoad)
	{
		uint32_t value;
		switch (op)
		{
			case 0: 	// Byte
				value = ((uint8_t*) thread->core->memory)[address]; 
				break;
				
			case 1: 	// Byte, sign extend
				value = ((int8_t*) thread->core->memory)[address]; 
				break;
				
			case 2: 	// Short
				value = ((uint16_t*) thread->core->memory)[address / 2]; 
				break;

			case 3: 	// Short, sign extend
				value = ((int16_t*) thread->core->memory)[address / 2]; 
				break;

			case 4:	// Load word
				value = readMemoryWord(thread, address); 
				break;

			case 5:	// Load linked
				value = readMemoryWord(thread, address);
				thread->linkedAddress = address / 64;
				break;
				
			case 6:	// Load control register
				value = 0;
				break;
				
			default:
				illegalInstruction(thread,  instr);
				return;
		}
		
		setScalarReg(thread, destsrcreg, value);			
	}
	else
	{
		// Store
		// Shift and mask in the value.
		uint32_t valueToStore = getThreadScalarReg(thread, destsrcreg);
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
				if (address / 64 == thread->linkedAddress)
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
				
			default:
				illegalInstruction(thread, instr);
				return;
		}
	}
}

static void executeVectorLoadStore(Thread *thread, uint32_t instr)
{
	int op = extractUnsignedBits(instr, 25, 4);
	int ptrreg = extractUnsignedBits(instr, 0, 5);
	int maskreg = extractUnsignedBits(instr, 10, 5);
	int destsrcreg = extractUnsignedBits(instr, 5, 5);
	int isLoad = extractUnsignedBits(instr, 29, 1);
	int offset;
	int lane;
	int mask;
	uint32_t baseAddress;
	uint32_t address;
	uint32_t result[16];

	LOG_INST_TYPE(STAT_VECTOR_INST);
	if (op == 7 || op == 13)
	{
		// not masked
		offset = extractSignedBits(instr, 10, 15);
	}
	else
	{
		// masked
		offset = extractSignedBits(instr, 15, 10);
	}

	// Compute mask value
	switch (op)
	{
		case 7:
		case 13:
			mask = 0xffff;
			break;

		case 8:
		case 14:	// Masked
			mask = getThreadScalarReg(thread, maskreg); break;
			break;

		default:
			illegalInstruction(thread, instr);
			return;
	}

	// Perform transfer
	if (op == 7 || op == 8)
	{
		// Block vector access.  Executes in a single cycle
		baseAddress = getThreadScalarReg(thread, ptrreg) + offset;
		if (baseAddress >= thread->core->memorySize)
		{
			printf("%s Access Violation %08x, pc %08x\n", isLoad ? "Load" : "Store",
				baseAddress, thread->currentPc - 4);
			printRegisters(thread->core, thread->id);
			thread->core->halt = 1;	// XXX Perhaps should stop some other way...
			return;
		}

		if ((baseAddress & 63) != 0)
		{
			memoryAccessFault(thread, baseAddress, isLoad);
			return;
		}

		if (isLoad)
		{
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
			printf("%s Access Violation %08x, pc %08x\n", isLoad ? "Load" : "Store",
				address, thread->currentPc - 4);
			printRegisters(thread->core, thread->id);
			thread->core->halt = 1;	// XXX Perhaps should stop some other way...
			return;
		}

		if ((mask & (1 << lane)) && (address & 3) != 0)
		{
			memoryAccessFault(thread, address, isLoad);
			return;
		}

		if (isLoad)
		{
			uint32_t values[16];
			memset(values, 0, 16 * sizeof(uint32_t));
			if (mask & (1 << lane))
				values[lane] = readMemoryWord(thread, address);
			
			setVectorReg(thread, destsrcreg, mask & (1 << lane), values);
		}
		else if (mask & (1 << lane))
			writeMemWord(thread, address, thread->vectorReg[destsrcreg][lane]);
	}

	if (thread->multiCycleTransferActive)
		thread->currentPc -= 4;	// repeat current instruction
}

static void executeControlRegister(Thread *thread, uint32_t instr)
{
	int crIndex = extractUnsignedBits(instr, 0, 5);
	int dstSrcReg = extractUnsignedBits(instr, 5, 5);
	if (extractUnsignedBits(instr, 29, 1))
	{
		// Load
		uint32_t value = 0xffffffff;
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
				
			case CR_CYCLE_COUNT:
				value = __total_instructions;
				break;
		}

		setScalarReg(thread, dstSrcReg, value);
	}
	else
	{
		// Store
		uint32_t value = getThreadScalarReg(thread, dstSrcReg);
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
				thread->core->threadEnableMask = getThreadScalarReg(thread, dstSrcReg)
					& ((1ull << thread->core->totalThreads) - 1);
				if (thread->core->threadEnableMask == 0)
					doHalt(thread->core);
					
				break;
				
			case CR_HALT:
				doHalt(thread->core);
				break;
		}
	}
}

static void executeMemoryAccess(Thread *thread, uint32_t instr)
{
	int type = extractUnsignedBits(instr, 25, 4);
	if (type != 6)	// Don't count control register transfers
	{
		if (extractUnsignedBits(instr, 29, 1))
			LOG_INST_TYPE(STAT_LOAD_INST);
		else
			LOG_INST_TYPE(STAT_STORE_INST);
	}

	if (type == 6)
		executeControlRegister(thread, instr);	
	else if (type < 6)
		executeScalarLoadStore(thread, instr);
	else
		executeVectorLoadStore(thread, instr);
}

static void executeBranch(Thread *thread, uint32_t instr)
{
	int branchTaken;
	int srcReg = extractUnsignedBits(instr, 0, 5);

	LOG_INST_TYPE(STAT_BRANCH_INST);
	switch (extractUnsignedBits(instr, 25, 3))
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
		thread->currentPc += extractSignedBits(instr, 5, 20);
}

static int retireInstruction(Thread *thread)
{
	uint32_t instr;

	instr = readMemoryWord(thread, thread->currentPc);
	thread->currentPc += 4;
	INC_INST_COUNT;

restart:
	if (instr == 0)
		; // no-op
	else if ((instr & 0xe0000000) == 0xc0000000)
		executeRegisterArith(thread, instr);
	else if ((instr & 0x80000000) == 0)
	{
		if (instr == BREAKPOINT_OP)
		{
			struct Breakpoint *breakpoint = lookupBreakpoint(thread->core, thread->currentPc - 4);
			if (breakpoint == NULL)
			{
				thread->currentPc += 4;
				illegalInstruction(thread, instr);
				return 1;
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
		else if (instr != 0) // 0 is no-op, don't evaluate
			executeImmediateArith(thread, instr);
	}
	else if ((instr & 0xc0000000) == 0x80000000)
		executeMemoryAccess(thread, instr);
	else if ((instr & 0xf0000000) == 0xf0000000)
		executeBranch(thread, instr);
	else if ((instr & 0xf0000000) == 0xe0000000)
		;	// Format D instruction.  Ignore
	else
		printf("Bad instruction @%08x\n", thread->currentPc - 4);

	return 1;
}
