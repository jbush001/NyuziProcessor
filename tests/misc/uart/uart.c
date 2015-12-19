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

// UART tests.
// - Basic character transmission
// - Test overrun and frame error tests

#include <stdio.h>
#include <unistd.h>
#include <uart.h>

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
	while ((LOOPBACK_UART[kStatus] & UART_TX_READY) == 0)	// Wait for transmit to finish
		CHECK(++timeout < kMaxTimeout);

	printf("write %02x\n", ch);
}

int waitLoopbackUartNewRxWord(int maxTimeOut)
{
	int timeout = 0;
	while ((LOOPBACK_UART[kStatus] & UART_RX_READY) == 0)
		if (timeout++ > maxTimeOut)
			return 0;
	return 1;
}

int readLoopbackUart(void)
{
	char result;
	CHECK(waitLoopbackUartNewRxWord(kMaxTimeout));
	result = LOOPBACK_UART[kRx];
	printf("read %02x\n", result);
	return result;
}

void setLoopbackUartMask(int value)
{
	LOOPBACK_UART[3] = value;
}

int main ()
{
	int fifoCount;
	int i;
	char txChar = 1;
	char rxChar = 1;
	int readCount;

	// Overrun Error Test
	for (fifoCount = 1; fifoCount < kMaxFifoDepth + 3; fifoCount++)
	{
		for (i = 0; i < fifoCount; i++)
		{
			writeLoopbackUart(txChar++);

			// Ensure the overrun bit is set if we've filled the FIFO,
			// not set if we have not
			if (i >= kMaxFifoDepth)
				CHECK((LOOPBACK_UART[kStatus] & UART_OVERRUN) != 0);
			else
				CHECK((LOOPBACK_UART[kStatus] & UART_OVERRUN) == 0);
		}

		// Account for dropped characters
		if (fifoCount > kMaxFifoDepth)
			rxChar += fifoCount - kMaxFifoDepth;

		readCount = fifoCount;
		if (readCount > kMaxFifoDepth)
			readCount = kMaxFifoDepth;

		for (i = 0; i < readCount; i++)
		{
			CHECK((LOOPBACK_UART[kStatus] & UART_FRAME_ERR) == 0);
			CHECK(readLoopbackUart() == rxChar++);

			// Reading from the UART should clear the overflow bit
			// if it was set.
			CHECK((LOOPBACK_UART[kStatus] & UART_OVERRUN) == 0);
		}
	}

	// Frame Error Test
	setLoopbackUartMask(0);
	waitLoopbackUartNewRxWord(kMaxTimeout);
	setLoopbackUartMask(1);
	int hasFrameErrorRaised = 0;
	// When unhold, the last word may be a valid word.
	// This breaks an assumption that all words have frame error.
	// We need to flush before checking the flag is lowered properly.
	while ((LOOPBACK_UART[kStatus] & UART_RX_READY) != 0)
	{
		if ((LOOPBACK_UART[kStatus] & UART_FRAME_ERR) != 0)
			hasFrameErrorRaised = 1;
		readLoopbackUart();
	}
	CHECK(hasFrameErrorRaised);
	// Assure that we have at least one valid word
	writeLoopbackUart('a');
	writeLoopbackUart('b');
	waitLoopbackUartNewRxWord(kMaxTimeout);
	CHECK((LOOPBACK_UART[kStatus] & UART_FRAME_ERR) == 0);
	CHECK(readLoopbackUart() == 'a');
	CHECK(readLoopbackUart() == 'b');

	printf("PASS\n");
	return 0;
}
