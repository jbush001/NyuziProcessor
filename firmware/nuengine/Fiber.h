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

#ifndef __FIBER_H
#define __FIBER_H

#include "HardwareThread.h"

class Fiber
{
public:
	Fiber(void (*startFunction)());
	void switchTo();
	static Fiber *spawnFiber(void (*startFunction)());
	static inline Fiber *current();
	static void initSelf();

private:
	Fiber()
		:	fStackPointer(0),
			fStackBase(0),
			fQueueNext(0)
	{}

	friend class FiberQueue;

	unsigned int *fStackPointer;
	unsigned int *fStackBase;	
	Fiber *fQueueNext;
};

inline Fiber *Fiber::current()
{
	return HardwareThread::currentThread()->fCurrentFiber;
}

#endif
