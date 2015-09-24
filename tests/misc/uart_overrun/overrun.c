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

volatile unsigned int * const LOOPBACK_UART = (volatile unsigned int*) 0xFFFF0100;

enum UartRegs
{
	kStatus = 0,
	kRx = 1,
	kTx = 2
};

void writeLoopbackUart(char ch) {
	while ((LOOPBACK_UART[kStatus] & 1) == 0)	// Wait for ready
		;
	
	LOOPBACK_UART[kTx] = ch;
}

// A UART has 7-character capacity
const char * text = "abcdefghij";
const int text_len = 10;

int main () {
	printf("====UART Overrun Test====\n");
	printf("String: %s\n", text);
	int i, j, k;
	for (i = 1; i <= 7; i++) {
		// Fill Rx FIFO until full and overrun
		while ((LOOPBACK_UART[kStatus] & 4) == 0) {
			for (j = 0; j < text_len; j++) {
				writeLoopbackUart(text[j]);
			}
		}
		// Dequeue for i characters
		printf("%dDequeue: ", i);
		for (k = 1; k <= i; k++) {
			while ((LOOPBACK_UART[kStatus] & 2) == 0)
				;
			printf("%c", LOOPBACK_UART[kRx]);
		}
		printf("\n");

		// Check if Overrun bit is deasserted
		if ((LOOPBACK_UART[kStatus] & 4) == 0)
			printf("%d:PASS\n", i);
		else
			printf("%d:FAIL\n", i);
	}
	printf("===END===\n");
	return 0;
}
