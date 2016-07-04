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

#pragma once

#define NUM_INTERRUPTS 16

typedef void (*interrupt_handler_t)(void);

// Returns old flag state before interrupts were disabled. The return
// value must be passed to restore_interrupts. If interrupts were
// already disabled, restore_interrupts will not turn them back on.
extern int disable_interrupts(void);

// restore interrupts to value before disable_interrupts was called.
extern void restore_interrupts(int value);

extern void enable_interrupts(void);

void unmask_interrupt(int interrupt);
void register_interrupt_handler(int interrupt, interrupt_handler_t);
void ack_interrupt(int interrupt);
