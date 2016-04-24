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

#include "trap_test_common.inc"

//
// This does a lot of I/O writes while the timer interrupt is going off.
// There was a design issue where an interrupt coming during an I/O write
// could duplicate the write. This test ensures that doesn't happen.
//
// Note this will only work in verilog simulation. It doesn't check if the
// UART is ready to send (it always is in the simulator)
//

//
// Interrupt handler clobbers s24-s25
//
handle_trap:    load_32 s24, seraddr    // Load address of serial registers
                move s25, '*'
                store_32 s25, 8(s24)    // Send char
                eret

                .globl _start
_start:
                // Set up trap handler
                lea s0, handle_trap
                setcr s0, CR_TRAP_HANDLER

                // Configure timer
                move s0, 100             // Cycles per interrupt
                load_32 s1, timer_addr
                store_32 s0, (s1)

                // Enable interrupts
                move s0, FLAG_SUPERVISOR_EN | FLAG_INTERRUPT_EN
                setcr s0, CR_FLAGS
                flush_pipeline

                load_32 s1, seraddr
                move s0, '!'
                store_32 s0, 8(s1)

                move s5, 10
repeat_loop:    move s0, '0'
print_loop:     store_32 s0, 8(s1)      // Send char
                add_i s0, s0, 1
                cmpgt_i s2, s0, 'z'
                bfalse s2, print_loop
                sub_i s5, s5, 1
                btrue s5, repeat_loop

                move s0, '\n'
                store_32 s0, 8(s1)

                call halt_test

seraddr:        .long 0xffff0040
timer_addr:     .long 0xffff0020
