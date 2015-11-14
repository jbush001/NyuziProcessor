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

#pragma once

#define PAGE_SIZE 0x1000
#define IO_REGION_BASE 0xffff0000

#define TLB_WRITABLE (1 << 1)
#define TLB_SUPERVISOR (1 << 3)
#define TLB_GLOBAL (1 << 4)

#define CR_FAULT_HANDLER 1
#define CR_FAULT_PC 2
#define CR_FAULT_REASON 3
#define CR_FLAGS 4
#define CR_FAULT_ADDRESS 5
#define CR_TLB_MISS_HANDLER 7
#define CR_SAVED_FLAGS 8
#define CR_CURRENT_ASID 9
#define CR_SCRATCHPAD0 11

#define FLAG_MMU_EN (1 << 1)
#define FLAG_SUPERVISOR_EN (1 << 2)

void add_itlb_mapping(unsigned int va, unsigned int pa)
{
	asm volatile("itlbinsert %0, %1" : : "r" (va), "r" (pa));
}

void add_dtlb_mapping(unsigned int va, unsigned int pa)
{
	asm volatile("dtlbinsert %0, %1" : : "r" (va), "r" (pa));
}

// Make this an explicit call to flush the pipeline
static void set_asid(int asid) __attribute__((noinline))
{
	__builtin_nyuzi_write_control_reg(CR_CURRENT_ASID, asid);
}
