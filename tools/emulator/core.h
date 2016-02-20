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

#ifndef __CORE_H
#define __CORE_H

#include <stdbool.h>
#include <stdint.h>

#define NUM_REGISTERS 32
#define NUM_VECTOR_LANES 16
#define ALL_THREADS 0xffffffff
#define CACHE_LINE_LENGTH 64u
#define CACHE_LINE_MASK (CACHE_LINE_LENGTH - 1)

typedef struct Core Core;

Core *initCore(uint32_t memsize, uint32_t totalThreads, bool randomizeMemory,
               const char *sharedMemoryFile);
void enableTracing(Core*);
int loadHexFile(Core*, const char *filename);
void writeMemoryToFile(const Core*, const char *filename, uint32_t baseAddress,
                       uint32_t length);
const void *getMemoryRegionPtr(const Core*, uint32_t address, uint32_t length);
void printRegisters(const Core*, uint32_t threadId);
void enableCosimulation(Core*);
void cosimInterrupt(Core*, uint32_t threadId, uint32_t pc);
uint32_t getTotalThreads(const Core*);
bool coreHalted(const Core*);
bool stoppedOnFault(const Core*);

// Return false if this hit a breakpoint or crashed
// threadId of ALL_THREADS means run all threads in a round robin fashion.
// Otherwise, run just the indicated thread.
bool executeInstructions(Core*, uint32_t threadId, uint64_t instructions);

void singleStep(Core*, uint32_t threadId);
uint32_t getPc(const Core*, uint32_t threadId);
uint32_t getScalarRegister(const Core*, uint32_t threadId, uint32_t regId);
uint32_t getVectorRegister(const Core*, uint32_t threadId, uint32_t regId, uint32_t lane);
uint32_t debugReadMemoryByte(const Core*, uint32_t addr);
void debugWriteMemoryByte(const Core*, uint32_t addr, uint8_t byte);
int setBreakpoint(Core*, uint32_t pc);
int clearBreakpoint(Core*, uint32_t pc);
void setStopOnFault(Core*, bool stopOnFault);

void dumpInstructionStats(Core*);

#endif
