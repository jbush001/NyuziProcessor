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
