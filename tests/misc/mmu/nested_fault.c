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

#include <stdint.h>
#include "mmu_test_common.h"

//
// Ensure the processor handles nested faults properly.
//

#define EXTPTR ((volatile unsigned int*) 0x300000)

int main();
extern void tlb_miss_handler();

unsigned int foo;

void fault_handler()
{
	__builtin_nyuzi_write_control_reg(CR_SCRATCHPAD0, 0x88cf70b4);
	__builtin_nyuzi_write_control_reg(CR_SCRATCHPAD1, 0x78662516);

	// This will cause a nested TLB miss fault
	*EXTPTR = 0;

	// We've returned from the TLB miss handler. Ensure all of the control registers
	// have been restored to the values for the original fault.
	printf("reason %d\n", __builtin_nyuzi_read_control_reg(CR_FAULT_REASON)); // CHECK: reason 2
	printf("fault address %08x\n", __builtin_nyuzi_read_control_reg(CR_FAULT_ADDRESS)); // CHECK: 00000017
	printf("flags %02x\n", __builtin_nyuzi_read_control_reg(CR_SAVED_FLAGS)); // CHECK: flags 06
	printf("subcycle %d\n", __builtin_nyuzi_read_control_reg(CR_SUBCYCLE)); // CHECK: subcycle 6
	if (__builtin_nyuzi_read_control_reg(CR_FAULT_PC) < (unsigned int) &tlb_miss_handler)
		printf("fault pc ok\n"); // CHECK: fault pc ok
	else
		printf("fault pc bad (%08x)\n", __builtin_nyuzi_read_control_reg(CR_FAULT_PC));

	printf("CR_SCRATCHPAD0 %08x\n", __builtin_nyuzi_read_control_reg(CR_SCRATCHPAD0));
		// CHECK: CR_SCRATCHPAD0 88cf70b4
	printf("CR_SCRATCHPAD1 %08x\n", __builtin_nyuzi_read_control_reg(CR_SCRATCHPAD1));
		// CHECK: CR_SCRATCHPAD1 78662516

	exit(0);
}

int main(void)
{
	veci16_t pointers = { &foo, &foo, &foo, &foo, &foo, &foo, 0x17,  &foo, &foo, &foo, &foo, &foo, &foo, &foo, &foo, &foo };

	__builtin_nyuzi_write_control_reg(CR_FAULT_HANDLER, fault_handler);
	__builtin_nyuzi_write_control_reg(CR_TLB_MISS_HANDLER, tlb_miss_handler);
	__builtin_nyuzi_write_control_reg(CR_FLAGS, FLAG_MMU_EN | FLAG_SUPERVISOR_EN);

	// This ensures the libc functions are mapped into the TLB so we don't generate
	// multiple TLB misses in the fault handler (doesn't break the test, just makes
	// debugging cleaner)
	printf("Starting test %d\n", 12);

	// This will cause an alignment fault on the 6th lane and jump to 'fault_handler'.
	__builtin_nyuzi_scatter_storei(pointers, __builtin_nyuzi_makevectori(0));

	return 0;
}

