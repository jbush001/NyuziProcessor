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


#ifndef __CORE_H
#define __CORE_H

#include "Fiber.h"
#include "Spinlock.h"
#include "FiberQueue.h"

namespace runtime
{

const int kNumCores = 1;
const int kHardwareThreadsPerCore = 4;

//
// Core represents a single execution pipeline, which has some number of hardware
// threads. Fibers represent software thread contexts.  Each running fiber must
// be bound to a hardware thread, but ready (non-running) fibers are in a single
// ready queue, shared per core.  Fibers are bound to a core for their lifetime
// for simplicity and to improve L1 cache utilization.
// The main purpose of fibers is to allow switching to other jobs while a thread 
// is waiting on long latency device accesses through memory mapped IO space. The 
// hardware threads cover smaller latencies due to cache misses and RAW dependencies
// for floating point operations.
//
// Since there aren't currently any memory mapped devices used by this program runtime, 
// there is only one fiber per thread right now.
//

class Core
{
public:
	// Return the core that the calling fiber is running on.
	inline static Core *current();

	// Pick a fiber from the ready queue and context switch to it.
	static void reschedule();

	// Put a new fiber into the ready queue.
	void addFiber(Fiber*);
	
	static inline int currentStrandId() 
	{
		return __builtin_vp_read_control_reg(0);
	}

private:
	friend class Fiber;

	static Core sCores[kNumCores];
	Fiber *fCurrentFiber[kHardwareThreadsPerCore];
	Spinlock fReadyQueueLock;
	FiberQueue fReadyQueue;
};

inline Core *Core::current()
{
	return &sCores[currentStrandId() / kHardwareThreadsPerCore];
}

}

#endif
