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

#include "mmu_test_common.inc"

//
// Similar to supervisor_fault_write, but to an I/O mapped page, which is treated
// differently in hardware.
//
                .globl _start
_start:         mmu_fault_test (TT_SUPERVISOR_ACCESS | TRAP_CAUSE_STORE | TRAP_CAUSE_DCACHE), store_32, 0x1350, itlb_entries, dtlb_entries, FLAG_MMU_EN

itlb_entries:   .long 0x00000000, TLB_PRESENT | TLB_EXECUTABLE
                .long 0xffffffff, 0xffffffff

dtlb_entries:   .long 0x00000000, TLB_PRESENT
                .long 0x00001000, 0xffff0000 | TLB_PRESENT | TLB_SUPERVISOR
                .long 0xffff0000, 0xffff0000 | TLB_PRESENT | TLB_WRITABLE    // I/O area
                .long 0xffffffff, 0xffffffff
