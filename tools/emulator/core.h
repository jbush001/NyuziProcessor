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

typedef struct Core Core;

Core *initCore(size_t memsize, int totalThreads, int randomizeMemory);
void enableTracing(Core *core);
int loadHexFile(Core *core, const char *filename);
void writeMemoryToFile(const Core *core, const char *filename, uint32_t baseAddress, 
	size_t length);
void *getCoreFb(Core*);
void printRegisters(const Core *core, int threadId);
void enableCosim(Core *core, int enable);
void cosimInterrupt(Core *core, int threadId, uint32_t pc);
int getTotalThreads(const Core *core);
int coreHalted(const Core *core);

//
// Returns: 
//  0 - This stopped when it hit a breakpoint
//  1 - Ran the full number of instructions passed
//
// threadId of -1 means run all threads in a round robin fashion. 
// Otherwise, run just the indicated thread.
//
int executeInstructions(Core*, int threadId, int instructions);

void singleStep(Core*, int threadId);
uint32_t getPc(const Core*, int threadId);
uint32_t getScalarRegister(const Core*, int threadId, int index);
uint32_t getVectorRegister(const Core*, int threadId, int index, int lane);
uint32_t readMemoryByte(const Core*, uint32_t addr);
void setBreakpoint(Core*, uint32_t pc);
void clearBreakpoint(Core*, uint32_t pc);
void forEachBreakpoint(const Core*, void (*callback)(uint32_t pc));
void setStopOnFault(Core*, int stopOnFault);

#endif
