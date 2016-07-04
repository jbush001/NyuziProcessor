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
// Test mechanism for delivering interrupts from an external program
// to the emulator.
//

.macro receive_interrupt intnum
                    // Set the trap handler to the next label
                    lea s0, handle_trap\intnum
                    setcr s0, CR_TRAP_HANDLER

                    // Once the trap handle is set, (re)enable interrupts
                    move s0, FLAG_SUPERVISOR_EN | FLAG_INTERRUPT_EN
                    setcr s0, CR_FLAGS
                    flush_pipeline

int_addr\intnum :   goto 1b     // Wait for interrupt

handle_trap\intnum :
                    // Ack interrupt
                    getcr s25, CR_INTERRUPT_PENDING
                    setcr s25, CR_INTERRUPT_ACK

                    // Check control registers
                    getcr s0, CR_TRAP_CAUSE
                    assert_reg s0, TT_INTERRUPT
                    getcr s0, CR_FLAGS
                    assert_reg s0, FLAG_SUPERVISOR_EN   // Interrupts disabled

                    // XXX when multiple interrupts are enabled, check that the
                    // proper bit in the pending interrupt register is set.

                    // Check that trap PC is correct
                    getcr s0, CR_TRAP_PC
                    lea s1, int_addr\intnum
                    cmpeq_i s0, s0, s1
                    btrue s0, 1f
                    call fail_test
1:                  // Interrupts are now off
.endm

                    .globl _start
_start:             // Unmask interrupt
                    move s24, -1
                    setcr s24, CR_INTERRUPT_MASK

                    receive_interrupt 16
                    receive_interrupt 17
                    receive_interrupt 18
                    receive_interrupt 19
                    receive_interrupt 20

                    call pass_test





