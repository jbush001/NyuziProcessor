#ifndef __INTERP_H
#define __INTERP_H

#define NUM_REGISTERS 32
#define NUM_VECTOR_LANES 16

typedef struct Core Core;

Core *initCore();
int loadImage(Core *core, const char *filename);

//
// Returns: 
//  0 - This stopped when it hit a breakpoint
//  1 - If this quantum ran completely
//
int runQuantum(Core*);
void stepInto(Core*);
void stepOver(Core*);
void stepReturn(Core*);
unsigned int getPc(Core*);
int getScalarRegister(Core*, int index);
int getVectorRegister(Core*, int index, int lane);
int readMemoryByte(Core*, unsigned int addr);
void setBreakpoint(Core*, unsigned int pc);
void clearBreakpoint(Core*, unsigned int pc);

#endif
