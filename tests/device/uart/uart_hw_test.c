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

const int MAX_TIMEOUT = 10000;
const int MAX_FIFO_DEPTH = 7;
volatile unsigned int * const LOOPBACK_UART = (volatile unsigned int*) 0xFFFF0140;

enum uart_regs
{
    UART_STATUS = 0,
    UART_RX = 1,
    UART_TX = 2,
    UART_DIVISOR = 3
};

void write_loopback_uart(char ch)
{
    int timeout = 0;
    LOOPBACK_UART[UART_TX] = ch;
    while ((LOOPBACK_UART[UART_STATUS] & UART_TX_READY) == 0)	// Wait for transmit to finish
        CHECK(++timeout < MAX_TIMEOUT);

    printf("write %02x\n", ch);
}

int wait_loopback_uart_new_rx_word(int max_time_out)
{
    int timeout = 0;
    while ((LOOPBACK_UART[UART_STATUS] & UART_RX_READY) == 0)
        if (timeout++ > max_time_out)
            return 0;
    return 1;
}

int read_loopback_uart(void)
{
    char result;
    CHECK(wait_loopback_uart_new_rx_word(MAX_TIMEOUT));
    result = LOOPBACK_UART[UART_RX];
    printf("read %02x\n", result);
    return result;
}

void set_loopback_uart_mask(int value)
{
    *((volatile unsigned int*) 0xffff001c) = value;
}

int main(void)
{
    int fifo_count;
    int i;
    char tx_char = 1;
    char rx_char = 1;
    int read_count;

    LOOPBACK_UART[UART_DIVISOR] = 10;

    // Overrun Error Test
    for (fifo_count = 1; fifo_count < MAX_FIFO_DEPTH + 3; fifo_count++)
    {
        for (i = 0; i < fifo_count; i++)
        {
            write_loopback_uart(tx_char++);

            // Ensure the overrun bit is set if we've filled the FIFO,
            // not set if we have not
            if (i >= MAX_FIFO_DEPTH)
                CHECK((LOOPBACK_UART[UART_STATUS] & UART_OVERRUN) != 0);
            else
                CHECK((LOOPBACK_UART[UART_STATUS] & UART_OVERRUN) == 0);
        }

        // Account for dropped characters
        if (fifo_count > MAX_FIFO_DEPTH)
            rx_char += fifo_count - MAX_FIFO_DEPTH;

        read_count = fifo_count;
        if (read_count > MAX_FIFO_DEPTH)
            read_count = MAX_FIFO_DEPTH;

        for (i = 0; i < read_count; i++)
        {
            CHECK((LOOPBACK_UART[UART_STATUS] & UART_FRAME_ERR) == 0);
            CHECK(read_loopback_uart() == rx_char++);

            // Reading from the UART should clear the overflow bit
            // if it was set.
            CHECK((LOOPBACK_UART[UART_STATUS] & UART_OVERRUN) == 0);
        }
    }

    // Frame Error Test
    set_loopback_uart_mask(0);
    wait_loopback_uart_new_rx_word(MAX_TIMEOUT);
    set_loopback_uart_mask(1);
    int has_frame_error_raised = 0;
    // When unhold, the last word may be a valid word.
    // This breaks an assumption that all words have frame error.
    // We need to flush before checking the flag is lowered properly.
    while ((LOOPBACK_UART[UART_STATUS] & UART_RX_READY) != 0)
    {
        if ((LOOPBACK_UART[UART_STATUS] & UART_FRAME_ERR) != 0)
            has_frame_error_raised = 1;
        read_loopback_uart();
    }
    CHECK(has_frame_error_raised);
    // Assure that we have at least one valid word
    write_loopback_uart('a');
    write_loopback_uart('b');
    wait_loopback_uart_new_rx_word(MAX_TIMEOUT);
    CHECK((LOOPBACK_UART[UART_STATUS] & UART_FRAME_ERR) == 0);
    CHECK(read_loopback_uart() == 'a');
    CHECK(read_loopback_uart() == 'b');

    printf("PASS\n");
    return 0;
}
