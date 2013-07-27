#ifndef __BARRIER_H
#define __BARRIER_H

//
// Each thread that calls wait() will wait until all threads have called it.
// At that point, they are all released.
//

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
		if (__sync_add_and_fetch(&fWaitCount, 1) == NUM_THREADS)
			fWaitCount = 0;
		else
		{
			while (fWaitCount)
				;	// Wait busily
		}
	}

private:
	volatile int fWaitCount;
};

#endif
