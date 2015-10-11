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

#include <assert.h>
#include <inttypes.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "core.h"
#include "cosimulation.h"
#include "device.h"
#include "instruction-set.h"
#include "util.h"

#ifdef DUMP_INSTRUCTION_STATS
    #define TALLY_INSTRUCTION(type) thread->core->stat_ ## type++
#else
    #define TALLY_INSTRUCTION(type) do { } while (0)
#endif

#define INVALID_LINK_ADDR 0xffffffff

// This is used to signal an instruction that may be a breakpoint. We use
// a special instruction to avoid a breakpoint lookup on every instruction cycle.
// This is an invalid instruction because it uses a reserved format type
#define BREAKPOINT_OP 0x707fffff

typedef struct Thread Thread;

struct Thread
{
	Core *core;
	uint32_t id;
	uint32_t linkedAddress; // For synchronized store/load. Cache line (addr / 64)
	uint32_t currentPc;
	FaultReason lastFaultReason;
	uint32_t lastFaultPc;
	uint32_t lastFaultAddress;
	uint32_t interruptEnable;
	uint32_t multiCycleTransferActive;
	uint32_t multiCycleTransferLane;
	uint32_t scalarReg[NUM_REGISTERS - 1];	// 31 is PC, which is special
	uint32_t vectorReg[NUM_REGISTERS][NUM_VECTOR_LANES];
};

struct Core
{
	Thread *threads;
	struct Breakpoint *breakpoints;
	uint32_t *memory;
	uint32_t memorySize;
	uint32_t totalThreads;
	uint32_t threadEnableMask;
	uint32_t faultHandlerPc;
	bool crashed;
	bool singleStepping;
	bool stopOnFault;
	bool enableTracing;
	bool cosimEnable;
	int64_t totalInstructions;
#ifdef DUMP_INSTRUCTION_STATS
	int64_t stat_vector_inst;
	int64_t stat_load_inst;
	int64_t stat_store_inst;
	int64_t stat_branch_inst;
	int64_t stat_imm_arith_inst;
	int64_t stat_reg_arith_inst;
#endif
};

struct Breakpoint
{
	struct Breakpoint *next;
	uint32_t address;
	uint32_t originalInstruction;
	bool restart;
};

static void printThreadRegisters(const Thread*);
static uint32_t getThreadScalarReg(const Thread*, uint32_t reg);
static void setScalarReg(Thread*, uint32_t reg, uint32_t value);
static void setVectorReg(Thread*, uint32_t reg, uint32_t mask, 
	uint32_t *values);
static void invalidateSyncAddress(Core*, uint32_t address);
static void memoryAccessFault(Thread*, uint32_t address, bool isLoad, FaultReason);
static void illegalInstruction(Thread*, uint32_t instruction);
static void writeMemBlock(Thread*, uint32_t address, uint32_t mask, 
	const uint32_t *values);
static void writeMemWord(Thread*, uint32_t address, uint32_t value);
static void writeMemShort(Thread*, uint32_t address, uint32_t value);
static void writeMemByte(Thread*, uint32_t address, uint32_t value);
static uint32_t readMemoryWord(const Thread*, uint32_t address);
static uint32_t scalarArithmeticOp(ArithmeticOp, uint32_t value1, uint32_t value2);
static bool isCompareOp(uint32_t op);
static struct Breakpoint *lookupBreakpoint(Core*, uint32_t pc);
static void executeRegisterArithInst(Thread*, uint32_t instruction);
static void executeImmediateArithInst(Thread*, uint32_t instruction);
static void executeScalarLoadStoreInst(Thread*, uint32_t instruction);
static void executeVectorLoadStoreInst(Thread*, uint32_t instruction);
static void executeControlRegisterInst(Thread*, uint32_t instruction);
static void executeMemoryAccessInst(Thread*, uint32_t instruction);
static void executeBranchInst(Thread*, uint32_t instruction);
static int executeInstruction(Thread*);

Core *initCore(uint32_t memorySize, uint32_t totalThreads, bool randomizeMemory)
{
	uint32_t address;
	uint32_t threadid;
	Core *core;

	// Currently limited by enable mask
	assert(totalThreads <= 32);

	core = (Core*) calloc(sizeof(Core), 1);
	core->memorySize = memorySize;
	core->memory = (uint32_t*) malloc(memorySize);
	if (core->memory == NULL)
	{
		fprintf(stderr, "Could not allocate memory\n");
		return NULL;
	}
	
	if (randomizeMemory)
	{
		srand((unsigned int) time(NULL));
		for (address = 0; address < memorySize / 4; address++)
			core->memory[address] = (uint32_t) rand();
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

	core->threadEnableMask = 1;
	core->crashed = false;
	core->enableTracing = false;
	core->faultHandlerPc = 0;

	return core;
}

void enableTracing(Core *core)
{
	core->enableTracing = true;
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
		*memptr++ = endianSwap32((uint32_t) strtoul(line, NULL, 16));
		if ((uint32_t)((memptr - core->memory) * 4) >= core->memorySize)
		{
			fprintf(stderr, "hex file too big to fit in memory\n");
			return -1;
		}
	}
	
	fclose(file);

	return 0;
}

