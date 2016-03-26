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
#include <fcntl.h>
#include <inttypes.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/time.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>
#include "core.h"
#include "cosimulation.h"
#include "device.h"
#include "instruction-set.h"
#include "util.h"

#define TLB_SETS 16
#define TLB_WAYS 4
#define PAGE_SIZE 0x1000u
#define ROUND_TO_PAGE(addr) ((addr) & ~(PAGE_SIZE - 1u))
#define PAGE_OFFSET(addr) ((addr) & (PAGE_SIZE - 1u))
#define TRAP_LEVELS 2

#ifdef DUMP_INSTRUCTION_STATS
#define TALLY_INSTRUCTION(type) thread->core->stat ## type++
#else
#define TALLY_INSTRUCTION(type) do { } while (0)
#endif

#define INVALID_ADDR 0xfffffffful


// When a breakpoint is set, this instruction replaces the one at the
// breakpoint address. It is invalid, because it uses a reserved format
// type. The interpreter only performs a breakpoint lookup when it sees
// this instruction as an optimization.
#define BREAKPOINT_INST 0x707fffff

typedef struct Thread Thread;
typedef struct TlbEntry TlbEntry;
typedef struct Breakpoint Breakpoint;

struct Thread
{
    Core *core;
    uint32_t id;
    uint32_t lastSyncLoadAddr; // Cache line number (addr / 64)
    uint32_t currentPc;
    uint32_t currentAsid;
    uint32_t currentPageDir;
    bool enableInterrupt;
    bool enableMmu;
    bool enableSupervisor;
    uint32_t currentSubcycle;
    uint32_t scalarReg[NUM_REGISTERS - 1];	// PC (31) not included here
    uint32_t vectorReg[NUM_REGISTERS][NUM_VECTOR_LANES];
    uint32_t pendingInterrupts;

    // Trap information. There are two levels of trap information, to
    // handle a nested TLB miss occurring in the middle of another trap.
    TrapReason trapReason[TRAP_LEVELS];
    uint32_t trapScratchpad0[TRAP_LEVELS];
    uint32_t trapScratchpad1[TRAP_LEVELS];
    uint32_t trapPc[TRAP_LEVELS];
    uint32_t trapAccessAddress[TRAP_LEVELS];
    uint32_t trapSubcycle[TRAP_LEVELS];
    bool trapEnableInterrupt[TRAP_LEVELS];
    bool trapEnableMmu[TRAP_LEVELS];
    bool trapEnableSupervisor[TRAP_LEVELS];
};

struct TlbEntry
{
    uint32_t asid;
    uint32_t virtualAddress;
    uint32_t physAddrAndFlags;
};

struct Core
{
    Thread *threads;
    Breakpoint *breakpoints;
    uint32_t *memory;
    uint32_t memorySize;
    uint32_t totalThreads;
    uint32_t threadEnableMask;
    uint32_t trapHandlerPc;
    uint32_t tlbMissHandlerPc;
    uint32_t physTlbUpdateAddr;
    TlbEntry *itlb;
    uint32_t nextITlbWay;
    TlbEntry *dtlb;
    uint32_t nextDTlbWay;
    bool crashed;
    bool singleStepping;
    bool stopOnFault;
    bool enableTracing;
    bool enableCosim;
    int64_t totalInstructions;
    uint32_t startCycleCount;
#ifdef DUMP_INSTRUCTION_STATS
    int64_t statVectorInst;
    int64_t statLoadInst;
    int64_t statStoreInst;
    int64_t statBranchInst;
    int64_t statImmArithInst;
    int64_t statRegArithInst;
#endif
};

