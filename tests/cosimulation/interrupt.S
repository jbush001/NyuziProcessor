#
# Copyright 2011-2015 Jeff Bush
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

.include "../asm_macros.inc"

#
# Test interrupt handling
#

                    .text
                    .align    4

                    .globl    _start
                    .align    4
                    .type    main,@function
_start:             lea s0, interrupt_handler
                    setcr s0, CR_TRAP_HANDLER
                    move s0, 5
                    setcr s0, CR_FLAGS   # Enable interrupts

                    # Unmask interrupt
                    move s24, 1
                    setcr s24, CR_INTERRUPT_MASK

                    # Set up registers
                    move s1, 1000
                    move s2, 7
                    move s3, 17
                    move s4, 31

                    # Main loop. Do some computations to ensure state is handled correctly.
1:                  mull_i s2, s2, s3
                    add_i s2, s2, s4
                    sub_i s1, s1, 1
                    btrue s1, 1b

                    # Disable interrupts before finishing.  This avoids a race condition
                    # where the emulator can begin processing an interrupt before
                    # halting.
                    move s0, 0
                    setcr s0, CR_FLAGS

                    halt_current_thread


interrupt_handler:  getcr s11, CR_TRAP_PC        # Interrupt PC
                    getcr s12, CR_TRAP_REASON    # Reason
                    move s13, 1

                    # Ack interrupt
                    move s25, 1
                    setcr s25, CR_INTERRUPT_ACK
                    eret
