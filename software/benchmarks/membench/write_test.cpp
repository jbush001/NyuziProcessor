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

	veci16 *dest = (veci16*) region1Base + __builtin_nyuzi_read_control_reg(0) * LOOP_UNROLL;
	const veci16 values = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 11, 14, 15 };
	
	int transferCount = kTransferSize / (64 * NUM_THREADS * LOOP_UNROLL);
	do
	{
		dest[0] = values;
		dest[1] = values;
		dest[2] = values;
		dest[3] = values;
		dest[4] = values;
		dest[5] = values;
		dest[6] = values;
		dest[7] = values;
		dest[8] = values;
		dest[9] = values;
		dest[10] = values;
		dest[11] = values;
		dest[12] = values;
		dest[13] = values;
		dest[14] = values;
		dest[15] = values;
		dest += NUM_THREADS * LOOP_UNROLL;
	}
	while (--transferCount);
}