struct Breakpoint
{
    Breakpoint *next;
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
static void tryToDispatchInterrupts(Thread*);
static void raiseTrap(Thread*, uint32_t address, TrapReason);
static void raiseAccessFault(Thread*, uint32_t address, TrapReason, bool isLoad);
static void raiseIllegalInstructionFault(Thread*, uint32_t instruction);
static bool translateAddress(Thread*, uint32_t virtualAddress, uint32_t
                             *physicalAddress, bool data, bool isWrite);
static uint32_t scalarArithmeticOp(ArithmeticOp, uint32_t value1, uint32_t value2);
static bool isCompareOp(uint32_t op);
static Breakpoint *lookupBreakpoint(Core*, uint32_t pc);
static void executeRegisterArithInst(Thread*, uint32_t instruction);
static void executeImmediateArithInst(Thread*, uint32_t instruction);
static void executeScalarLoadStoreInst(Thread*, uint32_t instruction);
static void executeBlockLoadStoreInst(Thread*, uint32_t instruction);
static void executeScatterGatherInst(Thread*, uint32_t instruction);
static void executeControlRegisterInst(Thread*, uint32_t instruction);
static void executeMemoryAccessInst(Thread*, uint32_t instruction);
static void executeBranchInst(Thread*, uint32_t instruction);
static void executeCacheControlInst(Thread*, uint32_t instruction);
static bool executeInstruction(Thread*);

Core *initCore(uint32_t memorySize, uint32_t totalThreads, bool randomizeMemory,
               const char *sharedMemoryFile)
{
    uint32_t address;
    uint32_t threadid;
    Core *core;
    int i;
    struct timeval tv;
    int sharedMemoryFd;

    // Limited by enable mask
    assert(totalThreads <= 32);

    core = (Core*) calloc(sizeof(Core), 1);
    core->memorySize = memorySize;
    if (sharedMemoryFile != NULL)
    {
        sharedMemoryFd = open(sharedMemoryFile, O_CREAT | O_RDWR, 666);
        if (sharedMemoryFd < 0)
        {
            perror("initCore: Error opening shared memory file");
            return NULL;
        }

        if (ftruncate(sharedMemoryFd, memorySize) < 0)
        {
            perror("initCore: couldn't resize shared memory file");
            return NULL;
        }

        core->memory = mmap(NULL, memorySize, PROT_READ | PROT_WRITE, MAP_SHARED
                            | MAP_FILE, sharedMemoryFd, 0);
        if (core->memory == NULL)
        {
            perror("initCore: mmap failed");
            return NULL;
        }
    }
    else
    {
        core->memory = (uint32_t*) malloc(memorySize);
        if (core->memory == NULL)
        {
            perror("initCore: malloc failed");
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
    }

    core->itlb = (TlbEntry*) malloc(sizeof(TlbEntry) * TLB_SETS * TLB_WAYS);
    core->dtlb = (TlbEntry*) malloc(sizeof(TlbEntry) * TLB_SETS * TLB_WAYS);
    for (i = 0; i < TLB_SETS * TLB_WAYS; i++)
    {
        // Set to invalid (unaligned) addresses so these don't match
        core->itlb[i].virtualAddress = INVALID_ADDR;
        core->dtlb[i].virtualAddress = INVALID_ADDR;
    }

    core->totalThreads = totalThreads;
    core->threads = (Thread*) calloc(sizeof(Thread), totalThreads);
    for (threadid = 0; threadid < totalThreads; threadid++)
    {
        core->threads[threadid].core = core;
        core->threads[threadid].id = threadid;
        core->threads[threadid].lastSyncLoadAddr = INVALID_ADDR;
        core->threads[threadid].enableSupervisor = true;
        core->threads[threadid].trapEnableSupervisor[0] = true;
    }

    core->threadEnableMask = 1;
    core->crashed = false;
    core->enableTracing = false;
    core->trapHandlerPc = 0;

    gettimeofday(&tv, NULL);
    core->startCycleCount = (uint32_t)(tv.tv_sec * 50000000 + tv.tv_usec * 50);

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
        perror("loadHexFile: error opening output file");
        return -1;
    }

    while (fgets(line, sizeof(line), file))
    {
        *memptr++ = endianSwap32((uint32_t) strtoul(line, NULL, 16));
        if ((uint32_t)((memptr - core->memory) * 4) >= core->memorySize)
        {
            fprintf(stderr, "loadHexFile: hex file too big to fit in memory\n");
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
        perror("writeMemoryToFile: Error opening output file");
        return;
    }

    if (fwrite((int8_t*) core->memory + baseAddress, MIN(core->memorySize, length), 1, file) <= 0)
    {
        perror("writeMemoryToFile: fwrite failed");
        return;
    }

    fclose(file);
}

const void *getMemoryRegionPtr(const Core *core, uint32_t address, uint32_t length)
{
    assert(length < core->memorySize);

    // Prevent overrun for bad address
    if (address > core->memorySize || address + length > core->memorySize)
        return core->memory;

    return ((const uint8_t*) core->memory) + address;
}

void printRegisters(const Core *core, uint32_t threadId)
{
    printThreadRegisters(&core->threads[threadId]);
}

void enableCosimulation(Core *core)
{
    core->enableCosim = true;
}

void raiseInterrupt(Core *core, uint32_t threadId, uint32_t interruptId)
{
    Thread *thread = &core->threads[threadId];
    thread->pendingInterrupts |= 1 << interruptId;
    tryToDispatchInterrupts(thread);
}

// Called when the verilog model in cosimulation indicates an interrupt.
void cosimInterrupt(Core *core, uint32_t threadId, uint32_t pc)
{
    Thread *thread = &core->threads[threadId];

    // This handles an edge case where cosimulation mismatches would occur
    // if an interrupt happened during a scatter store. Hardware does not
    // create store cycles for scatter store lanes that do not have the mask
    // bit set (and thus doesn't emit cosimulation events). It's possible for
    // the instruction to finish in hardware, but the emulator not to have
    // finished it. When it starts executing the ISR, the subcycle counter
    // will be non-zero, which messes up things later.
    if (pc != thread->currentPc)
        thread->currentSubcycle = 0;

    thread->currentPc = pc + 4;
    raiseTrap(thread, 0, TR_INTERRUPT_BASE);
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

bool executeInstructions(Core *core, uint32_t threadId, uint64_t totalInstructions)
{
    uint64_t instructionCount;
    uint32_t thread;

    core->singleStepping = false;
    for (instructionCount = 0; instructionCount < totalInstructions; instructionCount++)
    {
        if (core->threadEnableMask == 0)
        {
            printf("Thread enable mask is now zero\n");
            return false;
        }

        if (core->crashed)
            return false;

        if (threadId == ALL_THREADS)
        {
            // Cycle through threads round-robin
            for (thread = 0; thread < core->totalThreads; thread++)
            {
                if (core->threadEnableMask & (1 << thread))
                {
                    if (!executeInstruction(&core->threads[thread]))
                        return false;  // Hit breakpoint
                }
            }
        }
        else
        {
            if (!executeInstruction(&core->threads[threadId]))
                return false;  // Hit breakpoint
        }
    }

    return true;
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

uint32_t debugReadMemoryByte(const Core *core, uint32_t address)
{
    return ((uint8_t*)core->memory)[address];
}

void debugWriteMemoryByte(const Core *core, uint32_t address, uint8_t byte)
{
    ((uint8_t*)core->memory)[address] = byte;
}

int setBreakpoint(Core *core, uint32_t pc)
{
    Breakpoint *breakpoint = lookupBreakpoint(core, pc);
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

    breakpoint = (Breakpoint*) calloc(sizeof(Breakpoint), 1);
    breakpoint->next = core->breakpoints;
    core->breakpoints = breakpoint;
    breakpoint->address = pc;
    breakpoint->originalInstruction = core->memory[pc / 4];
    if (breakpoint->originalInstruction == BREAKPOINT_INST)
        breakpoint->originalInstruction = INSTRUCTION_NOP;	// Avoid infinite loop

    core->memory[pc / 4] = BREAKPOINT_INST;
    return 0;
}

int clearBreakpoint(Core *core, uint32_t pc)
{
    Breakpoint **link;

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
#define PRINT_STAT(name) printf("%s %" PRId64 " %.4g%%\n", #name, core->stat ## name, \
		(double) core->stat ## name/ core->totalInstructions * 100);

    PRINT_STAT(VectorInst);
    PRINT_STAT(LoadInst);
    PRINT_STAT(StoreInst);
    PRINT_STAT(BranchInst);
    PRINT_STAT(ImmArithInst);
    PRINT_STAT(RegArithInst);

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
            printf(" "); // Align single digit numbers

        printf("s%d %08x ", reg, thread->scalarReg[reg]);
        if (reg % 8 == 7)
            printf("\n");
    }

    printf("s31 %08x\n", thread->currentPc - 4);
    printf("Flags: ");
    if (thread->enableInterrupt)
        printf("I");

    if (thread->enableMmu)
        printf("M");

    if(thread->enableSupervisor)
        printf("S");

    printf("\n\n");
    for (reg = 0; reg < NUM_REGISTERS; reg++)
    {
        if (reg < 10)
            printf(" "); // Align single digit numbers

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

    if (thread->core->enableCosim)
        cosimCheckSetScalarReg(thread->core, thread->currentPc - 4, reg, value);

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

    if (thread->core->enableCosim)
        cosimCheckSetVectorReg(thread->core, thread->currentPc - 4, reg, mask, values);

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
        if (core->threads[threadId].lastSyncLoadAddr == address / CACHE_LINE_LENGTH)
            core->threads[threadId].lastSyncLoadAddr = INVALID_ADDR;
    }
}

// Check if interrupts are enabled and one is pending. If so, dispatch it now.
static void tryToDispatchInterrupts(Thread *thread)
{
    int nextInterruptId;

    if (!thread->enableInterrupt || thread->pendingInterrupts == 0)
        return;

    nextInterruptId = 31 - __builtin_clz(thread->pendingInterrupts);

    // Unlike exceptions, an interrupt saves the PC of the *next* instruction,
    // rather than the current one, but only if a multicycle instruction is
    // not active. Advance the PC here accordingly.
    if (thread->currentSubcycle == 0)
        thread->currentPc += 4;

    raiseTrap(thread, 0, (TrapReason)(TR_INTERRUPT_BASE + nextInterruptId));
    thread->pendingInterrupts &= ~(1 << nextInterruptId);
}

static void raiseTrap(Thread *thread, uint32_t trapAddress, TrapReason reason)
{
    if (thread->core->enableTracing)
    {
        printf("%08x [th %d] trap %d %08x\n", thread->currentPc - 4,
               thread->id, reason, trapAddress);
    }

    // For nested interrupts, push the old saved state into
    // the second save slot.
    thread->trapReason[1] = thread->trapReason[0];
    thread->trapScratchpad0[1] = thread->trapScratchpad0[0];
    thread->trapScratchpad1[1] = thread->trapScratchpad1[0];
    thread->trapPc[1] = thread->trapPc[0];
    thread->trapEnableInterrupt[1] = thread->trapEnableInterrupt[0];
    thread->trapEnableMmu[1] = thread->trapEnableMmu[0];
    thread->trapEnableSupervisor[1] = thread->trapEnableSupervisor[0];
    thread->trapSubcycle[1] = thread->trapSubcycle[0];
    thread->trapAccessAddress[1] = thread->trapAccessAddress[0];

    // Save trap information
    thread->trapReason[0] = reason;
    thread->trapPc[0] = thread->currentPc - 4;
    thread->trapEnableInterrupt[0] = thread->enableInterrupt;
    thread->trapEnableMmu[0] = thread->enableMmu;
    thread->trapEnableSupervisor[0] = thread->enableSupervisor;
    thread->trapSubcycle[0] = thread->currentSubcycle;
    thread->trapAccessAddress[0] = trapAddress;

    // Update thread state
    thread->enableInterrupt = false;
    if (reason == TR_ITLB_MISS || reason == TR_DTLB_MISS)
    {
        thread->currentPc = thread->core->tlbMissHandlerPc;
        thread->enableMmu = false;
    }
    else
        thread->currentPc = thread->core->trapHandlerPc;

    thread->currentSubcycle = 0;
    thread->enableSupervisor = true;
}

static void raiseAccessFault(Thread *thread, uint32_t address, TrapReason reason, bool isLoad)
{
    if (thread->core->stopOnFault || thread->core->trapHandlerPc == 0)
    {
        printf("Invalid %s access thread %d PC %08x address %08x\n",
               isLoad ? "load" : "store",
               thread->id, thread->currentPc - 4, address);
        printThreadRegisters(thread);
        thread->core->crashed = true;
    }
    else
    {
        if (reason == TR_IFETCH_ALIGNNMENT)
            thread->currentPc += 4;

        raiseTrap(thread, address, reason);
    }
}

static void raiseIllegalInstructionFault(Thread *thread, uint32_t instruction)
{
    if (thread->core->stopOnFault || thread->core->trapHandlerPc == 0)
    {
        printf("Illegal instruction %08x thread %d PC %08x\n", instruction, thread->id,
               thread->currentPc - 4);
        printThreadRegisters(thread);
        thread->core->crashed = true;
    }
    else
        raiseTrap(thread, 0, TR_ILLEGAL_INSTRUCTION);
}

// Translate addresses using the translation lookaside buffer. Raise faults
// if necessary.
static bool translateAddress(Thread *thread, uint32_t virtualAddress, uint32_t *outPhysicalAddress,
                             bool dataFetch, bool isWrite)
{
    int tlbSet;
    int way;
    TlbEntry *setEntries;

    if (!thread->enableMmu)
    {
        if (virtualAddress >= thread->core->memorySize && virtualAddress < 0xffff0000)
        {
            // This isn't an actual fault supported by the hardware, but a debugging
            // aid only available in the emulator.
            printf("Memory access out of range %08x, pc %08x (MMU not enabled)\n",
                   virtualAddress, thread->currentPc - 4);
            printThreadRegisters(thread);
            thread->core->crashed = true;
            return false;
        }

        *outPhysicalAddress = virtualAddress;
        return true;
    }

    tlbSet = (virtualAddress / PAGE_SIZE) % TLB_SETS;
    setEntries = (dataFetch ? thread->core->dtlb : thread->core->itlb) + tlbSet * TLB_WAYS;
    for (way = 0; way < TLB_WAYS; way++)
    {
        if (setEntries[way].virtualAddress == ROUND_TO_PAGE(virtualAddress)
                && ((setEntries[way].physAddrAndFlags & TLB_GLOBAL) != 0
                    || setEntries[way].asid == thread->currentAsid))
        {
            if ((setEntries[way].physAddrAndFlags & TLB_PRESENT) == 0)
            {
                raiseTrap(thread, virtualAddress, TR_PAGE_FAULT);
                return false;
            }

            if ((setEntries[way].physAddrAndFlags & TLB_SUPERVISOR) != 0
                    && !thread->enableSupervisor)
            {
                raiseTrap(thread, virtualAddress, dataFetch ? TR_DATA_SUPERVISOR
                          : TR_IFETCH_SUPERVISOR);
                return false;
            }

            if ((setEntries[way].physAddrAndFlags & TLB_EXECUTABLE) == 0
                    && !dataFetch)
            {
                raiseTrap(thread, virtualAddress, TR_NOT_EXECUTABLE);
                return false;
            }

            if (isWrite && (setEntries[way].physAddrAndFlags & TLB_WRITE_ENABLE) == 0)
            {
                raiseAccessFault(thread, virtualAddress, TR_ILLEGAL_WRITE, false);
                return false;
            }

            *outPhysicalAddress = ROUND_TO_PAGE(setEntries[way].physAddrAndFlags)
                                  | PAGE_OFFSET(virtualAddress);

            if (*outPhysicalAddress >= thread->core->memorySize && *outPhysicalAddress < 0xffff0000)
            {
                // This isn't an actual fault supported by the hardware, but a debugging
                // aid only available in the emulator.
                printf("Translated physical address out of range. va %08x pa %08x pc %08x\n",
                       virtualAddress, *outPhysicalAddress, thread->currentPc - 4);
                printThreadRegisters(thread);
                thread->core->crashed = true;
                return false;
            }

            return true;
        }
    }

    // No translation found

    if (dataFetch)
        raiseTrap(thread, virtualAddress, TR_DTLB_MISS);
    else
    {
        thread->currentPc += 4;	// In instruction fetch, hadn't been incremented yet
        raiseTrap(thread, virtualAddress, TR_ITLB_MISS);
    }

    return false;
}

static uint32_t scalarArithmeticOp(ArithmeticOp operation, uint32_t value1, uint32_t value2)
{
    switch (operation)
    {
        case OP_OR:
            return value1 | value2;
        case OP_AND:
            return value1 & value2;
        case OP_XOR:
            return value1 ^ value2;
        case OP_ADD_I:
            return value1 + value2;
        case OP_SUB_I:
            return value1 - value2;
        case OP_MULL_I:
            return value1 * value2;
        case OP_MULH_U:
            return (uint32_t)(((uint64_t)value1 * (uint64_t)value2) >> 32);
        case OP_ASHR:
            return (uint32_t)(((int32_t)value1) >> (value2 & 31));
        case OP_SHR:
            return value1 >> (value2 & 31);
        case OP_SHL:
            return value1 << (value2 & 31);
        case OP_CLZ:
            return value2 == 0 ? 32u : (uint32_t)__builtin_clz(value2);
        case OP_CTZ:
            return value2 == 0 ? 32u : (uint32_t)__builtin_ctz(value2);
        case OP_MOVE:
            return value2;
        case OP_CMPEQ_I:
            return (uint32_t)value1 == value2;
        case OP_CMPNE_I:
            return (uint32_t)value1 != value2;
        case OP_CMPGT_I:
            return (uint32_t)((int32_t)value1 > (int32_t)value2);
        case OP_CMPGE_I:
            return (uint32_t)((int32_t)value1 >= (int32_t)value2);
        case OP_CMPLT_I:
            return (uint32_t)((int32_t)value1 < (int32_t)value2);
        case OP_CMPLE_I:
            return (uint32_t)((int32_t)value1 <= (int32_t)value2);
        case OP_CMPGT_U:
            return (uint32_t)(value1 > value2);
        case OP_CMPGE_U:
            return (uint32_t)(value1 >= value2);
        case OP_CMPLT_U:
            return (uint32_t)(value1 < value2);
        case OP_CMPLE_U:
            return (uint32_t)(value1 <= value2);
        case OP_FTOI:
            return (uint32_t)(int32_t)valueAsFloat(value2);
        case OP_RECIPROCAL:
        {
            // Reciprocal only has 6 bits of accuracy
            float fresult = 1.0f / valueAsFloat(value2 & 0xfffe0000);
            uint32_t iresult = valueAsInt(fresult);
            if (!isnan(fresult))
                iresult &= 0xfffe0000;	// Truncate, but only if not NaN

            return iresult;
        }

        case OP_SEXT8:
            return (uint32_t)(int32_t)(int8_t)value2;
        case OP_SEXT16:
            return (uint32_t)(int32_t)(int16_t)value2;
        case OP_MULH_I:
            return (uint32_t) (((int64_t)(int32_t)value1 * (int64_t)(int32_t)value2) >> 32);
        case OP_ADD_F:
            return valueAsInt(valueAsFloat(value1) + valueAsFloat(value2));
        case OP_SUB_F:
            return valueAsInt(valueAsFloat(value1) - valueAsFloat(value2));
        case OP_MUL_F:
            return valueAsInt(valueAsFloat(value1) * valueAsFloat(value2));
        case OP_ITOF:
            return valueAsInt((float)(int32_t)value2);
        case OP_CMPGT_F:
            return valueAsFloat(value1) > valueAsFloat(value2);
        case OP_CMPGE_F:
            return valueAsFloat(value1) >= valueAsFloat(value2);
        case OP_CMPLT_F:
            return valueAsFloat(value1) < valueAsFloat(value2);
        case OP_CMPLE_F:
            return valueAsFloat(value1) <= valueAsFloat(value2);
        case OP_CMPEQ_F:
            return valueAsFloat(value1) == valueAsFloat(value2);
        case OP_CMPNE_F:
            return valueAsFloat(value1) != valueAsFloat(value2);
        default:
            return 0u;
    }
}

static bool isCompareOp(uint32_t op)
{
    return (op >= OP_CMPEQ_I && op <= OP_CMPLE_U) || (op >= OP_CMPGT_F && op <= OP_CMPNE_F);
}

static Breakpoint *lookupBreakpoint(Core *core, uint32_t pc)
{
    Breakpoint *breakpoint;

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

    if (op == OP_SYSCALL)
    {
        raiseTrap(thread, 0, TR_SYSCALL);
        return;
    }

    TALLY_INSTRUCTION(RegArithInst);
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
                TALLY_INSTRUCTION(VectorInst);

                // Vector/Scalar operation
                // Pack compare results in low 16 bits of scalar register
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
                TALLY_INSTRUCTION(VectorInst);

                // Vector/Vector operation
                // Pack compare results in low 16 bits of scalar register
                for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
                {
                    result >>= 1;
                    result |= scalarArithmeticOp(op, thread->vectorReg[op1reg][lane],
                                                 thread->vectorReg[op2reg][lane]) ? 0x8000 : 0;
                }

                break;

            default:
                raiseIllegalInstructionFault(thread, instruction);
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
        // Vector arithmetic
        uint32_t result[NUM_VECTOR_LANES];
        uint32_t mask;

        TALLY_INSTRUCTION(VectorInst);
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
                raiseIllegalInstructionFault(thread, instruction);
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
            // Vector/Scalar operands
            uint32_t scalarValue = getThreadScalarReg(thread, op2reg);
            for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
            {
                result[lane] = scalarArithmeticOp(op, thread->vectorReg[op1reg][lane],
                                                  scalarValue);
            }
        }
        else
        {
            // Vector/Vector operands
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

    TALLY_INSTRUCTION(ImmArithInst);
    if (hasMask)
        immValue = extractSignedBits(instruction, 15, 8);
    else
        immValue = extractSignedBits(instruction, 10, 13);

    if (op == OP_GETLANE)
    {
        TALLY_INSTRUCTION(VectorInst);
        setScalarReg(thread, destreg, thread->vectorReg[op1reg][NUM_VECTOR_LANES - 1 - (immValue & 0xf)]);
    }
    else if (isCompareOp(op))
    {
        uint32_t result = 0;
        switch (fmt)
        {
            case FMT_IMM_VV:
            case FMT_IMM_VV_M:
                TALLY_INSTRUCTION(VectorInst);

                // Pack compare results into low 16 bits of scalar register
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
                raiseIllegalInstructionFault(thread, instruction);
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
        // Vector arithmetic
        uint32_t result[NUM_VECTOR_LANES];
        uint32_t mask;

        TALLY_INSTRUCTION(VectorInst);
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
                raiseIllegalInstructionFault(thread, instruction);
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
    uint32_t virtualAddress;
    uint32_t physicalAddress;
    int isDeviceAccess;
    uint32_t value;
    uint32_t accessSize;

    virtualAddress = getThreadScalarReg(thread, ptrreg) + offset;

    switch (op)
    {
        case MEM_BYTE:
        case MEM_BYTE_SEXT:
            accessSize = 1;
            break;

        case MEM_SHORT:
        case MEM_SHORT_EXT:
            accessSize = 2;
            break;

        default:
            accessSize = 4;
    }

    // Check alignment
    if ((virtualAddress % accessSize) != 0)
    {
        raiseAccessFault(thread, virtualAddress, TR_DATA_ALIGNMENT, isLoad);
        return;
    }

    if (!translateAddress(thread, virtualAddress, &physicalAddress, true, !isLoad))
        return; // fault raised, bypass other side effects

    isDeviceAccess = (physicalAddress & 0xffff0000) == 0xffff0000;
    if (isDeviceAccess && op != MEM_LONG)
    {
        // This is not an actual CPU fault, but a debugging aid in the emulator.
        printf("%s Invalid device access %08x, pc %08x\n", isLoad ? "Load" : "Store",
               virtualAddress, thread->currentPc - 4);
        printThreadRegisters(thread);
        thread->core->crashed = true;
        return;
    }

    if (isLoad)
    {
        switch (op)
        {
            case MEM_LONG:
                if (isDeviceAccess)
                    value = readDeviceRegister(physicalAddress & 0xffff);
                else
                    value = (uint32_t) *UINT32_PTR(thread->core->memory, physicalAddress);

                break;

            case MEM_BYTE:
                value = (uint32_t) *UINT8_PTR(thread->core->memory, physicalAddress);
                break;

            case MEM_BYTE_SEXT:
                value = (uint32_t)(int32_t) *INT8_PTR(thread->core->memory, physicalAddress);
                break;

            case MEM_SHORT:
                value = (uint32_t) *UINT16_PTR(thread->core->memory, physicalAddress);
                break;

            case MEM_SHORT_EXT:
                value = (uint32_t)(int32_t) *INT16_PTR(thread->core->memory, physicalAddress);
                break;

            case MEM_SYNC:
                value = *UINT32_PTR(thread->core->memory, physicalAddress);
                thread->lastSyncLoadAddr = physicalAddress / CACHE_LINE_LENGTH;
                break;

            case MEM_CONTROL_REG:
                assert(0);	// Should have been handled in caller
                return;

            default:
                raiseIllegalInstructionFault(thread, instruction);
                return;
        }

        setScalarReg(thread, destsrcreg, value);
    }
    else
    {
        // Store
        uint32_t valueToStore = getThreadScalarReg(thread, destsrcreg);

        // Some instruction don't update memory, for example: a synchronized store
        // that fails or writes to device memory. This tracks whether they
        // did for the cosimulation code below.
        bool didWrite = false;
        switch (op)
        {
            case MEM_BYTE:
            case MEM_BYTE_SEXT:
                *UINT8_PTR(thread->core->memory, physicalAddress) = (uint8_t) valueToStore;
                didWrite = true;
                break;

            case MEM_SHORT:
            case MEM_SHORT_EXT:
                *UINT16_PTR(thread->core->memory, physicalAddress) = (uint16_t) valueToStore;
                didWrite = true;
                break;

            case MEM_LONG:
                if ((physicalAddress & 0xffff0000) == 0xffff0000)
                {
                    // IO address range
                    if (physicalAddress == 0xffff0060)
                    {
                        // Thread resume
                        thread->core->threadEnableMask |= valueToStore
                                                          & ((1ull << thread->core->totalThreads) - 1);
                    }
                    else if (physicalAddress == 0xffff0064)
                    {
                        // Thread halt
                        thread->core->threadEnableMask &= ~valueToStore;
                    }
                    else
                        writeDeviceRegister(physicalAddress & 0xffff, valueToStore);

                    // Bail to avoid logging and other side effects below.
                    return;
                }

                *UINT32_PTR(thread->core->memory, physicalAddress) = valueToStore;
                didWrite = true;
                break;

            case MEM_SYNC:
                if (physicalAddress / CACHE_LINE_LENGTH == thread->lastSyncLoadAddr)
                {
                    // Success

                    // HACK: cosim can only track one side effect per instruction, but sync
                    // store has two: setting the register to indicate success and updating
                    // memory. This only logs the memory transaction. Instead of
                    // calling setScalarReg (which would log the register transfer as
                    // a side effect), set the value explicitly here.
                    thread->scalarReg[destsrcreg] = 1;

                    *UINT32_PTR(thread->core->memory, physicalAddress) = valueToStore;
                    didWrite = true;
                }
                else
                    thread->scalarReg[destsrcreg] = 0;	// Fail. Set register manually as above.

                break;

            case MEM_CONTROL_REG:
                assert(0);	// Should have been handled in caller
                return;

            default:
                raiseIllegalInstructionFault(thread, instruction);
                return;
        }

        if (didWrite)
        {
            invalidateSyncAddress(thread->core, physicalAddress);
            if (thread->core->enableTracing)
            {
                printf("%08x [th %d] memory store size %d %08x %02x\n", thread->currentPc - 4,
                       thread->id, accessSize, virtualAddress, valueToStore);
            }

            if (thread->core->enableCosim)
            {
                cosimCheckScalarStore(thread->core, thread->currentPc - 4, virtualAddress, accessSize,
                                      valueToStore);
            }
        }
    }
}

static void executeBlockLoadStoreInst(Thread *thread, uint32_t instruction)
{
    uint32_t op = extractUnsignedBits(instruction, 25, 4);
    uint32_t ptrreg = extractUnsignedBits(instruction, 0, 5);
    uint32_t maskreg = extractUnsignedBits(instruction, 10, 5);
    uint32_t destsrcreg = extractUnsignedBits(instruction, 5, 5);
    bool isLoad = extractUnsignedBits(instruction, 29, 1);
    uint32_t offset;
    uint32_t lane;
    uint32_t mask;
    uint32_t virtualAddress;
    uint32_t physicalAddress;
    uint32_t *blockPtr;

    TALLY_INSTRUCTION(VectorInst);

    // Compute mask value
    switch (op)
    {
        case MEM_BLOCK_VECTOR:
            mask = 0xffff;
            offset = extractSignedBits(instruction, 10, 15);
            break;

        case MEM_BLOCK_VECTOR_MASK:
            mask = getThreadScalarReg(thread, maskreg);
            offset = extractSignedBits(instruction, 15, 10);
            break;

        default:
            assert(0);
    }

    virtualAddress = getThreadScalarReg(thread, ptrreg) + offset;

    // Check alignment
    if ((virtualAddress & (NUM_VECTOR_LANES * 4 - 1)) != 0)
    {
        raiseAccessFault(thread, virtualAddress, TR_DATA_ALIGNMENT, isLoad);
        return;
    }

    if (!translateAddress(thread, virtualAddress, &physicalAddress, true, !isLoad))
        return; // fault raised, bypass other side effects

    blockPtr = UINT32_PTR(thread->core->memory, physicalAddress);
    if (isLoad)
    {
        uint32_t loadValue[NUM_VECTOR_LANES];
        for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
            loadValue[lane] = blockPtr[NUM_VECTOR_LANES - lane - 1];

        setVectorReg(thread, destsrcreg, mask, loadValue);
    }
    else
    {
        uint32_t *storeValue = thread->vectorReg[destsrcreg];

        if ((mask & 0xffff) == 0)
            return;	// Hardware ignores block stores with a mask of zero

        if (thread->core->enableTracing)
        {
            printf("%08x [th %d] writeMemBlock %08x\n", thread->currentPc - 4, thread->id,
                   virtualAddress);
        }

        if (thread->core->enableCosim)
            cosimCheckVectorStore(thread->core, thread->currentPc - 4, virtualAddress, mask, storeValue);

        for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
        {
            uint32_t regIndex = NUM_VECTOR_LANES - lane - 1;
            if (mask & (1 << regIndex))
                blockPtr[lane] = storeValue[regIndex];
        }

        invalidateSyncAddress(thread->core, physicalAddress);
    }
}

static void executeScatterGatherInst(Thread *thread, uint32_t instruction)
{
    uint32_t op = extractUnsignedBits(instruction, 25, 4);
    uint32_t ptrreg = extractUnsignedBits(instruction, 0, 5);
    uint32_t maskreg = extractUnsignedBits(instruction, 10, 5);
    uint32_t destsrcreg = extractUnsignedBits(instruction, 5, 5);
    bool isLoad = extractUnsignedBits(instruction, 29, 1);
    uint32_t offset;
    uint32_t lane;
    uint32_t mask;
    uint32_t virtualAddress;
    uint32_t physicalAddress;

    TALLY_INSTRUCTION(VectorInst);

    // Compute mask value
    switch (op)
    {
        case MEM_SCGATH:
            mask = 0xffff;
            offset = extractSignedBits(instruction, 10, 15);
            break;

        case MEM_SCGATH_MASK:
            mask = getThreadScalarReg(thread, maskreg);
            offset = extractSignedBits(instruction, 15, 10);
            break;

        default:
            assert(0);
    }

    lane = NUM_VECTOR_LANES - 1 - thread->currentSubcycle;
    virtualAddress = thread->vectorReg[ptrreg][lane] + offset;
    if ((mask & (1 << lane)) && (virtualAddress & 3) != 0)
    {
        raiseAccessFault(thread, virtualAddress, TR_DATA_ALIGNMENT, isLoad);
        return;
    }

    if (!translateAddress(thread, virtualAddress, &physicalAddress, true, !isLoad))
        return; // fault raised, bypass other side effects

    if (isLoad)
    {
        uint32_t loadValue[NUM_VECTOR_LANES];
        memset(loadValue, 0, NUM_VECTOR_LANES * sizeof(uint32_t));
        if (mask & (1 << lane))
            loadValue[lane] = *UINT32_PTR(thread->core->memory, physicalAddress);

        setVectorReg(thread, destsrcreg, mask & (1 << lane), loadValue);
    }
    else if (mask & (1 << lane))
    {
        if (thread->core->enableTracing)
        {
            printf("%08x [th %d] storeScatter (%d) %08x %08x\n", thread->currentPc - 4,
                   thread->id, thread->currentSubcycle, virtualAddress,
                   thread->vectorReg[destsrcreg][lane]);
        }

        *UINT32_PTR(thread->core->memory, physicalAddress)
            = thread->vectorReg[destsrcreg][lane];
        invalidateSyncAddress(thread->core, physicalAddress);
        if (thread->core->enableCosim)
        {
            cosimCheckScalarStore(thread->core, thread->currentPc - 4, virtualAddress, 4,
                                  thread->vectorReg[destsrcreg][lane]);
        }
    }

    if (++thread->currentSubcycle == NUM_VECTOR_LANES)
        thread->currentSubcycle = 0; // Finish
    else
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
                value = thread->core->trapHandlerPc;
                break;

            case CR_FAULT_PC:
                value = thread->trapPc[0];
                break;

            case CR_FAULT_REASON:
                value = thread->trapReason[0];
                break;

            case CR_FLAGS:
                value = (thread->enableInterrupt ? 1 : 0)
                        | (thread->enableMmu ? 2 : 0)
                        | (thread->enableSupervisor ? 4 : 0);
                break;

            case CR_SAVED_FLAGS:
                value = (thread->trapEnableInterrupt[0] ? 1 : 0)
                        | (thread->trapEnableMmu[0] ? 2 : 0)
                        | (thread->trapEnableSupervisor[0] ? 4 : 0);
                break;

            case CR_CURRENT_ASID:
                value = thread->currentAsid;
                break;

            case CR_PAGE_DIR:
                value = thread->currentPageDir;
                break;

            case CR_FAULT_ADDRESS:
                value = thread->trapAccessAddress[0];
                break;

            case CR_CYCLE_COUNT:
            {
                // Make clock appear to be running at 50Mhz real time, independent
                // of the instruction rate of the emulator.
                struct timeval tv;
                gettimeofday(&tv, NULL);
                value = (uint32_t)(tv.tv_sec * 50000000 + tv.tv_usec * 50)
                        - thread->core->startCycleCount;
                break;
            }

            case CR_TLB_MISS_HANDLER:
                value = thread->core->tlbMissHandlerPc;
                break;

            case CR_SCRATCHPAD0:
                value = thread->trapScratchpad0[0];
                break;

            case CR_SCRATCHPAD1:
                value = thread->trapScratchpad1[0];
                break;

            case CR_SUBCYCLE:
                value = thread->trapSubcycle[0];
                break;
        }

        setScalarReg(thread, dstSrcReg, value);
    }
    else
    {
        // Only threads in supervisor mode can write control registers.
        if (!thread->enableSupervisor)
        {
            raiseTrap(thread, 0, TR_PRIVILEGED_OP);
            return;
        }

        // Store
        uint32_t value = getThreadScalarReg(thread, dstSrcReg);
        switch (crIndex)
        {
            case CR_FAULT_HANDLER:
                thread->core->trapHandlerPc = value;
                break;

            case CR_FAULT_PC:
                thread->trapPc[0] = value;
                break;

            case CR_FLAGS:
                thread->enableInterrupt = (value & 1) != 0;
                thread->enableMmu = (value & 2) != 0;
                thread->enableSupervisor = (value & 4) != 0;

                // An interrupt may have occurred while interrupts were
                // disabled.
                if (thread->enableInterrupt)
                    tryToDispatchInterrupts(thread);

                break;

            case CR_SAVED_FLAGS:
                thread->trapEnableInterrupt[0] = (value & 1) != 0;
                thread->trapEnableMmu[0] = (value & 2) != 0;
                thread->trapEnableSupervisor[0] = (value & 4) != 0;
                break;

            case CR_CURRENT_ASID:
                thread->currentAsid = value;
                break;

            case CR_PAGE_DIR:
                thread->currentPageDir = value;
                break;

            case CR_TLB_MISS_HANDLER:
                thread->core->tlbMissHandlerPc = value;
                break;

            case CR_SCRATCHPAD0:
                thread->trapScratchpad0[0] = value;
                break;

            case CR_SCRATCHPAD1:
                thread->trapScratchpad1[0] = value;
                break;

            case CR_SUBCYCLE:
                thread->trapSubcycle[0] = value;
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
            TALLY_INSTRUCTION(LoadInst);
        else
            TALLY_INSTRUCTION(StoreInst);
    }

    switch (type)
    {
        case MEM_BYTE:
        case MEM_BYTE_SEXT:
        case MEM_SHORT:
        case MEM_SHORT_EXT:
        case MEM_LONG:
        case MEM_SYNC:
            executeScalarLoadStoreInst(thread, instruction);
            break;

        case MEM_CONTROL_REG:
            executeControlRegisterInst(thread, instruction);
            break;

        case MEM_BLOCK_VECTOR:
        case MEM_BLOCK_VECTOR_MASK:
            executeBlockLoadStoreInst(thread, instruction);
            break;

        case MEM_SCGATH:
        case MEM_SCGATH_MASK:
            executeScatterGatherInst(thread, instruction);
            break;

        default:
            raiseIllegalInstructionFault(thread, instruction);
    }
}

static void executeBranchInst(Thread *thread, uint32_t instruction)
{
    bool branchTaken = false;
    uint32_t srcReg = extractUnsignedBits(instruction, 0, 5);

    TALLY_INSTRUCTION(BranchInst);
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
            return; // Short circuit, since the source register is the dest

        case BRANCH_ERET:
            if (!thread->enableSupervisor)
            {
                raiseTrap(thread, 0, TR_PRIVILEGED_OP);
                return;
            }

            thread->enableInterrupt = thread->trapEnableInterrupt[0];
            thread->enableMmu = thread->trapEnableMmu[0];
            thread->currentPc = thread->trapPc[0];
            thread->currentSubcycle = thread->trapSubcycle[0];
            thread->enableSupervisor = thread->trapEnableSupervisor[0];

            // Restore nested interrupt state
            thread->trapReason[0] = thread->trapReason[1];
            thread->trapScratchpad0[0] = thread->trapScratchpad0[1];
            thread->trapScratchpad1[0] = thread->trapScratchpad1[1];
            thread->trapPc[0] = thread->trapPc[1];
            thread->trapEnableInterrupt[0] = thread->trapEnableInterrupt[1];
            thread->trapEnableMmu[0] = thread->trapEnableMmu[1];
            thread->trapEnableSupervisor[0] = thread->trapEnableSupervisor[1];
            thread->trapSubcycle[0] = thread->trapSubcycle[1];
            thread->trapAccessAddress[0] = thread->trapAccessAddress[1];

            // There may be other interrupts pending
            if (thread->enableInterrupt)
                tryToDispatchInterrupts(thread);

            return; // Short circuit branch side effect below
    }

    if (branchTaken)
        thread->currentPc += extractSignedBits(instruction, 5, 20);
}

static void executeCacheControlInst(Thread *thread, uint32_t instruction)
{
    uint32_t op = extractUnsignedBits(instruction, 25, 3);
    uint32_t ptrReg = extractUnsignedBits(instruction, 0, 5);
    uint32_t way;
    bool updatedEntry;

    switch (op)
    {
        case CC_DINVALIDATE:
            if (!thread->enableSupervisor)
            {
                raiseTrap(thread, 0, TR_PRIVILEGED_OP);
                return;
            }

        // Falls through...

        case CC_DFLUSH:
        {
            // This needs to fault if the TLB entry isn't present. translateAddress
            // will do that as a side effect.
            uint32_t offset = extractSignedBits(instruction, 15, 10);
            uint32_t physicalAddress;
            translateAddress(thread, getThreadScalarReg(thread, ptrReg) + offset,
                             &physicalAddress, true, false);
            break;
        }

        case CC_DTLB_INSERT:
        case CC_ITLB_INSERT:
        {
            uint32_t virtualAddress = ROUND_TO_PAGE(getThreadScalarReg(thread, ptrReg));
            uint32_t physAddrReg = extractUnsignedBits(instruction, 5, 5);
            uint32_t physAddrAndFlags = getThreadScalarReg(thread, physAddrReg);
            uint32_t *wayPtr;
            TlbEntry *tlb;

            if (!thread->enableSupervisor)
            {
                raiseTrap(thread, 0, TR_PRIVILEGED_OP);
                return;
            }

            if (op == CC_DTLB_INSERT)
            {
                tlb = thread->core->dtlb;
                wayPtr = &thread->core->nextDTlbWay;
            }
            else
            {
                tlb = thread->core->itlb;
                wayPtr = &thread->core->nextITlbWay;
            }

            TlbEntry *entry = &tlb[((virtualAddress / PAGE_SIZE) % TLB_SETS) * TLB_WAYS];
            updatedEntry = false;
            for (way = 0; way < TLB_WAYS; way++)
            {
                if (entry[way].virtualAddress == virtualAddress
                        && ((entry[way].physAddrAndFlags & TLB_GLOBAL) != 0
                            || entry[way].asid == thread->currentAsid))
                {
                    // Found existing entry, update it
                    entry[way].physAddrAndFlags = physAddrAndFlags;
                    updatedEntry = true;
                    break;
                }
            }

            if (!updatedEntry)
            {
                // Replace entry with a new one
                entry[*wayPtr].virtualAddress = virtualAddress;
                entry[*wayPtr].physAddrAndFlags = physAddrAndFlags;
                entry[*wayPtr].asid = thread->currentAsid;
            }

            *wayPtr = (*wayPtr + 1) % TLB_WAYS;
            break;
        }

        case CC_INVALIDATE_TLB:
        {
            uint32_t offset = extractSignedBits(instruction, 15, 10);
            uint32_t virtualAddress = ROUND_TO_PAGE(getThreadScalarReg(thread, ptrReg) + offset);
            uint32_t tlbIndex = ((virtualAddress / PAGE_SIZE) % TLB_SETS) * TLB_WAYS;

            for (way = 0; way < TLB_WAYS; way++)
            {
                if (thread->core->itlb[tlbIndex + way].virtualAddress == virtualAddress)
                    thread->core->itlb[tlbIndex + way].virtualAddress = INVALID_ADDR;

                if (thread->core->dtlb[tlbIndex + way].virtualAddress == virtualAddress)
                    thread->core->dtlb[tlbIndex + way].virtualAddress = INVALID_ADDR;
            }

            break;
        }

        case CC_INVALIDATE_TLB_ALL:
        {
            int i;

            for (i = 0; i < TLB_SETS * TLB_WAYS; i++)
            {
                // Set to invalid (unaligned) addresses so these don't match
                thread->core->itlb[i].virtualAddress = INVALID_ADDR;
                thread->core->dtlb[i].virtualAddress = INVALID_ADDR;
            }

            break;
        }
    }
}

// Returns 0 if this hit a breakpoint and should break out of execution
// loop.
static bool executeInstruction(Thread *thread)
{
    uint32_t instruction;
    uint32_t physicalPc;

    // Check PC alignment
    if ((thread->currentPc & 3) != 0)
    {
        raiseAccessFault(thread, thread->currentPc, TR_IFETCH_ALIGNNMENT, true);
        return true;   // XXX if stop on fault was enabled, should return false
    }

    if (!translateAddress(thread, thread->currentPc, &physicalPc, false, false))
        return true;	// On next execution will start in TLB miss handler
                    // XXX if stop on fault was enabled, should return false

    instruction = *UINT32_PTR(thread->core->memory, physicalPc);
    thread->currentPc += 4;
    thread->core->totalInstructions++;

restart:
    if ((instruction & 0xe0000000) == 0xc0000000)
        executeRegisterArithInst(thread, instruction);
    else if ((instruction & 0x80000000) == 0)
    {
        if (instruction == BREAKPOINT_INST)
        {
            Breakpoint *breakpoint = lookupBreakpoint(thread->core, thread->currentPc - 4);
            if (breakpoint == NULL)
            {
                // We use a special instruction to trigger breakpoint lookup
                // as an optimization to avoid doing a lookup on every
                // instruction. In this case, the special instruction was
                // already in the program, so raise a fault.
                thread->currentPc += 4;
                raiseIllegalInstructionFault(thread, instruction);
                return true;
            }

            if (breakpoint->restart || thread->core->singleStepping)
            {
                breakpoint->restart = false;
                instruction = breakpoint->originalInstruction;
                assert(instruction != BREAKPOINT_INST);
                goto restart;
            }
            else
            {
                // Hit a breakpoint
                breakpoint->restart = true;
                return false;
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
        executeCacheControlInst(thread, instruction);
    else
        printf("Bad instruction @%08x\n", thread->currentPc - 4);

    return true;
}
