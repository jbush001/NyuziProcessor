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

// Control register indices
#define CR_CURRENT_THREAD 0
#define CR_TRAP_HANDLER 1
#define CR_TRAP_PC 2
#define CR_TRAP_REASON 3
#define CR_FLAGS 4
#define CR_TRAP_ADDR 5
#define CR_TLB_MISS_HANDLER 7
#define CR_SAVED_FLAGS 8
#define CR_CURRENT_ASID 9
#define CR_PAGE_DIR_BASE 10
#define CR_SCRATCHPAD0 11
#define CR_SCRATCHPAD1 12
#define CR_SUBCYCLE 13

// Flag register bits
#define FLAG_INTERRUPT_EN (1 << 0)
#define FLAG_MMU_EN (1 << 1)
#define FLAG_SUPERVISOR_EN (1 << 2)

// Trap reasons
#define TR_RESET 0
#define TR_ILLEGAL_INSTRUCTION 1
#define TR_DATA_ALIGNMENT 2
#define TR_PAGE_FAULT 3
#define TR_IFETCH_ALIGNNMENT 4
#define TR_ITLB_MISS 5
#define TR_DTLB_MISS 6
#define TR_ILLEGAL_WRITE 7
#define TR_DATA_SUPERVISOR 8
#define TR_IFETCH_SUPERVISOR 9
#define TR_PRIVILEGED_OP 10
#define TR_SYSCALL 11
#define TR_NOT_EXECUTABLE 12
#define TR_INTERRUPT 13
