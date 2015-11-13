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

// Test that supervisor bits work properly for DTLB entries

#define PAGE_SIZE 0x1000
#define TLB_WRITE_ENABLE 2
#define TLB_SUPERVISOR 8

volatile unsigned int *data_addr = (unsigned int*) 0x100000;

void add_itlb_mapping(unsigned int va, unsigned int pa)
{
	asm("itlbinsert %0, %1" : : "r" (va), "r" (pa));
}

void add_dtlb_mapping(unsigned int va, unsigned int pa)
{
	asm("dtlbinsert %0, %1" : : "r" (va), "r" (pa | TLB_WRITE_ENABLE));
}

void fault_handler()
{
	printf("FAULT %d %08x current flags %02x prev flags %02x\n", 
		__builtin_nyuzi_read_control_reg(3),
		__builtin_nyuzi_read_control_reg(5),
		__builtin_nyuzi_read_control_reg(4),
		__builtin_nyuzi_read_control_reg(8));
	exit(0);
}

// Make this a call to flush the pipeline
void switch_to_user_mode() __attribute__((noinline))
{
	__builtin_nyuzi_write_control_reg(4, (1 << 1));
}

int main(int argc, const char *argv[])
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

	// A data region
	add_dtlb_mapping(data_addr, ((unsigned int) data_addr) | TLB_SUPERVISOR);

	// I/O registers
	add_dtlb_mapping(0xffff0000, 0xffff0000);

	__builtin_nyuzi_write_control_reg(1, fault_handler);
	__builtin_nyuzi_write_control_reg(4, (1 << 1) | (1 << 2));

	// We are currently in supervisor mode. write then read to the page
	*data_addr = 0x12345678;
	printf("read1 data_addr %08x\n", *data_addr);	// CHECK: read1 data_addr 12345678

	// Switch to user mode, but leave MMU active
	switch_to_user_mode();

	printf("read2 data_addr %08x\n", *data_addr);	// CHECK: FAULT 8 00100000 current flags 06 prev flags 02
}

