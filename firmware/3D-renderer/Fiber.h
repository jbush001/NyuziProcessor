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

namespace runtime
{

class Fiber
{
public:
	virtual void run() {};

	static Fiber *current();

	void switchTo();

	// All hardware threads must call this on startup to initialize a 
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
