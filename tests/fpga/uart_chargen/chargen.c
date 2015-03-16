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
// This program validates the UART and I/O subsystem by writing a continuous 
// "chargen" (RFC 864) pattern out the serial port.
// The hardcoded setup for the UART is 115200 baud, 8 data bits, 1 stop bit,
// no parity.
//

const char *kPattern = "!#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz";
const int kPatternLength = 89;
const int kLineLength = 72;

volatile unsigned int * const UART_BASE = (volatile unsigned int*) 0xFFFF0018;
	
enum UartRegs
{
	kStatus = 0,
	kRx = 1,
	kTx = 2
};
	
void writeChar(char ch)	
{
	while ((UART_BASE[kStatus] & 1) == 0)	// Wait for ready
		;
	
	UART_BASE[kTx] = ch;
}

int main()
{
	for (;;)
	{
		for (int startIndex = 0; startIndex < kPatternLength; startIndex++)
		{
			int index = startIndex;
			for (int lineOffset = 0; lineOffset < kLineLength; lineOffset++)
			{
				writeChar(kPattern[index]);
				if (++index == kPatternLength)
					index = 0;
			}
			
			writeChar('\r');
			writeChar('\n');
		}
	}
}
