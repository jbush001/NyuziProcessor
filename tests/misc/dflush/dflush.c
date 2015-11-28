//
// Copyright 2011-2015 Jeff Bush
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

#include <stdint.h>

const int kNumThreads = 4;
veci16_t * const regionBase = (veci16_t*) 0x400000;
const int kFillCount = 4096;
volatile int gEndSync = kNumThreads;

int main()
{
	int myThreadId = __builtin_nyuzi_read_control_reg(0);
	if (myThreadId == 0)
	{
		// Start worker threads
		*((unsigned int*) 0xffff0060) = (1 << kNumThreads) - 1;
	}

	for (int i = myThreadId; i < kFillCount; i += kNumThreads)
	{
		regionBase[i] = __builtin_nyuzi_makevectori(0x1f0e6231 + i);
		asm("dflush %0" : : "s" (regionBase + i));
	}

	__sync_fetch_and_add(&gEndSync, -1);
	while (gEndSync)
		;

	return 0;
}
