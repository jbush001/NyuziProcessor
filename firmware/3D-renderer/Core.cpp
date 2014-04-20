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


#include "Core.h"
#include "Fiber.h"

using namespace runtime;

Core Core::sCores[kNumCores];

void Core::reschedule()
{
	Core *currentCore = Core::current();
	Fiber *currentFiber = Fiber::current();
	currentCore->fReadyQueueLock.acquire();
	Fiber *nextFiber = currentCore->fReadyQueue.dequeue();
	currentCore->fReadyQueue.enqueue(currentFiber);
	nextFiber->switchTo();
	currentCore->fReadyQueueLock.release();
}

void Core::addFiber(Fiber *newFiber)
{
	fReadyQueueLock.acquire();
	fReadyQueue.enqueue(newFiber);
	fReadyQueueLock.release();
}
