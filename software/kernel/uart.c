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

#include "registers.h"
#include "spinlock.h"
#include "trap.h"

//
// Utilities to print debug output to the UART
//

#define UART_TX_READY 	(1 << 0)

static spinlock_t uart_lock;

void putc(int c)
{
    int old_flags;

    old_flags = acquire_spinlock_int(&uart_lock);
    while ((REGISTERS[REG_UART_STATUS] & UART_TX_READY) == 0)
        ;	// Wait for space

    REGISTERS[REG_UART_TX] = c;
    release_spinlock_int(&uart_lock, old_flags);
}
