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

#include <libc.h>
#include "Core.h"

namespace runtime
{

//
// Each thread that calls wait() will wait until all threads have called it.
// At that point, they are all released.
//
	
class Barrier
{
public:
	Barrier()
		:	fWaitCount(0)
	{
	}
	
	void wait()
	{
		if (__sync_add_and_fetch(&fWaitCount, 1) == kHardwareThreadsPerCore * kNumCores)
		{
			// We only suspend threads on a single core configuration, since there 
			// currently isn't the ability to wake threads on other cores.
			int mask = (1 << (kHardwareThreadsPerCore * kNumCores)) - 1;
			if (kNumCores == 1)
			{

				// This is the last thread into the barrer.
				// Wait until other threads have fully suspended so they don't
				// miss the wakeup signal.
				while (true)
				{
					int activeThreads = __builtin_nyuzi_read_control_reg(30) & mask;
					if ((activeThreads & (activeThreads - 1)) == 0)
						break;	// Everyone else has halted
				}
			}

			// Wake everyone up
			fWaitCount = 0;

			if (kNumCores == 1)
				__builtin_nyuzi_write_control_reg(30, mask);
		}
		else
		{
			// Suspend this thread. 
			if (kNumCores == 1)
				__builtin_nyuzi_write_control_reg(29, 0);

			while (fWaitCount)
				;
		}
	}

private:
	volatile int fWaitCount;
};

}

#endif
