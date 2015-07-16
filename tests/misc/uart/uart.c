// 
// Copyright 2011-2015 Pipat Methavanitpong
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

// UART Rx Overrun Error behavior test
// An external uart has its Tx connected to Rx itself. 


#include <stdio.h>
#include <stdbool.h>
#include <string.h>

static volatile unsigned int * const REGISTERS = (volatile unsigned int*) 0xffff0000;
#define REG_UART_EXT_STATUS	0x118 / 4
#define REG_UART_EXT_RX		0x11c / 4
#define REG_UART_EXT_TX		0x120 / 4
#define UART_FIFO_DEPTH		8

void writeUartExt(char ch)
{
	while ((REGISTERS[REG_UART_EXT_STATUS] & (1 << 4)) == 0)
		;	// Wait for space
	
	REGISTERS[REG_UART_EXT_TX] = ch;	
}

unsigned char readUartExt()
{
	while ((REGISTERS[REG_UART_EXT_STATUS] & (1 << 5)) == 0)
		;	// Wait for a new word
	
	return REGISTERS[REG_UART_EXT_RX];	
}

void flushUartExtRx()
{
	char c;
	printf("Flushing ... ");
	while(REGISTERS[REG_UART_EXT_STATUS] & (1 << 5))
	{
		printf("%d ", REGISTERS[REG_UART_EXT_RX]);
	}
	printf("\n");
}

int main()
{
	const char* word[2] = { "AWESOME", "A quick brown fox jumps over the lazy dog."};
	int word_len[2] = { strlen(word[0]), strlen(word[1]) };
	int uart_status;
	bool isOverrunError = false;

	for (int i = 0; i < 2; i++)
	{
		printf("Sending \"%s\" (len=%d) to an external uart\n", word[i], word_len[i]);
		for (int j = 0; j < word_len[i]; j++)
			writeUartExt(word[i][j]);
		
		uart_status = REGISTERS[REG_UART_EXT_STATUS];
		printf("BI: %d FE: %d PE: %d OE: %d\n", (uart_status & (1 << 3)) > 0, 
												(uart_status & (1 << 2)) > 0,
												(uart_status & (1 << 1)) > 0,
												(uart_status & (1 << 0)) > 0);
		isOverrunError = (uart_status & (1 << 0)) ? true : false;

		if (word_len[i] < UART_FIFO_DEPTH && !isOverrunError)
			printf("Overrun Error ... PASS\n");
		else if (word_len[i] > UART_FIFO_DEPTH && isOverrunError)
			printf("Overrun Error ... PASS\n");
		else
			printf("Overrun Error ... FAIL\n");

		flushUartExtRx();
	}

	printf("END\n");

	return 0;
}
