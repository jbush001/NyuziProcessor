// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
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
