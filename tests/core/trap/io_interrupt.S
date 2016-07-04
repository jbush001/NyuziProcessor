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

#include "../../asm_macros.inc"

//
// This does a lot of I/O writes while the timer interrupt is going off.
// There was a hardware issue where an interrupt coming during an I/O write
// could duplicate the write. This test ensures that doesn't happen.
// This also validates the interrupt controller and timer.
//
// This assumes the existance of the hardware timer on interrupt 1
// Note this will only work in verilog simulation and the emulator because it
// doesn't check if the UART is ready to send (it always is in the simulator)
//

.set TIMER_INTERVAL, 100

//
// Interrupt handler clobbers s24-s25
//
handle_trap:    // Check that
                getcr s24, CR_INTERRUPT_PENDING
                and s24, s24, 2     // Cosimulation interrupt will also be set, ignore
                btrue s24, 1f       // If interrupt pending continue
                call fail_test
1:

                // Write serial character
                load_const s24, REG_SERIAL_WRITE
                move s25, '*'
                store_32 s25, (s24)    // Send char

                // Ack interrupt
                move s25, 2
                setcr s25, CR_INTERRUPT_ACK

                // Reset timer
                load_const s24, TIMER_INTERVAL
                load_const s25, REG_TIMER_COUNT
                store_32 s24, (s25)

                eret

                .globl _start
_start:
                // Set up trap handler
                lea s0, handle_trap
                setcr s0, CR_TRAP_HANDLER

                // Unmask interrupt
                move s24, 2
                setcr s24, CR_INTERRUPT_MASK

                // Configure timer
                load_const s24, TIMER_INTERVAL
                load_const s25, REG_TIMER_COUNT
                store_32 s24, (s25)

                // Enable interrupts
                move s0, FLAG_SUPERVISOR_EN | FLAG_INTERRUPT_EN
                setcr s0, CR_FLAGS
                flush_pipeline

                // Write start character
                load_const s1, REG_SERIAL_WRITE
                move s0, '!'
                store_32 s0, (s1)

                move s5, 10
repeat_loop:    move s0, '0'
print_loop:     store_32 s0, (s1)      // Send char
                add_i s0, s0, 1
                cmpgt_i s2, s0, 'z'
                bfalse s2, print_loop
                sub_i s5, s5, 1
                btrue s5, repeat_loop

                move s0, '\n'
                store_32 s0, (s1)

                halt_all_threads
