//
// Copyright 2016 Jeff Bush
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

#include "spinlock.h"

//
// Utilities to print debug output to the UART
//

#define UART_TX_READY 	(1 << 0)

enum RegisterIndex
{
    REG_UART_STATUS         = 0x0040 / 4,
    REG_UART_TX             = 0x0048 / 4,
};

static volatile unsigned int * const REGISTERS = (volatile unsigned int*) 0xffff0000;
static spinlock_t uart_lock;

void putc(int c)
{
    acquire_spinlock(&uart_lock);
    while ((REGISTERS[REG_UART_STATUS] & UART_TX_READY) == 0)
        ;	// Wait for space

    REGISTERS[REG_UART_TX] = c;
    release_spinlock(&uart_lock);
}
