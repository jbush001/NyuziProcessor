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

//
// Ensure we are properly translating I/O addresses, specifically that
// we are using the physical address and not the virtual address to determine
// if something is in the I/O range.
// Map the I/O range at 1MB and the physical address 1MB into the virtual
// range 0xffff0000 (where I/O is physically located).  
//

#define PAGE_SIZE 0x1000
#define TLB_WRITE_ENABLE 2

void add_itlb_mapping(unsigned int va, unsigned int pa)
{
	asm("itlbinsert %0, %1" : : "r" (va), "r" (pa));
}

void add_dtlb_mapping(unsigned int va, unsigned int pa)
{
	asm("dtlbinsert %0, %1" : : "r" (va), "r" (pa | TLB_WRITE_ENABLE));
}

void printmsg(const char *value)
{
	const char *c;
	
	for (c = value; *c; c++)
		*((volatile unsigned int*) 0x100020) = *c;
}

int main(void)
{
	int i;
	unsigned int stack_addr = (unsigned int) &i & ~(PAGE_SIZE - 1);

	// Map code & data
	for (i = 0; i < 8; i++)
	{
		add_itlb_mapping(i * PAGE_SIZE, i * PAGE_SIZE);
		add_dtlb_mapping(i * PAGE_SIZE, i * PAGE_SIZE);
	}

	// Stack
	add_dtlb_mapping(stack_addr, stack_addr);

	// A data region. Map this where the I/O region normally goes
	add_dtlb_mapping(0xffff0000, 0x100000);

	// I/O region. Put this outside its normal spot.
	add_dtlb_mapping(0x100000, 0xffff0000);

	// Enable MMU in flags register
	__builtin_nyuzi_write_control_reg(4, (1 << 1));

	// Print a message
	printmsg("jabberwocky");

	// Copy into memory
	memcpy(0xffff0000, "galumphing", 10);
	asm("dflush %0" : : "s" (0xffff0000));
	
	// Since I/O is remapped, need to halt using new address
	*((volatile unsigned int*) 0x100064) = 1; 
	
	return 0;
}