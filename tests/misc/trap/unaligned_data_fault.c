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
	printf("FAULT %d address %08x subcycle %d\n", __builtin_nyuzi_read_control_reg(3),
		__builtin_nyuzi_read_control_reg(5), registers[33]);
	registers[33] = 0;	// Set subcycle back to 0
	registers[31] += 4;	// Skip instruction
}

int main(int argc, const char *argv[])
{
	veci16_t pointers = {&dummy1, &dummy1, &dummy1, 0x29,
		&dummy1, &dummy1, &dummy1, &dummy1, &dummy1, &dummy1, &dummy1, &dummy1,
		&dummy1, &dummy1, &dummy1, &dummy1};

	__builtin_nyuzi_write_control_reg(1, trap_handler);

	// Test all memory access sizes, both load and store

	PTR_AS(0x17, unsigned int) = 1;    			// CHECK: FAULT 2 address 00000017 subcycle 0
	PTR_AS(0x19, unsigned short) = 1;  			// CHECK: FAULT 2 address 00000019 subcycle 0
	PTR_AS(0x21, veci16_t) = dummy2;   			// CHECK: FAULT 2 address 00000021 subcycle 0
	__builtin_nyuzi_scatter_storei(pointers, dummy2); // CHECK: FAULT 2 address 00000029 subcycle 3

	dummy1 += PTR_AS(0x23, unsigned int) = 1;	// CHECK: FAULT 2 address 00000023 subcycle 0
	dummy1 += PTR_AS(0x25, unsigned short) = 1;	// CHECK: FAULT 2 address 00000025 subcycle 0
	dummy2 = PTR_AS(0x27, veci16_t);			// CHECK: FAULT 2 address 00000027 subcycle 0
	dummy2 = __builtin_nyuzi_gather_loadi(pointers); // CHECK: FAULT 2 address 00000029 subcycle 3

	printf("DONE\n"); // CHECK: DONE

	return 1;
}

