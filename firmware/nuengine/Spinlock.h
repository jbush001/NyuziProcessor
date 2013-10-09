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

#ifndef __SPINLOCK_H
#define __SPINLOCK_H

class Spinlock
{
public:
	Spinlock()
		:	fFlag(0)
	{}
	
	void acquire()
	{
		while (fFlag != 0 || __sync_fetch_and_or(&fFlag, 1) != 0)
			;
	}
	
	void release()
	{
		fFlag = 0;
	}

private:
	volatile int fFlag;
};

#endif
