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

#include "mmu_test_common.h"

// Test that attempting to peform itlbinsert while in user mode raises a fault
// XXX Does not validate that the entry wasn't inserted.

void fault_handler()
{
	printf("FAULT %d current flags %02x prev flags %02x\n",
		__builtin_nyuzi_read_control_reg(3),
		__builtin_nyuzi_read_control_reg(4),
		__builtin_nyuzi_read_control_reg(8));
	exit(0);
}

int main(void)
{
	__builtin_nyuzi_write_control_reg(CR_FAULT_HANDLER, fault_handler);

	// Switch to user mode, but leave MMU active
	switch_to_user_mode();

	asm("itlbinsert %0, %1" : : "r" (0), "r" (0)); // CHECK: FAULT 10 current flags 04 prev flags 00

	printf("executed instruction\n");
}

