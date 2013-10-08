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

#include "Fiber.h"
#include "utils.h"
#include "Debug.h"

const int kDefaultStackSize = 2048;	// Num words

extern "C" void context_switch(unsigned int **saveOldSp, unsigned int *newSp);

Fiber::Fiber(void (*startFunction)())
{
	fStackBase = static_cast<unsigned int*>(allocMem(kDefaultStackSize 
		* sizeof(int)));

	// This assumes the frame format defined in context_switch.s
	fStackPointer = fStackBase + kDefaultStackSize - 272;

	// Set link pointer
	fStackPointer[14] = reinterpret_cast<unsigned int>(startFunction);
}

void Fiber::switchTo()
{	
	Fiber *fromFiber = current();
	if (fromFiber == this)
		return;
		
	HardwareThread::currentThread()->fCurrentFiber = this;
	context_switch(&fromFiber->fStackPointer, fStackPointer);
}

void Fiber::initSelf()
{
	Fiber *thisFiber = new Fiber;
	HardwareThread::currentThread()->fCurrentFiber = thisFiber;
}




