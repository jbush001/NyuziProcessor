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
