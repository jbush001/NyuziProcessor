// 
// Copyright 2013 Jeff Bush
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

private:
	friend class Fiber;

	static Core sCores[kNumCores];
	Fiber *fCurrentFiber[kHardwareThreadsPerCore];
	Spinlock fReadyQueueLock;
	FiberQueue fReadyQueue;
};

inline Core *Core::current()
{
	return &sCores[__builtin_vp_get_current_strand() / kHardwareThreadsPerCore];
}

}

#endif
