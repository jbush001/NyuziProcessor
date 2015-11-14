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

#include <stdio.h>
#include <unistd.h>

#define PAGE_SIZE 0x1000
#define TLB_WRITABLE 2
#define TLB_GLOBAL (1 << 4)

// Virtual addresses are chosen to not alias with code or other pages
#define VADDR1 0x10a000
#define PADDR1 0x100000
#define PADDR2 0x101000

void add_itlb_mapping(unsigned int va, unsigned int pa)
{
	asm("itlbinsert %0, %1" : : "r" (va), "r" (pa));
}

void add_dtlb_mapping(unsigned int va, unsigned int pa)
{
	asm("dtlbinsert %0, %1" : : "r" (va), "r" (pa));
}

// Make this an explicit call to flush the pipeline
void set_asid(int asid) __attribute__((noinline))
{
	__builtin_nyuzi_write_control_reg(9, asid);
}

void fault_handler(void)
{
	printf("FAULT %d addr %08x pc %08x\n", 
		__builtin_nyuzi_read_control_reg(3),
		__builtin_nyuzi_read_control_reg(5),
		__builtin_nyuzi_read_control_reg(2));
	exit(0);
}

int main(int argc, const char *argv[])
{
	int i;
	int asid;
	unsigned int stack_addr = (unsigned int) &i & ~(PAGE_SIZE - 1);

	// Create mappings for code, data, stack, and IO. Mark these global.
	// They will be in ASID 0 but should be visible to all address spaces.
	for (i = 0; i < 8; i++)
	{
		add_itlb_mapping(i * PAGE_SIZE, i * PAGE_SIZE | TLB_GLOBAL);
		add_dtlb_mapping(i * PAGE_SIZE, (i * PAGE_SIZE) | TLB_WRITABLE | TLB_GLOBAL);
	}

	add_dtlb_mapping(stack_addr, stack_addr | TLB_WRITABLE | TLB_GLOBAL);
	add_dtlb_mapping(0xffff0000, 0xffff0000 | TLB_WRITABLE | TLB_GLOBAL); // I/O

	// Map a private page into address space 1
	set_asid(1);
	add_dtlb_mapping(VADDR1, PADDR1);
	*((unsigned int*) PADDR1) = 0xdeadbeef;

	// Map a private page into address space 2
	set_asid(2);
	add_dtlb_mapping(VADDR1, PADDR2);
	*((unsigned int*) PADDR2) = 0xabcdefed;

	// Enable MMU in flags register
	__builtin_nyuzi_write_control_reg(1, fault_handler);
	__builtin_nyuzi_write_control_reg(7, fault_handler);
	__builtin_nyuzi_write_control_reg(4, (1 << 1) | (1 << 2));
	
	// Read value from first address space
	set_asid(1);
	printf("A1 %08x\n", *((unsigned int*) VADDR1)); // CHECK: A1 deadbeef
	
	// Read value from the second address space
	set_asid(2);
	printf("A2 %08x\n", *((unsigned int*) VADDR1)); // CHECK: A2 abcdefed

	return 0;
}
