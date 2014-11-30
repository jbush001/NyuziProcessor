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

#ifndef __CORE_H
#define __CORE_H

#define NUM_REGISTERS 32
#define NUM_VECTOR_LANES 16
#define THREADS_PER_CORE 4

typedef struct Core Core;

Core *initCore(int memsize);
void enableTracing(Core *core);
int loadHexFile(Core *core, const char *filename);
void writeMemoryToFile(Core *core, const char *filename, unsigned int baseAddress, 
	size_t length);
void *getCoreFb(Core*);

//
// Returns: 
//  0 - This stopped when it hit a breakpoint
//  1 - If this quantum ran completely
//
// threadId of -1 means run all threads.  Otherwise, run just the
// indicated thread.
//
int runQuantum(Core*, int threadId, int instructions);
void singleStep(Core*, int threadId);
unsigned int getPc(Core*, int threadId);
int getScalarRegister(Core*, int threadId, int index);
int getVectorRegister(Core*, int threadId, int index, int lane);
int readMemoryByte(Core*, unsigned int addr);
void setBreakpoint(Core*, unsigned int pc);
void clearBreakpoint(Core*, unsigned int pc);
void forEachBreakpoint(Core*, void (*callback)(unsigned int pc));
void setStopOnFault(Core*, int stopOnFault);

// Co-simulation
int cosimMemoryStore(Core *core, int threadId, unsigned int pc, unsigned int address, 
	unsigned long long int mask, const unsigned int values[16]);
int cosimVectorWriteback(Core *core, int threadId, unsigned int pc, int reg, unsigned int mask, 
	const unsigned int values[16]);
int cosimScalarWriteback(Core *core, int threadId, unsigned int pc, int reg, unsigned int value);
int cosimHalt(Core *core);
void cosimInterrupt(Core *core, int threadId, unsigned int pc);

#endif
