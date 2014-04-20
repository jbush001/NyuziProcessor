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


#ifndef __FIBER_QUEUE_H
#define __FIBER_QUEUE_H

#include "Fiber.h"

namespace runtime
{

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

}

#endif
