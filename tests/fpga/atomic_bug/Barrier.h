#ifndef __BARRIER_H
#define __BARRIER_H

//
// Each thread that calls wait() will wait until all threads have called it.
// At that point, they are all released.
//

#include "sseg.h"

template <int NUM_THREADS>
class Barrier
{
public:
	Barrier()
		:	fWaitCount(0)
	{
	}
	
	// This assumes all threads will be able to exit wait before another calls it
	// If that wasn't the case, this would livelock.
	void wait()
	{
		int myCount = __sync_add_and_fetch(&fWaitCount, 1);
		kLedRegBase[__builtin_vp_get_current_strand()] = myCount;
		if (myCount == NUM_THREADS)
			fWaitCount = 0;
		else
		{
			int maxWait = 25;
			while (fWaitCount)
			{
				if (maxWait-- == 0)
					asm("setcr s0, 29");	// HALT
			}
		}
	}

private:
	volatile int fWaitCount;
};

#endif
