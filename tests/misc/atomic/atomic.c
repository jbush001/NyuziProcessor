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

const int kNumSlots = 512;
volatile int gIndex;
volatile int *gSlots = (volatile int*) 0x100000;
const int kNumThreads = 4;

int main()
{
	__builtin_nyuzi_write_control_reg(30, (1 << kNumThreads) - 1);	// Start other threads

	const int kTotalIncrements = kNumSlots * 10;
	while (1)
	{
		int mySlot = __sync_fetch_and_add(&gIndex, 1);
		if (mySlot >= kTotalIncrements)
			break;
		
		__sync_fetch_and_add(&gSlots[mySlot % kNumSlots], 1);
	}
	
	__sync_synchronize();

	return 0;
}
