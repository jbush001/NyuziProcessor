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

void fault_handler()
{
	printf("FAULT %d current flags %02x prev flags %02x\n", 
		__builtin_nyuzi_read_control_reg(3),
		__builtin_nyuzi_read_control_reg(4),
		__builtin_nyuzi_read_control_reg(8));
	exit(0);
}

// Make this a call to flush the pipeline
void switch_to_user_mode() __attribute__((noinline))
{
	__builtin_nyuzi_write_control_reg(4, 0);
}

int main(int argc, const char *argv[])
{
	__builtin_nyuzi_write_control_reg(1, fault_handler);

	// Switch to user mode, but leave MMU active
	switch_to_user_mode();

	asm("eret"); // CHECK: FAULT 10 current flags 04 prev flags 00
}

