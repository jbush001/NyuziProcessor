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


#ifndef __FIBER_H
#define __FIBER_H

namespace runtime
{

//
// A fiber represents a software execution context, which is described more fully in Core.h.
// Fiber may be overridden to create new tasks.
//
class Fiber
{
public:
	// Thread execution starts in this function. Subclasses override this function and put
	// their specific jobs here. 
	virtual void run() {};

	// Return which fiber is calling this function.
	static Fiber *current();

	// Context switch from the currently running fiber to this one.
	void switchTo();

	// All hardware threads must call this on startup to initialize the
	// data structure.
	static void initSelf();

protected:
	Fiber(int stackSize);

private:
	Fiber()
		:	fStackPointer(0),
			fStackBase(0),
			fQueueNext(0)
	{}

	static void startFunc();

	friend class FiberQueue;

	unsigned int *fStackPointer;
	unsigned int *fStackBase;	
	Fiber *fQueueNext;
};

}

#endif
