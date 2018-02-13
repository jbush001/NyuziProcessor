//
// Copyright 2018 Jeff Bush
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

#define UART_FRAME_ERR 	(1 << 3)
#define UART_OVERRUN 	(1 << 2)
#define UART_RX_READY 	(1 << 1)
#define UART_TX_READY 	(1 << 0)

static volatile unsigned int * const REGISTERS = (volatile unsigned int*) 0xffff0000;

enum register_index
{
    REG_UART_STATUS         = 0x0040 / 4,
    REG_UART_RX             = 0x0044 / 4,
    REG_UART_TX             = 0x0048 / 4
};


void write_uart(char ch)
{
    while ((REGISTERS[REG_UART_STATUS] & UART_TX_READY) == 0)
        ;	// Wait for space

    REGISTERS[REG_UART_TX] = ch;
}

unsigned char read_uart(void)
{
    while ((REGISTERS[REG_UART_STATUS] & UART_RX_READY) == 0)
        ;	// Wait for characters to be available

    return REGISTERS[REG_UART_RX];
}

int main()
{
    while (1)
    {
        unsigned ch = read_uart();
        if (ch >= 'A' && ch <= 'Z')
            write_uart(ch + ('a' - 'A'));
        else
            write_uart(ch);

        if (ch == '\n')
            break;
    }

    return 0;
}
