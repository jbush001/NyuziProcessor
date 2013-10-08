#include "Fiber.h"
#include "utils.h"
#include "Debug.h"

const int kDefaultStackSize = 2048;	// Num words

extern "C" void context_switch(unsigned int **saveOldSp, unsigned int *newSp);

void Fiber::switchTo()
{	
	Fiber *fromFiber = currentFiber();
	HardwareThread::currentThread()->fCurrentFiber = this;
	context_switch(&fromFiber->fStackPointer, fStackPointer);
}

Fiber *Fiber::spawnFiber(void (*startFunction)())
{
	Fiber *newFiber = new Fiber;
	newFiber->fStackBase = static_cast<unsigned int*>(allocMem(kDefaultStackSize 
		* sizeof(int)));

	// This assumes the format defined in context_switch.s
	newFiber->fStackPointer = newFiber->fStackBase + kDefaultStackSize - 272;
	newFiber->fStackPointer[14] = reinterpret_cast<unsigned int>(startFunction);
		// Set link pointer

	return newFiber;
}

void Fiber::initSelf()
{
	Fiber *thisFiber = new Fiber;
	HardwareThread::currentThread()->fCurrentFiber = thisFiber;
}




