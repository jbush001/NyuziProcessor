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

//
// This benchmark tests raw memory transfer speeds for reads, writes, and copies.
// It attempts to saturate the memory interface by using vector wide transfers and
// splitting the copy between multiple hardware threads to hide memory latency.
//

#include <stdint.h>
#include <stdio.h>

#define NUM_THREADS 4
#define LOOP_UNROLL 16

const int kTransferSize = 0x200000;
void * const region1Base = (void*) 0x200000;
void * const region2Base = (void*) (0x200000 + kTransferSize);

int currentThread()
{
	return __builtin_nyuzi_read_control_reg(0);
}

void startParallel()
{
	__builtin_nyuzi_write_control_reg(30, (1 << NUM_THREADS) - 1);
}

void endParallel()
{
	if (currentThread() == 0)
	{
		while (__builtin_nyuzi_read_control_reg(30) != 1)
			;
	}
	else
	{
		asm("setcr s0, 29");
	}
}

int getTime()
{
	return __builtin_nyuzi_read_control_reg(6);
}

void copyTest()
{
	veci16_t *dest = (veci16_t*) region1Base + currentThread() * LOOP_UNROLL;
	veci16_t *src = (veci16_t*) region2Base + currentThread() * LOOP_UNROLL;
	veci16_t values = __builtin_nyuzi_makevectori(0xdeadbeef);
	int transferCount = kTransferSize / (64 * NUM_THREADS * LOOP_UNROLL);
	int unrollCount;

	int startTime = getTime();
	startParallel();
	do
	{
		// The compiler will automatically unroll this
		for (unrollCount = 0; unrollCount < LOOP_UNROLL; unrollCount++)
			dest[unrollCount] = src[unrollCount];

		dest += NUM_THREADS * LOOP_UNROLL;
		src += NUM_THREADS * LOOP_UNROLL;
	}
	while (--transferCount);
	endParallel();
	if (currentThread() == 0)
	{
		int endTime = getTime();
		printf("copy: %g bytes/cycle\n", (float) kTransferSize / (endTime - startTime));
	}
}

void readTest()
{
	// Because src is volatile, the loads below will not be optimized away
	volatile veci16_t *src = (veci16_t*) region1Base + currentThread() * LOOP_UNROLL;
	veci16_t result;
	int transferCount = kTransferSize / (64 * NUM_THREADS * LOOP_UNROLL);
	int unrollCount;

	int startTime = getTime();
	startParallel();
	do
	{
		// The compiler will automatically unroll this
		for (unrollCount = 0; unrollCount < LOOP_UNROLL; unrollCount++)
			result = src[unrollCount];

		src += NUM_THREADS * LOOP_UNROLL;
	}
	while (--transferCount);
	endParallel();
	if (currentThread() == 0)
	{
		int endTime = getTime();
		printf("read: %g bytes/cycle\n", (float) kTransferSize / (endTime - startTime));
	}
}

void writeTest()
{
	veci16_t *dest = (veci16_t*) region1Base + currentThread() * LOOP_UNROLL;
	const veci16_t values = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 11, 14, 15 };
	int transferCount = kTransferSize / (64 * NUM_THREADS * LOOP_UNROLL);
	int unrollCount;

	int startTime = getTime();
	startParallel();
	do
	{
		// The compiler will automatically unroll this
		for (unrollCount = 0; unrollCount < LOOP_UNROLL; unrollCount++)
			dest[unrollCount] = values;

		dest += NUM_THREADS * LOOP_UNROLL;
	}
	while (--transferCount);
	endParallel();
	if (currentThread() == 0)
	{
		int endTime = getTime();
		printf("write: %g bytes/cycle\n", (float) kTransferSize / (endTime - startTime));
	}
}

int main(int argc, const char *argv[])
{
	copyTest();
	readTest();
	writeTest();
	
	return 0;
}


