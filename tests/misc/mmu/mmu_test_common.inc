#
# Copyright 2015-2016 Jeff Bush
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

.set TLB_PRESENT, 1
.set TLB_WRITABLE, (1 << 1)
.set TLB_EXECUTABLE, (1 << 2)
.set TLB_SUPERVISOR, (1 << 3)
.set TLB_GLOBAL, (1 << 4)

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
.set TR_INTERRUPT_BASE, 16

.set FLAG_MMU_EN, (1 << 1)
.set FLAG_SUPERVISOR_EN, (1 << 2)

# Clobbers s0, s1, s2
.macro load_tlb_entries itlb_entries, dtlb_entries
                    # Load ITLB
                    lea s0, \itlb_entries
1:                  load_32 s1, (s0)
                    cmpeq_i s2, s1, -1
                    btrue s2, 2f
                    load_32 s2, 4(s0)
                    itlbinsert s1, s2
                    add_i s0, s0, 8
                    goto 1b
2:
                    # Load DTLB
                    lea s0, \dtlb_entries
1:                  load_32 s1, (s0)
                    cmpeq_i s2, s1, -1
                    btrue s2, 2f
                    load_32 s2, 4(s0)
                    dtlbinsert s1, s2
                    add_i s0, s0, 8
                    goto 1b
2:
.endm

# Takes s0 as parameter, null terminated string. Clobbers s0-s3.
                    .align 4, 0xff
.macro print_string
                    load_32 s1, _seraddr    ; Load address of serial registers
1:                  load_u8 s2, (s0)        ; Read a character
                    bfalse s2, 3f           ; If delimeter, exit
2:                  load_32 s3, (s1)        ; Read STATUS
                    and s3, s3, 1           ; Check write available bit
                    bfalse s3, 2b           ; If this is clear, busy wait
                    store_32 s2, 8(s1)      ; Write space available, send char
                    add_i s0, s0, 1         ; Increment pointer
                    goto 1b                 ; Loop for next char
3:
.endm
_seraddr:          .long 0xffff0018

# Does not return
                    .align 4, 0xff
fail_test:          lea s0, failstr
                    print_string
                    call halt_test
failstr:            .asciz "FAIL"

# Does not return
                    .align 4, 0xff
pass_test:          lea s0, passstr
                    print_string
                    call halt_test
passstr:            .asciz "PASS"

                    .align 4, 0xff
halt_test:          move s0, -1
                    load_32 s1, haltaddr
                    store_32 s0, (s1)
2:                  goto 2b
haltaddr:          .long 0xffff0064


# Load a constant value into a register
.macro load_const oreg, cval
                    move \oreg, ((\cval >> 20) & 0xfff)   ; Bits 31-20
                    shl \oreg, \oreg, 12
                    or \oreg, \oreg, ((\cval >> 8) & 0xfff)      ; Bits 19-8
                    shl \oreg, \oreg, 8
                    or \oreg, \oreg,    (\cval & 0xff)
.endm

# If register is not equal to cval, print failure message.
# Otherwise continue. Clobbers s25
.macro assert_reg reg, cval
                    load_const s25, \cval
                    cmpeq_i s25, s25, \reg
                    btrue s25, 1f
                    call fail_test
1:
.endm

.macro flush_pipeline
                goto 1f
1:
.endm

.macro mmu_fault_test reason, access_op, address, itlb_entries, dtlb_entries, flags
                    load_tlb_entries \itlb_entries, \dtlb_entries

                    lea s0, handle_fault
                    setcr s0, CR_TRAP_HANDLER
                    lea s0, fail_test
                    setcr s0, CR_TLB_MISS_HANDLER # Fail on TLB miss

                    move s0, \flags
                    setcr s0, CR_FLAGS          # Enable MMU
                    flush_pipeline

                    load_const s0, \address
fault_loc:          \access_op s0, (s0)            # This should fault
                    call fail_test                 # Fail if no

                    # After fault resumes from here. Check that it behaved as
                    # expected.
handle_fault:       getcr s0, CR_TRAP_REASON
                    assert_reg s0, \reason
                    getcr s0, CR_TRAP_ADDRESS
                    assert_reg s0, \address

                    ; Check that fault PC is correct
                    getcr s0, CR_TRAP_PC
                    lea s1, fault_loc
                    cmpeq_i s0, s0, s1
                    btrue s0, 1f
                    call fail_test
1:

                    call pass_test
.endm

.macro should_not_get_here
                    call fail_test
.endm
