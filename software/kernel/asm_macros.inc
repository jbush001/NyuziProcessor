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
.set CR_CURRENT_THREAD, 0
.set CR_TRAP_HANDLER, 1
.set CR_TRAP_PC, 2
.set CR_TRAP_REASON, 3
.set CR_FLAGS, 4
.set CR_TRAP_ADDRESS, 5
.set CR_TLB_MISS_HANDLER, 7
.set CR_SAVED_FLAGS, 8
.set CR_CURRENT_ASID, 9
.set CR_PAGE_DIR_BASE, 10
.set CR_SCRATCHPAD0, 11
.set CR_SCRATCHPAD1, 12
.set CR_SUBCYCLE, 13

// Flag register bits
.set FLAG_INTERRUPT_EN, (1 << 0)
.set FLAG_MMU_EN, (1 << 1)
.set FLAG_SUPERVISOR_EN, (1 << 2)

// Fault reasons
.set FR_ITLB_MISS, 5




