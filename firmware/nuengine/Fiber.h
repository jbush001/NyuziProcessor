#ifndef __FIBER_H
#define __FIBER_H

#include "HardwareThread.h"

class Fiber
{
public:
	void switchTo();
	static Fiber *spawnFiber(void (*startFunction)());
	static inline Fiber *currentFiber();
	static void initSelf();

private:
	Fiber() {}

	unsigned int *fStackPointer;
	unsigned int *fStackBase;	
};

inline Fiber *Fiber::currentFiber()
{
	return HardwareThread::currentThread()->fCurrentFiber;
}

#endif
