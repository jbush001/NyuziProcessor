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
// This program tests the UART and I/O subsystem by writing a continuous
// "chargen" (RFC 864) pattern out the serial port.
//

const char *PATTERN = "!#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz";
const int PATTERN_LENGTH = 89;
const int LINE_LENGTH = 72;

volatile unsigned int * const UART_BASE = (volatile unsigned int*) 0xFFFF0040;

enum uart_regs
{
    UART_STATUS = 0,
    UART_RX = 1,
    UART_TX = 2
};

void write_char(char ch)
{
    while ((UART_BASE[UART_STATUS] & 1) == 0)	// Wait for ready
        ;

    UART_BASE[UART_TX] = ch;
}

int main()
{
    for (;;)
    {
        for (int start_index = 0; start_index < PATTERN_LENGTH; start_index++)
        {
            int index = start_index;
            for (int line_offset = 0; line_offset < LINE_LENGTH; line_offset++)
            {
                write_char(PATTERN[index]);
                if (++index == PATTERN_LENGTH)
                    index = 0;
            }

            write_char('\r');
            write_char('\n');
        }
    }
}
