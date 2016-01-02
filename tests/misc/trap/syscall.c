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
// This tests performing a syscall and returning from it, although
// in reverse order
//

void fault_handler(void)
{
    printf("FAULT %d current flags %02x prev flags %02x\n",
           __builtin_nyuzi_read_control_reg(3),
           __builtin_nyuzi_read_control_reg(4),
           __builtin_nyuzi_read_control_reg(8));
    exit(0);
}

void start_user_code(void)
{
    printf("ENTER start_user_code current flags %02x\n",
           __builtin_nyuzi_read_control_reg(4));

    // This will call fault_handler, which was set up in main
    asm("syscall" );
    printf("FAIL: syscall did not work\n");
}

int main(void)
{
    __builtin_nyuzi_write_control_reg(1, fault_handler);

    printf("ENTER main current flags %02x\n",
           __builtin_nyuzi_read_control_reg(4));
    // CHECK: ENTER main current flags 04

    // Test using ERET to disable supervisor flag and jump to code
    __builtin_nyuzi_write_control_reg(2, start_user_code);
    __builtin_nyuzi_write_control_reg(8, 0);	// Prev flags
    asm("eret");

    // CHECK: ENTER start_user_code current flags 00
    // CHECK: FAULT 11 current flags 04 prev flags 00

    printf("should_not_be_here\n"); // CHECKN: should_not_be_here
}

