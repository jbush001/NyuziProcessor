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

#ifndef __FIBER_QUEUE_H
#define __FIBER_QUEUE_H

#include "Fiber.h"

class FiberQueue
{
public:
	FiberQueue()
		:	fHead(0),
			fTail(0)
	{}
	
	void enqueue(Fiber *fiber)
	{
		if (fTail)
		{
			fTail->fQueueNext = fiber;
			fTail = fiber;
		}
		else
			fHead = fTail = fiber;
	}
	
	Fiber *dequeue()
	{
		Fiber *next = fHead;
		if (next)
		{
			fHead = fHead->fQueueNext;
			if (fHead == 0)
				fTail = 0;
		}
		
		return next;
	}

private:
	Fiber *fHead;
	Fiber *fTail;
};


#endif
