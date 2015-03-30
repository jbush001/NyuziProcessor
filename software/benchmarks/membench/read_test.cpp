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
veci16 gSum;

// All threads start here
int main()
{
	__builtin_nyuzi_write_control_reg(30, (1 << NUM_THREADS) - 1);	// Start other threads

	veci16 *src = (veci16*) region1Base + __builtin_nyuzi_read_control_reg(0) * LOOP_UNROLL;
	veci16 sum;
		
	int transferCount = kTransferSize / (64 * NUM_THREADS * LOOP_UNROLL);
	do
	{
		sum += src[0];
		sum += src[1];
		sum += src[2];
		sum += src[3];
		sum += src[4];
		sum += src[5];
		sum += src[6];
		sum += src[7];
		src += NUM_THREADS * LOOP_UNROLL;
	}
	while (--transferCount);
	
	gSum = sum;
}

