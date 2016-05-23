//
// Copyright 2015 Jeff Bush
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

// TLB flags
.set TLB_PRESENT, 1
.set TLB_WRITABLE, (1 << 1)
.set TLB_EXECUTABLE, (1 << 2)
.set TLB_SUPERVISOR, (1 << 3)
.set TLB_GLOBAL, (1 << 4)

// Control register indices
.set CR_CURRENT_THREAD, 0
.set CR_TRAP_HANDLER, 1
.set CR_TRAP_PC, 2
.set CR_TRAP_REASON, 3
.set CR_FLAGS, 4
.set CR_TRAP_ADDRESS, 5
.set CR_TLB_MISS_HANDLER, 7
.set CR_SAVED_FLAGS, 8
.set CR_CURRENT_ASID, 9
.set CR_SCRATCHPAD0, 11
.set CR_SCRATCHPAD1, 12
.set CR_SUBCYCLE, 13

// Trap reasons
.set TR_ILLEGAL_INSTRUCTION, 1
.set TR_DATA_ALIGNMENT, 2
.set TR_PAGE_FAULT, 3
.set TR_IFETCH_ALIGNNMENT, 4
.set TR_ITLB_MISS, 5
.set TR_DTLB_MISS, 6
.set TR_ILLEGAL_WRITE, 7
.set TR_DATA_SUPERVISOR, 8
.set TR_IFETCH_SUPERVISOR, 9
.set TR_PRIVILEGED_OP, 10
.set TR_SYSCALL, 11
.set TR_NOT_EXECUTABLE, 12
.set TR_INTERRUPT, 13

// Flag register bits
.set FLAG_INTERRUPT_EN, (1 << 0)
.set FLAG_MMU_EN, (1 << 1)
.set FLAG_SUPERVISOR_EN, (1 << 2)

.macro start_all_threads
	move s0, 0xffffffff
	shl s0, s0, 16
	or s0, s0, 0x100
	move s1, 0xffffffff
	store_32 s1, (s0)
.endm

.macro halt_current_thread
	getcr s0, CR_CURRENT_THREAD
	move s1, 1
	shl s1, s1, s0
	move s0, 0xffffffff
	shl s0, s0, 16
	or s0, s0, 0x104
	store_32 s1, (s0)
1:	goto 1b
.endm

.macro halt_all_threads
    move s0, 0xffffffff
    shl s0, s0, 16
    or s0, s0, 0x104
    move s1, 0xffffffff
	store_32 s1, (s0)
1:	goto 1b
.endm

// Print a null terminated string pointer to by s0 to the serial
// port. Clobbers s0-s3.
                    .align 4, 0xff
.macro print_string
                    load_32 s1, _seraddr    // Load address of serial registers
1:                  load_u8 s2, (s0)        // Read a character
                    bfalse s2, 3f           // If delimeter, exit
2:                  load_32 s3, (s1)        // Read STATUS
                    and s3, s3, 1           // Check write available bit
                    bfalse s3, 2b           // If this is clear, busy wait
                    store_32 s2, 8(s1)      // Write space available, send char
                    add_i s0, s0, 1         // Increment pointer
                    goto 1b                 // Loop for next char
3:
.endm
_seraddr:          .long 0xffff0040

// If register is not equal to testval, print failure message.
// Otherwise continue. Clobbers s25
.macro assert_reg reg, testval
                    load_const s25, \testval
                    cmpeq_i s25, s25, \reg
                    btrue s25, 1f
                    call fail_test
1:
.endm

.macro flush_pipeline
                goto 1f
1:
.endm

.macro should_not_get_here
                    call fail_test
.endm

// Load a constant value into a register
.macro load_const oreg, value
                    move \oreg, (((\value ) >> 20) & 0xfff)     // Bits 31-20
                    shl \oreg, \oreg, 12
                    or \oreg, \oreg, (((\value ) >> 8) & 0xfff) // Bits 19-8
                    shl \oreg, \oreg, 8
                    or \oreg, \oreg,    ((\value ) & 0xff)
.endm

// Print failure message and halt
                    .align 4, 0xff
fail_test:          lea s0, failstr
                    print_string
                    halt_all_threads
failstr:            .asciz "FAIL"

// Print success message and halt
                    .align 4, 0xff
pass_test:          lea s0, passstr
                    print_string
                    halt_all_threads
passstr:            .asciz "PASS"

                    .align 4, 0xff


