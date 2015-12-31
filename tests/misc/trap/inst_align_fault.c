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
// Test that unaligned instruction properly raises a fault
//

typedef void (*func_ptr_t)();

void fault_handler()
{
	printf("FAULT %d\n", __builtin_nyuzi_read_control_reg(3));
	exit(0);
}

void dummy_func()
{
	printf("FAIL: called dummy_func\n");
}

int main(int argc, const char *argv[])
{
	func_ptr_t func_ptr;

	__builtin_nyuzi_write_control_reg(1, fault_handler);

	func_ptr = (func_ptr_t) (((unsigned int) &dummy_func) + 1);
	(*func_ptr)();
	// CHECK: FAULT 4

	printf("FAIL: did not fault\n");

	return 1;
}

