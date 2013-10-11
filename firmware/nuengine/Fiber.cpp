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

#include "assert.h"
#include "Fiber.h"
#include "utils.h"
#include "Debug.h"

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
	current()->run();
}

void Fiber::initSelf()
{
	assert(current() == 0);
	Fiber *thisFiber = new Fiber;
	HardwareThread::currentThread()->fCurrentFiber = thisFiber;
}

void Fiber::switchTo()
{	
	Fiber *fromFiber = current();
	if (fromFiber == this)
		return;

	HardwareThread::currentThread()->fCurrentFiber = this;
	context_switch(&fromFiber->fStackPointer, fStackPointer);
}
