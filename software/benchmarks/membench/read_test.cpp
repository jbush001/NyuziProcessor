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


#define NUM_THREADS 4
#define LOOP_UNROLL 16

typedef int veci16 __attribute__((__vector_size__(16 * sizeof(int))));

const int kTransferSize = 0x100000;
void * const region1Base = (void*) 0x200000;

// All threads start here
int main()
{
	__builtin_nyuzi_write_control_reg(30, (1 << NUM_THREADS) - 1);	// Start other threads

	// Because src is volatile, the loads below will not be optimized away
	volatile veci16 *src = (veci16*) region1Base + __builtin_nyuzi_read_control_reg(0) * LOOP_UNROLL;
	veci16 result;
		
	int transferCount = kTransferSize / (64 * NUM_THREADS * LOOP_UNROLL);
	do
	{
		result = src[0];
		result = src[1];
		result = src[2];
		result = src[3];
		result = src[4];
		result = src[5];
		result = src[6];
		result = src[7];
		result = src[8];
		result = src[9];
		result = src[10];
		result = src[11];
		result = src[12];
		result = src[13];
		result = src[14];
		result = src[15];
		src += NUM_THREADS * LOOP_UNROLL;
	}
	while (--transferCount);
}

