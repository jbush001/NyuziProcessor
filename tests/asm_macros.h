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
#define TLB_PRESENT 1
#define TLB_WRITABLE (1 << 1)
#define TLB_EXECUTABLE (1 << 2)
#define TLB_SUPERVISOR (1 << 3)
#define TLB_GLOBAL (1 << 4)

// Control register indices
#define CR_CURRENT_THREAD 0
#define CR_TRAP_HANDLER 1
#define CR_TRAP_PC 2
#define CR_TRAP_CAUSE 3
#define CR_FLAGS 4
#define CR_TRAP_ADDRESS 5
#define CR_CYCLE_COUNT 6
#define CR_TLB_MISS_HANDLER 7
#define CR_SAVED_FLAGS 8
#define CR_CURRENT_ASID 9
#define CR_SCRATCHPAD0 11
#define CR_SCRATCHPAD1 12
#define CR_SUBCYCLE 13
#define CR_INTERRUPT_ENABLE 14
#define CR_INTERRUPT_ACK 15
#define CR_INTERRUPT_PENDING 16
#define CR_INTERRUPT_TRIGGER 17
#define CR_JTAG_DATA 18
#define CR_SYSCALL_INDEX 19
#define CR_SUSPEND_THREAD 20
#define CR_RESUME_THREAD 21
#define CR_PERF_EVENT_SELECT0 22
#define CR_PERF_EVENT_SELECT1 23
#define CR_PERF_EVENT_COUNT0_L 24
#define CR_PERF_EVENT_COUNT0_H 25
#define CR_PERF_EVENT_COUNT1_L 26
#define CR_PERF_EVENT_COUNT1_H 27

// Trap types
#define TT_RESET 0
#define TT_ILLEGAL_INSTRUCTION 1
#define TT_PRIVILEGED_OP 2
#define TT_INTERRUPT 3
#define TT_SYSCALL 4
#define TT_UNALIGNED_ACCESS 5
#define TT_PAGE_FAULT 6
#define TT_TLB_MISS 7
#define TT_ILLEGAL_STORE 8
#define TT_SUPERVISOR_ACCESS 9
#define TT_NOT_EXECUTABLE 10
#define TT_BREAKPOINT 11

#define TRAP_CAUSE_STORE 0x10
#define TRAP_CAUSE_DCACHE 0x20

// Flag register bits
#define FLAG_INTERRUPT_EN (1 << 0)
#define FLAG_MMU_EN (1 << 1)
#define FLAG_SUPERVISOR_EN (1 << 2)

// Device registers
#define REG_HOST_INTERRUPT 0xffff0018
#define REG_SERIAL_WRITE 0xffff0048
#define REG_TIMER_COUNT 0xffff0240

.macro start_all_threads
                li s0, 0xffffffff
                setcr s0, CR_RESUME_THREAD
.endm

.macro halt_current_thread
                getcr s0, CR_CURRENT_THREAD
                move s1, 1
                shl s1, s1, s0
                setcr s1, CR_SUSPEND_THREAD
1:              b 1b
.endm

.macro halt_all_threads
                li s0, 0xffffffff
                setcr s0, CR_SUSPEND_THREAD
1:              b 1b
.endm

// Print a null terminated string pointer to by s0 to the serial
// port. Clobbers s0-s3.
                .align 4, 0xff
.macro print_string
                li s1, 0xffff0040       // Load address of serial registers
1:              load_u8 s2, (s0)        // Read a character
                bz s2, 3f               // If delimiter, exit
2:              load_32 s3, (s1)        // Read STATUS
                and s3, s3, 1           // Check write available bit
                bz s3, 2b               // If this is clear, busy wait
                store_32 s2, 8(s1)      // Write space available, send char
                add_i s0, s0, 1         // Increment pointer
                b 1b                    // Loop for next char
3:
.endm

// Print a character in s0. Clobbers s1, s2
.macro print_char
                li s1, 0xffff0040       // Load address of serial registers
1:              load_32 s2, (s1)        // Read STATUS
                and s2, s2, 1           // Check write available bit
                bz s2, 1b               // If this is clear, busy wait
                store_32 s0, 8(s1)       // Write space available, send char
.endm

// If register is not equal to testval, print failure message.
// Otherwise continue. Clobbers s25
.macro assert_reg reg, testval
                li s25, \testval
                cmpeq_i s25, s25, \reg
                bnz s25, 1f
                call fail_test
1:
.endm

.macro flush_pipeline
                b 1f
1:
.endm

.macro should_not_get_here
                call fail_test
.endm

// Print failure message and halt. It will print \x04 (^D) at the end, which
// will cause the serial_loader console mode to exit on FPGA, triggering the
// end of the test.
                .align 4, 0xff
fail_test:      lea s0, failstr
                print_string
                halt_all_threads
failstr:        .ascii "FAIL"
                .byte 4, 0

// Print success message and halt
                .align 4, 0xff
pass_test:      lea s0, passstr
                print_string
                halt_all_threads
passstr:        .ascii "PASS"
                .byte 4, 0

                .align 4, 0xff