void writeMemoryToFile(const Core *core, const char *filename, uint32_t baseAddress, 
	uint32_t length)
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

void *getFramebuffer(Core *core)
{
	return ((uint8_t*) core->memory) + 0x200000;
}

void printRegisters(const Core *core, uint32_t threadId)
{
	printThreadRegisters(&core->threads[threadId]);
}

void enableCosimulation(Core *core)
{
	core->cosimEnable = true;
}

// Called when the verilog model in cosimulation indicates an interrupt.
void cosimInterrupt(Core *core, uint32_t threadId, uint32_t pc)
{
	Thread *thread = &core->threads[threadId];

	thread->lastFaultPc = pc;
	thread->currentPc = thread->core->faultHandlerPc;
	thread->lastFaultReason = FR_INTERRUPT;
	thread->interruptEnable = false;
	thread->multiCycleTransferActive = false;
}

uint32_t getTotalThreads(const Core *core)
{
	return core->totalThreads;
}

bool coreHalted(const Core *core)
{
	return core->threadEnableMask == 0 || core->crashed;
}

bool stoppedOnFault(const Core *core)
{
	return core->crashed;
}

uint32_t executeInstructions(Core *core, uint32_t threadId, uint32_t totalInstructions)
{
	uint32_t instructionCount;
	uint32_t thread;
	
	core->singleStepping = false;
	for (instructionCount = 0; instructionCount < totalInstructions; instructionCount++)
	{
		if (core->threadEnableMask == 0)
		{
			printf("Thread enable mask is now zero\n");
			return 0;
		}
	
		if (core->crashed)
			return 0;

		if (threadId == ALL_THREADS)
		{
			// Cycle through threads round-robin
			for (thread = 0; thread < core->totalThreads; thread++)
			{
				if (core->threadEnableMask & (1 << thread))
				{
					if (!executeInstruction(&core->threads[thread]))
						return 0;	// Hit breakpoint
				}
			}
		}
		else
		{
			if (!executeInstruction(&core->threads[threadId]))
				return 0;	// Hit breakpoint
		}
	}

	return 1;
}

void singleStep(Core *core, uint32_t threadId)
{
	core->singleStepping = true;
	executeInstruction(&core->threads[threadId]);	
}

uint32_t getPc(const Core *core, uint32_t threadId)
{
	return core->threads[threadId].currentPc;
}

uint32_t getScalarRegister(const Core *core, uint32_t threadId, uint32_t regId)
{
	return getThreadScalarReg(&core->threads[threadId], regId);
}

uint32_t getVectorRegister(const Core *core, uint32_t threadId, uint32_t regId, uint32_t lane)
{
	return core->threads[threadId].vectorReg[regId][lane];
}

uint32_t readMemoryByte(const Core *core, uint32_t address)
{
	if (address >= core->memorySize)
		return 0xffffffff;
	
	return ((uint8_t*) core->memory)[address];
}

void writeMemoryByte(const Core *core, uint32_t address, uint8_t byte)
{
	if (address >= core->memorySize)
		return;
	
	((uint8_t*) core->memory)[address] = byte;
}

int setBreakpoint(Core *core, uint32_t pc)
{
	struct Breakpoint *breakpoint = lookupBreakpoint(core, pc);
	if (breakpoint != NULL)
	{
		printf("already has a breakpoint at address %x\n", pc);
		return -1;
	}
	
	if (pc >= core->memorySize || (pc & 3) != 0)
	{
		printf("invalid breakpoint address %x\n", pc);
		return -1;
	}

	breakpoint = (struct Breakpoint*) calloc(sizeof(struct Breakpoint), 1);
	breakpoint->next = core->breakpoints;
	core->breakpoints = breakpoint;
	breakpoint->address = pc;
	breakpoint->originalInstruction = core->memory[pc / 4];
	if (breakpoint->originalInstruction == BREAKPOINT_OP)
		breakpoint->originalInstruction = INSTRUCTION_NOP;	// Avoid infinite loop
	
	core->memory[pc / 4] = BREAKPOINT_OP;
	return 0;
}

int clearBreakpoint(Core *core, uint32_t pc)
{
	struct Breakpoint **link;

	for (link = &core->breakpoints; *link; link = &(*link)->next)
	{
		if ((*link)->address == pc)
		{
			core->memory[pc / 4] = (*link)->originalInstruction;
			*link = (*link)->next;
			return 0;
		}
	}

	return -1; // Not found
}

void setStopOnFault(Core *core, bool stopOnFault)
{
	core->stopOnFault = stopOnFault;
}

