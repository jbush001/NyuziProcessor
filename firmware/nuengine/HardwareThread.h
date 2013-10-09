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

#ifndef __HARDWARE_THREAD_H
#define __HARDWARE_THREAD_H

const int kMaxThreads = 4;

class Fiber;

class HardwareThread
{
public:
	static inline HardwareThread *currentThread();

private:
	friend class Fiber;

	static HardwareThread sThreads[kMaxThreads];
	Fiber *fCurrentFiber;
};


inline HardwareThread *HardwareThread::currentThread()
{
	return &sThreads[__builtin_vp_get_current_strand()];
}

#endif
