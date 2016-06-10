//
// Copyright 2011-2016 Jeff Bush
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
// This checks that, if an interrupt comes in during a gather load, it resumes
// from the correct lane. In this test, v0 is both the vector of pointers and the
// destination. If it restarted from 0 after returning from the interrupt, it would
// use the data value as a pointer. The data value is an odd number, which will
// cause an alignment exception if accessed as such.
//

.set TIMER_INTERVAL, 100

                    .globl _start
_start:             getcr s0, 0                 // Find my thread ID
                    btrue s0, spinner_thread    // If it is 1, jump to spinner thread

                    // Start spinner thread, which is described below
                    load_const s0, REG_THREAD_RESUME
                    move s1, 3    // Two threads enabled
                    store_32 s1, (s0)

                    // Set up interrupts
                    move s24, 2
                    load_const s25, REG_INT_MASK0
                    store_32 s24, (s25)

                    // Reset timer
                    load_const s24, TIMER_INTERVAL
                    load_const s25, REG_TIMER_COUNT
                    store_32 s24, (s25)

                    lea s10, interrupt_handler
                    setcr s10, CR_TRAP_HANDLER     // Set fault handler address
                    move s10, 5
                    setcr s10, CR_FLAGS             // Enable interrupts

                    move s0, 1024                   // Number of loops
loop0:
                    // Invalidate the second page so we will miss the cache part way through
                    // fetching these
                    lea s1, dataloc2
                    dinvalidate s1
                    load_v v0, ptrvec     // Get vector of pointers
                    load_gath v0, (v0)     // Gather load from pointers
                    sub_i s0, s0, 1        // Decrement counter and loop if not done
                    btrue s0, loop0

                    call pass_test

interrupt_handler:  getcr s12, CR_TRAP_CAUSE
                    cmpeq_i s13, s12, TT_INTERRUPT
                    bfalse s13, bad_int

                    // Ack interrupt
                    load_const s24, REG_INTERRUPT_ACK
                    move s25, 2
                    store_32 s25, (s24)

                    // Reset timer
                    load_const s24, TIMER_INTERVAL
                    load_const s25, REG_TIMER_COUNT
                    store_32 s24, (s25)

                    eret

bad_int:            call fail_test

// The purpose of the spinner thread is to issue instructions in between the gather
// instructions from thread 0 and reset the subcycle counter. Otherwise it is still
// the value of the last instruction and the test appears to pass.
spinner_thread:     goto spinner_thread

                    .align 64

// There will be a cache miss between dataloc1 and dataloc2, which will allow the interrupt to
// be dispatched.
ptrvec:             .long dataloc1, dataloc2, dataloc2, dataloc2, dataloc2, dataloc2, dataloc2, dataloc2
                    .long dataloc2, dataloc2, dataloc2, dataloc2, dataloc2, dataloc2, dataloc2, dataloc2
dataloc1:           .long 7     // Odd address, will generate fault if used as pointer
                    .align 64
dataloc2:           .long 5     // Also odd, but this is on a different cache line
