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
#define LOOP_UNROLL 8

typedef int veci16 __attribute__((__vector_size__(16 * sizeof(int))));

const int kTransferSize = 0x100000;
void * const region1Base = (void*) 0x200000;
void * const region2Base = (void*) 0x300000;

// All threads start here
int main()
{
	__builtin_nyuzi_write_control_reg(30, (1 << NUM_THREADS) - 1);	// Start other threads

	veci16 *dest = (veci16*) region1Base + __builtin_nyuzi_read_control_reg(0) * LOOP_UNROLL;
	veci16 *src = (veci16*) region2Base + __builtin_nyuzi_read_control_reg(0) * LOOP_UNROLL;
	veci16 values = __builtin_nyuzi_makevectori(0xdeadbeef);
	int transferCount = kTransferSize / (64 * NUM_THREADS * LOOP_UNROLL);
	do
	{
		dest[0] = src[0];
		dest[1] = src[1];
		dest[2] = src[2];
		dest[3] = src[3];
		dest[4] = src[4];
		dest[5] = src[5];
		dest[6] = src[6];
		dest[7] = src[7];
		dest += NUM_THREADS * LOOP_UNROLL;
		src += NUM_THREADS * LOOP_UNROLL;
	}
	while (--transferCount);
}
