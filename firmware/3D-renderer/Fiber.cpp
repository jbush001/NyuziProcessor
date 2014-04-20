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


#include "assert.h"
#include "Fiber.h"
#include "utils.h"
#include "Debug.h"
#include "Core.h"

using namespace runtime;

extern "C" void context_switch(unsigned int **saveOldSp, unsigned int *newSp);

Fiber::Fiber(int stackSize)
{
	fStackBase = static_cast<unsigned int*>(allocMem(stackSize 
		* sizeof(int)));

	// This assumes the frame format defined in context_switch.s
	fStackPointer = fStackBase + stackSize - (448 / 4);

	// Set link pointer
	fStackPointer[5] = reinterpret_cast<unsigned int>(startFunc);
}

void Fiber::startFunc()
{
	Core::current()->fReadyQueueLock.release();
	current()->run();
}

void Fiber::initSelf()
{
	assert(current() == 0);
	Fiber *thisFiber = new Fiber;
	Core::current()->fCurrentFiber[__builtin_vp_get_current_strand() % 
		kHardwareThreadsPerCore] = thisFiber;
}

void Fiber::switchTo()
{	
	Fiber *fromFiber = current();
	if (fromFiber == this)
		return;

	Core::current()->fCurrentFiber[__builtin_vp_get_current_strand() % 
		kHardwareThreadsPerCore] = this;
	context_switch(&fromFiber->fStackPointer, fStackPointer);
}

Fiber *Fiber::current()
{
	return Core::current()->fCurrentFiber[__builtin_vp_get_current_strand() 
		% kHardwareThreadsPerCore];
}

