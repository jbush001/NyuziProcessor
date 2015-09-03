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

#include <stdint.h>

#define NUM_REGISTERS 32
#define NUM_VECTOR_LANES 16
#define ALL_THREADS 0xffffffff

typedef struct Core Core;

Core *initCore(uint32_t memsize, uint32_t totalThreads, uint32_t randomizeMemory);
void enableTracing(Core *core);
int loadHexFile(Core *core, const char *filename);
void writeMemoryToFile(const Core *core, const char *filename, uint32_t baseAddress, 
	uint32_t length);
void *getCoreFb(Core*);
void printRegisters(const Core *core, uint32_t threadId);
void enableCosimulation(Core *core, uint32_t enable);
void cosimInterrupt(Core *core, uint32_t threadId, uint32_t pc);
uint32_t getTotalThreads(const Core *core);
int coreHalted(const Core *core);

//
// Returns: 
//  0 - This stopped when it hit a breakpoint
//  1 - Ran the full number of instructions passed
//
// threadId of ALL_THREADS means run all threads in a round robin fashion. 
// Otherwise, run just the indicated thread.
//
uint32_t executeInstructions(Core*, uint32_t threadId, uint32_t instructions);

void singleStep(Core*, uint32_t threadId);
uint32_t getPc(const Core*, uint32_t threadId);
uint32_t getScalarRegister(const Core*, uint32_t threadId, uint32_t index);
uint32_t getVectorRegister(const Core*, uint32_t threadId, uint32_t index, uint32_t lane);
uint32_t readMemoryByte(const Core*, uint32_t addr);
void writeMemoryByte(const Core*, uint32_t addr, uint8_t byte);
void setBreakpoint(Core*, uint32_t pc);
void clearBreakpoint(Core*, uint32_t pc);
void forEachBreakpoint(const Core*, void (*callback)(uint32_t pc));
void setStopOnFault(Core*, uint32_t stopOnFault);

#endif
