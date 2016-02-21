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
// Ensure that attempting to write to a control register while in
// user mode raises a fault and doesn't update the register.
//

void faultHandler(void)
{
    printf("FAULT %d current flags %02x prev flags %02x\n",
           __builtin_nyuzi_read_control_reg(3),
           __builtin_nyuzi_read_control_reg(4),
           __builtin_nyuzi_read_control_reg(8));
    printf("scratchpad = %08x\n", __builtin_nyuzi_read_control_reg(11));
    exit(0);
}

// Make this a call to flush the pipeline
void __attribute__((noinline)) switchToUserMode(void)
{
    __builtin_nyuzi_write_control_reg(4, 0);
}

int main(void)
{
    __builtin_nyuzi_write_control_reg(1, faultHandler);

    // Initialize scratchpad0
    __builtin_nyuzi_write_control_reg(11, 0x12345678);

    // Switch to user mode, but leave MMU active
    switchToUserMode();

    // Check two things:
    // - That we raise a fault
    // - That the control register isn't updated. Since the fault check and update
    //   use different logic, it's possible to update the register *and* fault,
    //   which is still a security hole.
    __builtin_nyuzi_write_control_reg(11, 0xdeadbeef);
    // CHECK: FAULT 10 current flags 04 prev flags 00
    // CHECK: scratchpad = 12345678

    printf("should_not_be_here\n"); // CHECKN: should_not_be_here
}

