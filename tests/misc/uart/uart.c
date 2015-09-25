// 
// Copyright 2015 Pipat Methavanitpong
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

/// Check UART Overrun bit to assert and deassert properly
/// Recommend to turn on UART Overrun print in
///     hardware/fpga/common/uart.sv
/// to check contents in its FIFO

#include <stdio.h>
#include <unistd.h>

#define CHECK(cond) do { if (!(cond)) { printf("FAIL: %d: %s\n", __LINE__, \
	#cond); abort(); } } while(0)

const int kMaxTimeout = 10000;
const int kMaxFifoDepth = 7;
volatile unsigned int * const LOOPBACK_UART = (volatile unsigned int*) 0xFFFF0100;

enum UartRegs
{
	kStatus = 0,
	kRx = 1,
	kTx = 2
};


void writeLoopbackUart(char ch) 
{
	int timeout = 0;
	LOOPBACK_UART[kTx] = ch;
	while ((LOOPBACK_UART[kStatus] & 1) == 0)	// Wait for transmit to finish
		CHECK(++timeout < kMaxTimeout);

	printf("write %02x\n", ch);
}

int readLoopbackUart(void)
{
	char result;
	int timeout = 0;
	while ((LOOPBACK_UART[kStatus] & 2) == 0)
		CHECK(++timeout < kMaxTimeout);
	
	result = LOOPBACK_UART[kRx];
	printf("read %02x\n", result);
	return result;
}

int main () 
{
	int fifoCount;
	int i;
	char txChar = 1;
	char rxChar = 1;
	int readCount;
	
	for (fifoCount = 1; fifoCount < kMaxFifoDepth + 3; fifoCount++)
	{
		for (i = 0; i < fifoCount; i++)
		{
			writeLoopbackUart(txChar++);
			
			// Ensure the overrun bit is set if we've filled the FIFO,
			// not set if we have not
			if (i >= kMaxFifoDepth)
				CHECK((LOOPBACK_UART[kStatus] & 4) != 0);
			else
				CHECK((LOOPBACK_UART[kStatus] & 4) == 0);
		}
		
		// Account for dropped characters
		if (fifoCount > kMaxFifoDepth)
			rxChar += fifoCount - kMaxFifoDepth;
		
		readCount = fifoCount;
		if (readCount > kMaxFifoDepth)
			readCount = kMaxFifoDepth;
		
		for (i = 0; i < readCount; i++)
			CHECK(readLoopbackUart() == rxChar++);
	}

	printf("PASS\n");
	return 0;
}
