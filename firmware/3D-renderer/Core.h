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

class Core
{
public:
	inline static Core *current();

	static void reschedule();
	void addFiber(Fiber *);

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