void dumpInstructionStats(Core *core)
{
	printf("%" PRId64 " total instructions\n", core->totalInstructions);
#ifdef DUMP_INSTRUCTION_STATS
	#define PRINT_STAT(name) printf("%s %" PRId64 " %.4g%%\n", #name, core->stat_ ## name, \
		(double) core->stat_ ## name/ core->totalInstructions * 100);

	PRINT_STAT(vector_inst);
	PRINT_STAT(load_inst);
	PRINT_STAT(store_inst);
	PRINT_STAT(branch_inst);
	PRINT_STAT(imm_arith_inst);
	PRINT_STAT(reg_arith_inst);

	#undef PRINT_STAT
#endif
}

static void printThreadRegisters(const Thread *thread)
{
	int reg;
	int lane;
	
	printf("REGISTERS\n");
	for (reg = 0; reg < NUM_REGISTERS - 1; reg++)
	{
		if (reg < 10)
			printf(" "); // Align one digit numbers
			
		printf("s%d %08x ", reg, thread->scalarReg[reg]);
		if (reg % 8 == 7)
			printf("\n");
	}

	printf("s31 %08x\n\n", thread->currentPc - 4);
	for (reg = 0; reg < NUM_REGISTERS; reg++)
	{
		if (reg < 10)
			printf(" "); // Align one digit numbers
			
		printf("v%d ", reg);
		for (lane = NUM_VECTOR_LANES - 1; lane >= 0; lane--)
			printf("%08x", thread->vectorReg[reg][lane]);
			
		printf("\n");
	}
}

static uint32_t getThreadScalarReg(const Thread *thread, uint32_t reg)
{
	if (reg == PC_REG)
		return thread->currentPc;
	else
		return thread->scalarReg[reg];
}

static void setScalarReg(Thread *thread, uint32_t reg, uint32_t value)
{
	if (thread->core->enableTracing)
		printf("%08x [th %d] s%d <= %08x\n", thread->currentPc - 4, thread->id, reg, value);

	if (thread->core->cosimEnable)
		cosimSetScalarReg(thread->core, thread->currentPc - 4, reg, value);

	if (reg == PC_REG)
		thread->currentPc = value;
	else
		thread->scalarReg[reg] = value;
}

