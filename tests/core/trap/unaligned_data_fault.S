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
// Test that unaligned data accesses faults
//

.macro _test_unaligned_fault testnum, subtest, op, ptr, value, fault_addr, is_store, flags, subcycle
                lea s0, handle_fault\testnum\()_\subtest
                setcr s0, CR_TRAP_HANDLER

                // Switch modes if necessary
                move s0, \flags
                setcr s0, CR_FLAGS
                flush_pipeline

fault_loc\testnum\()_\subtest :
                \op \value, (\ptr\())
                should_not_get_here
handle_fault\testnum\()_\subtest :
                getcr s0, CR_TRAP_CAUSE
                assert_reg s0, (TT_UNALIGNED_ACCESS | TRAP_CAUSE_DCACHE | (\is_store << 4))
                getcr s0, CR_TRAP_ADDRESS
                assert_reg s0, \fault_addr
                getcr s0, CR_SUBCYCLE
                assert_reg s0, \subcycle

                // Check that we've switched back to supervisor mode
                getcr s0, CR_FLAGS
                assert_reg s0, FLAG_SUPERVISOR_EN
                getcr s0, CR_SAVED_FLAGS
                assert_reg s0, \flags

                // Check that PC is correct
                getcr s0, CR_TRAP_PC
                lea s1, fault_loc\testnum\()_\subtest
                cmpeq_i s0, s0, s1
                bnz s0, 1f
                call fail_test
1:
.endm

.macro test_unaligned_fault testnum, op, ptr, value, fault_addr, is_store, subcycle
    // User mode
    _test_unaligned_fault \testnum, 0, \op, \ptr, \value, \fault_addr, \is_store, 0, \subcycle

    // Supervisor mode
    _test_unaligned_fault \testnum, 1, \op, \ptr, \value, \fault_addr, \is_store, FLAG_SUPERVISOR_EN, \subcycle
.endm

.set ORIGINAL_VALUE, 0x12345678

                .globl _start
_start:         move s10, 17            // Scalar pointer
                lea s0, vec_ptr
                load_v v10, (s0)

                // Store check value at target location
                li s0, ORIGINAL_VALUE
                move s1, 16             // Aligned version of s10
                store_32 s0, (s1)

                test_unaligned_fault 1, load_u16, s10, s11, 17, 0, 0
                test_unaligned_fault 2, load_32, s10, s11, 17, 0, 0
                test_unaligned_fault 3, load_v, s10, v11, 17, 0, 0

                // Gather load will fault on lane 3
                test_unaligned_fault 4, load_gath, v10, v11, 17, 0, 3

                test_unaligned_fault 5, store_16, s10, s11, 17, 1, 0
                test_unaligned_fault 6, store_32, s10, s11, 17, 1, 0
                test_unaligned_fault 7, store_v, s10, v11, 17, 1, 0

                // Scatter store will fault on lane 3
                test_unaligned_fault 8, store_scat, v10, v11, 17, 1, 3

                // Read back location to ensure it hasn't changed
                move s1, 16
                load_32 s0, (s1)
                assert_reg s0, ORIGINAL_VALUE

                call pass_test

.align 64
vec_ptr: .long dummy, dummy, dummy, 17, dummy, dummy, dummy, dummy, dummy, dummy, dummy, dummy, dummy, dummy, dummy, dummy
dummy: .long 0
