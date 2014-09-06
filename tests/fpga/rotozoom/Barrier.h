// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
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
