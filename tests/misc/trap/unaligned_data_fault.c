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
// Test that unaligned data accesses properly raise faults
//

#include <stdint.h>

#define PTR_AS(num, type) *((type*) num)

extern void trap_handler();

volatile unsigned int dummy1;
volatile veci16_t dummy2;

void do_trap(unsigned int *registers)
{
	printf("FAULT %d address %08x\n", __builtin_nyuzi_read_control_reg(3),
		__builtin_nyuzi_read_control_reg(5));
	registers[31] += 4;	// Skip instruction
}

int main(int argc, const char *argv[])
{
	__builtin_nyuzi_write_control_reg(1, trap_handler);

	PTR_AS(0x17, unsigned int) = 1;    			// CHECK: FAULT 2 address 00000017
	PTR_AS(0x19, unsigned short) = 1;  			// CHECK: FAULT 2 address 00000019
	PTR_AS(0x21, veci16_t) = dummy2;   			// CHECK: FAULT 2 address 00000021
	dummy1 += PTR_AS(0x23, unsigned int) = 1;	// CHECK: FAULT 2 address 00000023
	dummy1 += PTR_AS(0x25, unsigned short) = 1;	// CHECK: FAULT 2 address 00000025
	dummy2 = PTR_AS(0x27, veci16_t);			// CHECK: FAULT 2 address 00000027

	printf("DONE\n"); // CHECK: DONE

	return 1;
}

