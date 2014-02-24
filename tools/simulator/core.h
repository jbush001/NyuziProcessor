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

#ifndef __INTERP_H
#define __INTERP_H

#define NUM_REGISTERS 32
#define NUM_VECTOR_LANES 16

typedef struct Core Core;

Core *initCore(int memsize);
void enableTracing(Core *core);
int loadHexFile(Core *core, const char *filename);
void writeMemoryToFile(Core *core, const char *filename, unsigned int baseAddress, 
	int length);
int getTotalInstructionCount(const Core *core);
void *getCoreFb(Core*);

//
// Returns: 
//  0 - This stopped when it hit a breakpoint
//  1 - If this quantum ran completely
//
int runQuantum(Core*, int instructions);
void singleStep(Core*);
unsigned int getPc(Core*);
void setCurrentStrand(Core*, int);
int getCurrentStrand(Core*);
int getScalarRegister(Core*, int index);
int getVectorRegister(Core*, int index, int lane);
int readMemoryByte(Core*, unsigned int addr);
void setBreakpoint(Core*, unsigned int pc);
void clearBreakpoint(Core*, unsigned int pc);
void forEachBreakpoint(Core*, void (*callback)(unsigned int pc));

// Co-simulation
int cosimMemoryStore(Core *core, int strandId, unsigned int pc, unsigned int address, 
	unsigned long long int mask, const unsigned int values[16]);
int cosimVectorWriteback(Core *core, int strandId, unsigned int pc, int reg, unsigned int mask, 
	const unsigned int values[16]);
int cosimScalarWriteback(Core *core, int strandId, unsigned int pc, int reg, unsigned int value);
int cosimHalt(Core *core);

#endif