static void setVectorReg(Thread *thread, uint32_t reg, uint32_t mask, uint32_t *values)
{
	int lane;

	if (thread->core->enableTracing)
	{
		printf("%08x [th %d] v%d{%04x} <= ", thread->currentPc - 4, thread->id, reg, 
			mask & 0xffff);
		for (lane = NUM_VECTOR_LANES - 1; lane >= 0; lane--)
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
	uint32_t threadId;
	
	for (threadId = 0; threadId < core->totalThreads; threadId++)
	{
		if (core->threads[threadId].linkedAddress == address / CACHE_LINE_LENGTH)
			core->threads[threadId].linkedAddress = INVALID_LINK_ADDR;
	}
}

static void memoryAccessFault(Thread *thread, uint32_t address, bool isLoad, FaultReason reason)
{
	if (thread->core->stopOnFault)
	{
		printf("Invalid %s access thread %d PC %08x address %08x\n",
			isLoad ? "load" : "store",
			thread->id, thread->currentPc - 4, address);
		printThreadRegisters(thread);
		thread->core->crashed = true;
	}
	else
	{
		// Allow core to dispatch
		if (reason == FR_IFETCH_FAULT)
			thread->lastFaultPc = thread->currentPc;
		else
			thread->lastFaultPc = thread->currentPc - 4;
			
		thread->currentPc = thread->core->faultHandlerPc;
		thread->lastFaultReason = reason;
		thread->interruptEnable = false;
		thread->lastFaultAddress = address;
	}
}

static void illegalInstruction(Thread *thread, uint32_t instruction)
{
	if (thread->core->stopOnFault)
	{
		printf("Illegal instruction %08x thread %d PC %08x\n", instruction, thread->id, 
			thread->currentPc - 4);
		printThreadRegisters(thread);
		thread->core->crashed = true;
	}
	else
	{
		// Allow core to dispatch
		thread->lastFaultPc = thread->currentPc - 4;
		thread->currentPc = thread->core->faultHandlerPc;
		thread->lastFaultReason = FR_ILLEGAL_INSTRUCTION;
		thread->interruptEnable = false;
	}
}

static void writeMemBlock(Thread *thread, uint32_t address, uint32_t mask, 
	const uint32_t *values)
{
	uint32_t lane;

	if ((mask & 0xffff) == 0)
		return;	// Hardware ignores block stores with a mask of zero

	if (thread->core->enableTracing)
	{
		printf("%08x [th %d] writeMemBlock %08x\n", thread->currentPc - 4, thread->id,
			address);
	}
	
	if (thread->core->cosimEnable)
		cosimWriteBlock(thread->core, thread->currentPc - 4, address, mask, values);
	
	for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
	{
		uint32_t regIndex = NUM_VECTOR_LANES - lane - 1;
		if (mask & (1 << regIndex))
			thread->core->memory[(address / 4) + lane] = values[regIndex];
	}

	invalidateSyncAddress(thread->core, address);
}

static void writeMemWord(Thread *thread, uint32_t address, uint32_t value)
{
	if ((address & 0xffff0000) == 0xffff0000)
	{
		// IO address range
		if (address == 0xffff0060)
		{
			// Thread resume
			thread->core->threadEnableMask |= value
				& ((1ull << thread->core->totalThreads) - 1);
		}
		else if (address == 0xffff0064)
		{
			// Thread halt
			thread->core->threadEnableMask &= ~value;
		}
		else
			writeDeviceRegister(address & 0xffff, value);

		return;
	}

	if (thread->core->enableTracing)
	{
		printf("%08x [th %d] writeMemWord %08x %08x\n", thread->currentPc - 4, thread->id, 
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
		printf("%08x [th %d] writeMemShort %08x %04x\n", thread->currentPc - 4, thread->id,
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
		printf("%08x [th %d] writeMemByte %08x %02x\n", thread->currentPc - 4, thread->id,
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
		printThreadRegisters(thread);
		thread->core->crashed = true;
		return 0;
	}

	return thread->core->memory[address / 4];
}

static uint32_t scalarArithmeticOp(ArithmeticOp operation, uint32_t value1, uint32_t value2)
{
	switch (operation)
	{
		case OP_OR: return value1 | value2;
		case OP_AND: return value1 & value2;
		case OP_XOR: return value1 ^ value2;
		case OP_ADD_I: return value1 + value2;
		case OP_SUB_I: return value1 - value2;
		case OP_MULL_I: return value1 * value2;
		case OP_MULH_U: return (uint32_t)(((uint64_t)value1 * (uint64_t)value2) >> 32);	
		case OP_ASHR:	return (uint32_t)(((int32_t)value1) >> (value2 & 31));
		case OP_SHR: return value1 >> (value2 & 31);
		case OP_SHL: return value1 << (value2 & 31);
		case OP_CLZ: return value2 == 0 ? 32u : (uint32_t)__builtin_clz(value2);
		case OP_CTZ: return value2 == 0 ? 32u : (uint32_t)__builtin_ctz(value2);
		case OP_MOVE: return value2;
		case OP_CMPEQ_I: return (uint32_t)value1 == value2;
		case OP_CMPNE_I: return (uint32_t)value1 != value2;
		case OP_CMPGT_I: return (uint32_t)((int32_t)value1 > (int32_t)value2);
		case OP_CMPGE_I: return (uint32_t)((int32_t)value1 >= (int32_t)value2);
		case OP_CMPLT_I: return (uint32_t)((int32_t)value1 < (int32_t)value2);
		case OP_CMPLE_I: return (uint32_t)((int32_t)value1 <= (int32_t)value2);
		case OP_CMPGT_U: return (uint32_t)(value1 > value2);
		case OP_CMPGE_U: return (uint32_t)(value1 >= value2);
		case OP_CMPLT_U: return (uint32_t)(value1 < value2);
		case OP_CMPLE_U: return (uint32_t)(value1 <= value2);
		case OP_FTOI: return (uint32_t)(int32_t)valueAsFloat(value2); 
		case OP_RECIPROCAL:
		{
			// Reciprocal only has 6 bits of accuracy
			float fresult = 1.0f / valueAsFloat(value2 & 0xfffe0000);
			uint32_t iresult = valueAsInt(fresult); 
			if (!isnan(fresult))
				iresult &= 0xfffe0000;	// Truncate, but only if not NaN

			return iresult;
		}

		case OP_SEXT8: return (uint32_t)(int32_t)(int8_t)value2;
		case OP_SEXT16: return (uint32_t)(int32_t)(int16_t)value2;
		case OP_MULH_I: return (uint32_t) (((int64_t)(int32_t)value1 * (int64_t)(int32_t)value2) >> 32);
		case OP_ADD_F: return valueAsInt(valueAsFloat(value1) + valueAsFloat(value2));
		case OP_SUB_F: return valueAsInt(valueAsFloat(value1) - valueAsFloat(value2));
		case OP_MUL_F: return valueAsInt(valueAsFloat(value1) * valueAsFloat(value2));
		case OP_ITOF: return valueAsInt((float)(int32_t)value2); 
		case OP_CMPGT_F: return valueAsFloat(value1) > valueAsFloat(value2);
		case OP_CMPGE_F: return valueAsFloat(value1) >= valueAsFloat(value2);
		case OP_CMPLT_F: return valueAsFloat(value1) < valueAsFloat(value2);
		case OP_CMPLE_F: return valueAsFloat(value1) <= valueAsFloat(value2);
		case OP_CMPEQ_F: return valueAsFloat(value1) == valueAsFloat(value2);
		case OP_CMPNE_F: return valueAsFloat(value1) != valueAsFloat(value2);
		default: return 0u;
	}
}

static bool isCompareOp(uint32_t op)
{
	return (op >= OP_CMPEQ_I && op <= OP_CMPLE_U) || (op >= OP_CMPGT_F && op <= OP_CMPNE_F);
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

static void executeRegisterArithInst(Thread *thread, uint32_t instruction)
{
	RegisterArithFormat fmt = extractUnsignedBits(instruction, 26, 3);
	ArithmeticOp op = extractUnsignedBits(instruction, 20, 6);
	uint32_t op1reg = extractUnsignedBits(instruction, 0, 5);
	uint32_t op2reg = extractUnsignedBits(instruction, 15, 5);
	uint32_t destreg = extractUnsignedBits(instruction, 5, 5);
	uint32_t maskreg = extractUnsignedBits(instruction, 10, 5);
	int lane;

	TALLY_INSTRUCTION(reg_arith_inst);
	if (op == OP_GETLANE)
	{
		setScalarReg(thread, destreg, thread->vectorReg[op1reg][NUM_VECTOR_LANES - 1 
			- (getThreadScalarReg(thread, op2reg) & 0xf)]);
	}
	else if (isCompareOp(op))
	{
		uint32_t result = 0;
		switch (fmt)
		{
			case FMT_RA_SS:
				result = scalarArithmeticOp(op, getThreadScalarReg(thread, op1reg),
					getThreadScalarReg(thread, op2reg)) ? 0xffff : 0;
				break;

			case FMT_RA_VS:
			case FMT_RA_VS_M:
				TALLY_INSTRUCTION(vector_inst);

				// Vector compare results are packed together in the 16 low
				// bits of a scalar register, one bit per lane.

				// Vector/Scalar operation
				uint32_t scalarValue = getThreadScalarReg(thread, op2reg);
				for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
				{
					result >>= 1;
					result |= scalarArithmeticOp(op, thread->vectorReg[op1reg][lane],
						scalarValue) ? 0x8000 : 0;
				}

				break;

			case FMT_RA_VV:
			case FMT_RA_VV_M:
				TALLY_INSTRUCTION(vector_inst);

				// Vector/Vector operation
				for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
				{
					result >>= 1;
					result |= scalarArithmeticOp(op, thread->vectorReg[op1reg][lane],
						thread->vectorReg[op2reg][lane]) ? 0x8000 : 0;
				}

				break;

			default:
				illegalInstruction(thread, instruction);
				return;
		}
		
		setScalarReg(thread, destreg, result);			
	}
	else if (fmt == FMT_RA_SS)
	{
		uint32_t result = scalarArithmeticOp(op, getThreadScalarReg(thread, op1reg),
			getThreadScalarReg(thread, op2reg));
		setScalarReg(thread, destreg, result);			
	}
	else
	{
		// Vector arithmetic...
		uint32_t result[NUM_VECTOR_LANES];
		uint32_t mask;

		TALLY_INSTRUCTION(vector_inst);
		switch (fmt)
		{
			case FMT_RA_VS_M:
			case FMT_RA_VV_M:
				mask = getThreadScalarReg(thread, maskreg); 
				break;
			
			case FMT_RA_VS:
			case FMT_RA_VV:
				mask = 0xffff;
				break;

			default:
				illegalInstruction(thread, instruction);
				return;
		}
	
		if (op == OP_SHUFFLE)
		{
			const uint32_t *src1 = thread->vectorReg[op1reg];
			const uint32_t *src2 = thread->vectorReg[op2reg];
			
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
				result[lane] = src1[NUM_VECTOR_LANES - 1 - (src2[lane] & 0xf)];
		}
		else if (fmt == FMT_RA_VS || fmt == FMT_RA_VS_M)
		{
			// Vector/Scalar operation
			uint32_t scalarValue = getThreadScalarReg(thread, op2reg);
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
			{
				result[lane] = scalarArithmeticOp(op, thread->vectorReg[op1reg][lane],
					scalarValue);
			}
		}
		else
		{
			// Vector/Vector operation
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
			{
				result[lane] = scalarArithmeticOp(op, thread->vectorReg[op1reg][lane],
					thread->vectorReg[op2reg][lane]);
			}
		}

		setVectorReg(thread, destreg, mask, result);
	}
}

static void executeImmediateArithInst(Thread *thread, uint32_t instruction)
{
	ImmediateArithFormat fmt = extractUnsignedBits(instruction, 28, 3);
	uint32_t immValue;
	ArithmeticOp op = extractUnsignedBits(instruction, 23, 5);
	uint32_t op1reg = extractUnsignedBits(instruction, 0, 5);
	uint32_t maskreg = extractUnsignedBits(instruction, 10, 5);
	uint32_t destreg = extractUnsignedBits(instruction, 5, 5);
	uint32_t hasMask = fmt == FMT_IMM_VV_M || fmt == FMT_IMM_VS_M;
	int lane;
	uint32_t operand1;

	TALLY_INSTRUCTION(imm_arith_inst);
	if (hasMask)
		immValue = extractSignedBits(instruction, 15, 8);
	else
		immValue = extractSignedBits(instruction, 10, 13);

	if (op == OP_GETLANE)
	{
		// getlane
		TALLY_INSTRUCTION(vector_inst);
		setScalarReg(thread, destreg, thread->vectorReg[op1reg][NUM_VECTOR_LANES - 1 - (immValue & 0xf)]);
	}
	else if (isCompareOp(op))
	{
		uint32_t result = 0;
		switch (fmt)
		{
			case FMT_IMM_VV:
			case FMT_IMM_VV_M:
				TALLY_INSTRUCTION(vector_inst);

				// Vector compares work a little differently than other arithmetic
				// operations: the results are packed together in the 16 low
				// bits of a scalar register
				for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
				{
					result >>= 1;
					result |= scalarArithmeticOp(op, thread->vectorReg[op1reg][lane],
						immValue) ? 0x8000 : 0;
				}

				break;
		
			case FMT_IMM_SS:
			case FMT_IMM_VS:
			case FMT_IMM_VS_M:
				result = scalarArithmeticOp(op, getThreadScalarReg(thread, op1reg),
					immValue) ? 0xffff : 0;
				break;

			default:
				illegalInstruction(thread, instruction);
				return;
		}
		
		setScalarReg(thread, destreg, result);			
	}
	else if (fmt == FMT_IMM_SS)
	{
		uint32_t result = scalarArithmeticOp(op, getThreadScalarReg(thread, op1reg),
			immValue);
		setScalarReg(thread, destreg, result);			
	}
	else
	{
		// Vector arithmetic...
		uint32_t result[NUM_VECTOR_LANES];
		uint32_t mask;

		TALLY_INSTRUCTION(vector_inst);
		switch (fmt)
		{
			case FMT_IMM_VV_M:
			case FMT_IMM_VS_M:
				mask = getThreadScalarReg(thread, maskreg); 
				break;

			case FMT_IMM_VV:
			case FMT_IMM_VS:
				mask = 0xffff;
				break;

			default:
				illegalInstruction(thread, instruction);
				return;
		}
		
		if (fmt == FMT_IMM_VV || fmt == FMT_IMM_VV_M)
		{
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
			{
				result[lane] = scalarArithmeticOp(op, thread->vectorReg[op1reg][lane], 
					immValue);
			}
		}
		else
		{
			operand1 = getThreadScalarReg(thread, op1reg);
			for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
				result[lane] = scalarArithmeticOp(op, operand1, immValue);
		}

		setVectorReg(thread, destreg, mask, result);
	}
}

static void executeScalarLoadStoreInst(Thread *thread, uint32_t instruction)
{
	MemoryOp op = extractUnsignedBits(instruction, 25, 4);
	uint32_t ptrreg = extractUnsignedBits(instruction, 0, 5);
	uint32_t offset = extractSignedBits(instruction, 10, 15);
	uint32_t destsrcreg = extractUnsignedBits(instruction, 5, 5);
	bool isLoad = extractUnsignedBits(instruction, 29, 1);
	uint32_t address;
	int isDeviceAccess;

	address = getThreadScalarReg(thread, ptrreg) + offset;
	isDeviceAccess = (address & 0xffff0000) == 0xffff0000;
	if ((address >= thread->core->memorySize && !isDeviceAccess)
		|| (isDeviceAccess && op != MEM_LONG))
	{
		printf("%s Access Violation %08x, pc %08x\n", isLoad ? "Load" : "Store",
			address, thread->currentPc - 4);
		printThreadRegisters(thread);
		thread->core->crashed = true;
		return;
	}

	// Check for address alignment
	switch (op) 
	{
		// Short
		case MEM_SHORT:
		case MEM_SHORT_EXT:
			if ((address & 1) != 0)
			{
				memoryAccessFault(thread, address, isLoad, FR_INVALID_ACCESS);
				return;
			}
			break;

		// Word
		case MEM_LONG:
		case MEM_SYNC:
			if ((address & 3) != 0)
			{
				memoryAccessFault(thread, address, isLoad, FR_INVALID_ACCESS);
				return;
			}
			break;

		default:
			break;
	}

	if (isLoad)
	{
		uint32_t value;
		switch (op)
		{
			case MEM_BYTE: 
				value = (uint32_t) ((uint8_t*) thread->core->memory)[address]; 
				break;
				
			case MEM_BYTE_SEXT: 	
				value = (uint32_t) ((int8_t*) thread->core->memory)[address]; 
				break;
				
			case MEM_SHORT: 
				value = (uint32_t) ((uint16_t*) thread->core->memory)[address / 2]; 
				break;

			case MEM_SHORT_EXT: 
				value = (uint32_t) ((int16_t*) thread->core->memory)[address / 2]; 
				break;

			case MEM_LONG:
				value = readMemoryWord(thread, address); 
				break;

			case MEM_SYNC:
				value = readMemoryWord(thread, address);
				thread->linkedAddress = address / CACHE_LINE_LENGTH;
				break;
				
			case MEM_CONTROL_REG:
				value = 0;
				break;
				
			default:
				illegalInstruction(thread, instruction);
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
			case MEM_BYTE:
			case MEM_BYTE_SEXT:
				writeMemByte(thread, address, valueToStore);
				break;
				
			case MEM_SHORT:
			case MEM_SHORT_EXT:
				writeMemShort(thread, address, valueToStore);
				break;
				
			case MEM_LONG:
				writeMemWord(thread, address, valueToStore);
				break;

			case MEM_SYNC:
				if (address / CACHE_LINE_LENGTH == thread->linkedAddress)
				{
					// Success
					thread->scalarReg[destsrcreg] = 1;	// HACK: cosim assumes one side effect per inst.
					writeMemWord(thread, address, valueToStore);
				}
				else
					thread->scalarReg[destsrcreg] = 0;	// Fail. Same as above.
				
				break;
				
			case MEM_CONTROL_REG:
				break;
				
			default:
				illegalInstruction(thread, instruction);
				return;
		}
	}
}

static void executeVectorLoadStoreInst(Thread *thread, uint32_t instruction)
{
	uint32_t op = extractUnsignedBits(instruction, 25, 4);
	uint32_t ptrreg = extractUnsignedBits(instruction, 0, 5);
	uint32_t maskreg = extractUnsignedBits(instruction, 10, 5);
	uint32_t destsrcreg = extractUnsignedBits(instruction, 5, 5);
	bool isLoad = extractUnsignedBits(instruction, 29, 1);
	uint32_t offset;
	uint32_t lane;
	uint32_t mask;
	uint32_t address;
	uint32_t result[NUM_VECTOR_LANES];

	TALLY_INSTRUCTION(vector_inst);

	// Compute mask value
	switch (op)
	{
		case MEM_BLOCK_VECTOR:
		case MEM_SCGATH:
			mask = 0xffff;
			offset = extractSignedBits(instruction, 10, 15);	// Not masked
			break;

		case MEM_BLOCK_VECTOR_MASK:
		case MEM_SCGATH_MASK:
			mask = getThreadScalarReg(thread, maskreg);
			offset = extractSignedBits(instruction, 15, 10);  // masked
			break;

		default:
			illegalInstruction(thread, instruction);
			return;
	}

	// Perform transfer
	switch (op)
	{
		case MEM_BLOCK_VECTOR:
		case MEM_BLOCK_VECTOR_MASK:
		{
			// Block vector access. Executes in a single cycle
			address = getThreadScalarReg(thread, ptrreg) + offset;
			if (address >= thread->core->memorySize)
			{
				// This doesn't raise an actual fault on hardware. It is here to 
				// aid debugging.
				printf("%s Access Violation %08x, pc %08x\n", isLoad ? "Load" : "Store",
					address, thread->currentPc - 4);
				printThreadRegisters(thread);
				thread->core->crashed = true;
				return;
			}

			if ((address & (NUM_VECTOR_LANES * 4 - 1)) != 0)
			{
				memoryAccessFault(thread, address, isLoad, FR_INVALID_ACCESS);
				return;
			}

			if (isLoad)
			{
				for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
					result[lane] = readMemoryWord(thread, address + (NUM_VECTOR_LANES - 1 - lane) * 4);

				setVectorReg(thread, destsrcreg, mask, result);
			}
			else
				writeMemBlock(thread, address, mask, thread->vectorReg[destsrcreg]);
		}
		break;

		default:
			// Multi-cycle vector access.
			if (!thread->multiCycleTransferActive)
			{
				thread->multiCycleTransferActive = true;
				thread->multiCycleTransferLane = NUM_VECTOR_LANES - 1;
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
				printThreadRegisters(thread);
				thread->core->crashed = true;
				return;
			}

			if ((mask & (1 << lane)) && (address & 3) != 0)
			{
				memoryAccessFault(thread, address, isLoad, FR_INVALID_ACCESS);
				return;
			}

			if (isLoad)
			{
				uint32_t values[NUM_VECTOR_LANES];
				memset(values, 0, NUM_VECTOR_LANES * sizeof(uint32_t));
				if (mask & (1 << lane))
					values[lane] = readMemoryWord(thread, address);

				setVectorReg(thread, destsrcreg, mask & (1 << lane), values);
			}
			else if (mask & (1 << lane))
				writeMemWord(thread, address, thread->vectorReg[destsrcreg][lane]);

			break;
	}

	if (thread->multiCycleTransferActive)
		thread->currentPc -= 4;	// repeat current instruction
}

static void executeControlRegisterInst(Thread *thread, uint32_t instruction)
{
	uint32_t crIndex = extractUnsignedBits(instruction, 0, 5);
	uint32_t dstSrcReg = extractUnsignedBits(instruction, 5, 5);
	if (extractUnsignedBits(instruction, 29, 1))
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
				
			case CR_CYCLE_COUNT:
				value = (uint32_t) (thread->core->totalInstructions & 0xffffffff);
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
		}
	}
}

static void executeMemoryAccessInst(Thread *thread, uint32_t instruction)
{
	uint32_t type = extractUnsignedBits(instruction, 25, 4);
	if (type != MEM_CONTROL_REG)	// Don't count control register transfers
	{
		if (extractUnsignedBits(instruction, 29, 1))
			TALLY_INSTRUCTION(load_inst);
		else
			TALLY_INSTRUCTION(store_inst);
	}

	if (type == MEM_CONTROL_REG)
		executeControlRegisterInst(thread, instruction);	
	else if (type < MEM_CONTROL_REG)
		executeScalarLoadStoreInst(thread, instruction);
	else
		executeVectorLoadStoreInst(thread, instruction);
}

static void executeBranchInst(Thread *thread, uint32_t instruction)
{
	bool branchTaken = false;
	uint32_t srcReg = extractUnsignedBits(instruction, 0, 5);

	TALLY_INSTRUCTION(branch_inst);
	switch (extractUnsignedBits(instruction, 25, 3))
	{
		case BRANCH_ALL: 
			branchTaken = (getThreadScalarReg(thread, srcReg) & 0xffff) == 0xffff;
			break;
			
		case BRANCH_ZERO: 
			branchTaken = getThreadScalarReg(thread, srcReg) == 0;
			break;

		case BRANCH_NOT_ZERO:
			branchTaken = getThreadScalarReg(thread, srcReg) != 0;
			break;

		case BRANCH_ALWAYS:
			branchTaken = true;
			break;
			
		case BRANCH_CALL_OFFSET:
			branchTaken = true;
			setScalarReg(thread, LINK_REG, thread->currentPc);
			break;
			
		case BRANCH_NOT_ALL:
			branchTaken = (getThreadScalarReg(thread, srcReg) & 0xffff) != 0xffff;
			break;
			
		case BRANCH_CALL_REGISTER:
			setScalarReg(thread, LINK_REG, thread->currentPc);
			thread->currentPc = getThreadScalarReg(thread, srcReg);
			return; // Short circuit out, since we use register as destination.
			
		case BRANCH_ERET:
			thread->currentPc = thread->lastFaultPc;
			return; // Short circuit out
	}
	
	if (branchTaken)
		thread->currentPc += extractSignedBits(instruction, 5, 20);
}

static int executeInstruction(Thread *thread)
{
	uint32_t instruction;
	
	if ((thread->currentPc & 3) != 0)
		memoryAccessFault(thread, thread->currentPc, true, FR_IFETCH_FAULT);

	instruction = readMemoryWord(thread, thread->currentPc);
	thread->currentPc += 4;
	thread->core->totalInstructions++;

restart:
	if ((instruction & 0xe0000000) == 0xc0000000)
		executeRegisterArithInst(thread, instruction);
	else if ((instruction & 0x80000000) == 0)
	{
		if (instruction == BREAKPOINT_OP)
		{
			struct Breakpoint *breakpoint = lookupBreakpoint(thread->core, thread->currentPc - 4);
			if (breakpoint == NULL)
			{
				thread->currentPc += 4;
				illegalInstruction(thread, instruction);
				return 1;
			}
		
			if (breakpoint->restart || thread->core->singleStepping)
			{
				breakpoint->restart = false;
				instruction = breakpoint->originalInstruction;
				assert(instruction != BREAKPOINT_OP);
				goto restart;
			}
			else
			{
				// Hit a breakpoint
				breakpoint->restart = true;
				return 0;
			}
		}
		else if (instruction != INSTRUCTION_NOP) 
		{
			// Don't call this for nop instructions. Although executing 
			// the instruction (or s0, s0, s0) has no effect, it would
			// cause a cosimulation mismatch because the verilog model
			// does not generate an event for it.

			executeImmediateArithInst(thread, instruction);
		}
	}
	else if ((instruction & 0xc0000000) == 0x80000000)
		executeMemoryAccessInst(thread, instruction);
	else if ((instruction & 0xf0000000) == 0xf0000000)
		executeBranchInst(thread, instruction);
	else if ((instruction & 0xf0000000) == 0xe0000000)
		;	// Format D instruction. Ignore
	else
		printf("Bad instruction @%08x\n", thread->currentPc - 4);

	return 1;
}
